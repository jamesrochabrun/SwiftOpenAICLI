import ArgumentParser
import Foundation
import SwiftOpenAI
import Rainbow
#if os(macOS)
import PDFKit
import WebKit
#endif

public struct ReportCommand: AsyncParsableCommand {
  public static let configuration = CommandConfiguration(
    commandName: "report",
    abstract: "Generate research reports with PDF export and visualizations"
  )

    public init() {}

  
  @Argument(help: "The research task or question")
  var query: String
  
  @Option(name: [.short, .long], help: "The model to use")
  var model: String = "gpt-4o-mini"
  
  @Option(name: .long, help: "Output format (pdf, markdown, html)")
  var format: String = "pdf"
  
  @Option(name: [.short, .long], help: "Output file path")
  var output: String?
  
  @Option(name: .long, help: "Report template (research, comparison, analysis)")
  var template: String = "research"
  
  @Option(name: .long, help: "Enable MCP servers (comma-separated)")
  var mcpServers: String?
  
  @Flag(name: .long, help: "Include screenshots from web pages")
  var includeScreenshots = false
  
  @Option(name: .long, help: "Maximum tool calls")
  var maxToolCalls: Int = 30
  
  @Option(name: .long, help: "System prompt for the report")
  var system: String?
  
  @Flag(name: .long, help: "Include charts and visualizations")
  var includeCharts = false
  
  @Flag(name: [.short, .long], help: "Verbose output")
  var verbose = false
  
  @Flag(name: .long, help: "Show tool execution events")
  var showToolEvents = false
  
  @Flag(name: .long, help: "Show full tool results without truncation")
  var showToolEventsVerbose = false
  
  public mutating func run() async throws {
    // Default system prompt for reports
    let defaultSystem = """
    You are a professional research analyst. Create detailed, well-structured reports with:
    - Executive summary
    - Detailed findings with sources
    - Data tables where appropriate
    - Clear conclusions and recommendations
    Format your response in markdown with proper headings and sections.
    When using web tools, capture important information and note the sources.
    """
    
    let effectiveSystem = system ?? defaultSystem
    
    // Determine output path
    let outputPath = output ?? "report_\(Date().timeIntervalSince1970).pdf"
    
    print("🔬 Generating report...".cyan)
    print("Template: \(template)".lightBlack)
    print("Output: \(outputPath)".lightBlack)
    
    // Configure MCP servers if needed
    let mcpConfigs = try loadMCPServers()
    
    // Special handling for playwright - request screenshots
    var modifiedQuery = query
    if includeScreenshots && (mcpServers?.contains("playwright") ?? false) {
      modifiedQuery += """
      
      [CRITICAL SCREENSHOT INSTRUCTIONS: 
      1. When you take a screenshot using browser_take_screenshot, you will receive a response like "Took the full page screenshot and saved it as /var/folders/.../screenshot.png"
      2. You MUST include each screenshot in your markdown report using EXACTLY this format: ![Description](sandbox:/var/folders/.../screenshot.png)
      3. Use the EXACT path from the tool response, just add 'sandbox:' prefix
      4. Example: If tool says "saved it as /var/folders/abc/screenshot.png", write: ![Screenshot](sandbox:/var/folders/abc/screenshot.png)
      5. Include ALL screenshots you take in the report - do not skip any]
      """
    }
    
    // Generate the report content
    let reportContent = try await generateReport(
      query: modifiedQuery,
      model: model,
      system: effectiveSystem,
      mcpConfigs: mcpConfigs
    )
    
    // Process based on format
    switch format.lowercased() {
    case "markdown", "md":
      try reportContent.write(toFile: outputPath, atomically: true, encoding: .utf8)
      print("✅ Markdown report saved to: \(outputPath)".green)
      
    case "html":
      let html = try convertMarkdownToHTML(reportContent)
      try html.write(toFile: outputPath, atomically: true, encoding: .utf8)
      print("✅ HTML report saved to: \(outputPath)".green)
      
    case "pdf":
      #if os(macOS)
      try await generatePDF(from: reportContent, to: outputPath)
      print("✅ PDF report saved to: \(outputPath)".green)
      #else
      print("❌ PDF generation is only available on macOS".red)
      throw ExitCode.failure
      #endif
      
    default:
      print("❌ Unsupported format: \(format)".red)
      throw ExitCode.failure
    }
  }
  
  private func generateReport(query: String, model: String, system: String, mcpConfigs: [MCPServerConfig]) async throws -> String {
    // Create arguments for agent command
    var enabledTools: Set<String>?
    if let servers = mcpServers {
      // Enable all MCP tools from specified servers
      let serverNames = servers.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)) }
      var tools: [String] = []
      for server in serverNames {
        tools.append("mcp__\(server)__*")
      }
      enabledTools = Set(tools)
    }
    
    // Call the agent service and get the response
    let reportContent = try await OpenAIService.shared.agentChatForReport(
      message: query,
      model: model,
      system: system,
      temperature: 1.0,  // GPT-5 models only support 1.0
      maxTokens: nil,
      enabledTools: enabledTools,
      verbose: verbose ? "high" : "low",
      reasoning: "medium",
      mcpServers: mcpConfigs,
      timeout: 120,
      maxToolCalls: maxToolCalls,
      showToolEvents: showToolEvents || verbose,
      showToolEventsVerbose: showToolEventsVerbose
    )
    
    // Add metadata
    let dateFormatter = DateFormatter()
    dateFormatter.dateStyle = .long
    dateFormatter.timeStyle = .short
    
    return """
    \(reportContent)
    
    ---
    *Report generated on \(dateFormatter.string(from: Date()))*
    *Model: \(model)*
    """
  }
  
  private func loadMCPServers() throws -> [MCPServerConfig] {
    guard let mcpServers = mcpServers else { return [] }
    
    let configManager = ConfigurationManager.shared
    let config = configManager.getConfiguration()
    
    let requestedServers = Set(mcpServers.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)) })
    
    var configs: [MCPServerConfig] = []
    
    if let serverDefs = config.mcpServers {
      for serverDef in serverDefs.allServers {
        if let serverName = serverDef.name,
           requestedServers.contains(serverName) && (serverDef.enabled ?? true) {
          configs.append(serverDef.toMCPServerConfig)
        }
      }
    }
    
    return configs
  }
  
  private func convertMarkdownToHTML(_ markdown: String) throws -> String {
    // Process the markdown to convert images and formatting
    var processedContent = markdown
    
    // Process images with sandbox paths FIRST (before other conversions)
    let imagePattern = #"!\[([^\]]*)\]\((sandbox:)?([^\)]+)\)"#
    let regex = try NSRegularExpression(pattern: imagePattern, options: [])
    let matches = regex.matches(in: processedContent, options: [], range: NSRange(processedContent.startIndex..., in: processedContent))
    
    // Process matches in reverse order to maintain string indices
    for match in matches.reversed() {
      guard let matchRange = Range(match.range, in: processedContent) else { continue }
      
      let altTextRange = Range(match.range(at: 1), in: processedContent)
      let pathRange = Range(match.range(at: 3), in: processedContent)
      
      let altText = altTextRange.map { String(processedContent[$0]) } ?? ""
      let imagePath = pathRange.map { String(processedContent[$0]) } ?? ""
      
      // Try to load and embed the image
      if let imageTag = embedImageAsBase64(path: imagePath, altText: altText) {
        processedContent.replaceSubrange(matchRange, with: imageTag)
      }
    }
    
    // Convert markdown formatting
    // Bold text
    processedContent = processedContent.replacingOccurrences(of: #"\*\*([^*]+)\*\*"#, with: "<strong>$1</strong>", options: .regularExpression)
    processedContent = processedContent.replacingOccurrences(of: #"__([^_]+)__"#, with: "<strong>$1</strong>", options: .regularExpression)
    
    // Italic text
    processedContent = processedContent.replacingOccurrences(of: #"\*([^*]+)\*"#, with: "<em>$1</em>", options: .regularExpression)
    processedContent = processedContent.replacingOccurrences(of: #"_([^_]+)_"#, with: "<em>$1</em>", options: .regularExpression)
    
    // Code blocks
    processedContent = processedContent.replacingOccurrences(of: #"```([^`]+)```"#, with: "<pre><code>$1</code></pre>", options: .regularExpression)
    processedContent = processedContent.replacingOccurrences(of: #"`([^`]+)`"#, with: "<code>$1</code>", options: .regularExpression)
    
    // Lists (using multiline patterns)
    let lines = processedContent.components(separatedBy: "\n")
    var convertedLines: [String] = []
    
    for line in lines {
      var convertedLine = line
      
      // Convert lists
      if line.starts(with: "- ") {
        convertedLine = "<li>" + String(line.dropFirst(2)) + "</li>"
      } else if line.starts(with: "* ") {
        convertedLine = "<li>" + String(line.dropFirst(2)) + "</li>"
      } else if line.range(of: #"^\d+\. (.+)$"#, options: .regularExpression) != nil {
        let numberedItem = line.replacingOccurrences(of: #"^\d+\. "#, with: "", options: .regularExpression)
        convertedLine = "<li>\(numberedItem)</li>"
      }
      // Convert headings
      else if line.starts(with: "#### ") {
        convertedLine = "<h4>" + String(line.dropFirst(5)) + "</h4>"
      } else if line.starts(with: "### ") {
        convertedLine = "<h3>" + String(line.dropFirst(4)) + "</h3>"
      } else if line.starts(with: "## ") {
        convertedLine = "<h2>" + String(line.dropFirst(3)) + "</h2>"
      } else if line.starts(with: "# ") {
        convertedLine = "<h1>" + String(line.dropFirst(2)) + "</h1>"
      }
      
      convertedLines.append(convertedLine)
    }
    
    processedContent = convertedLines.joined(separator: "\n")
    
    // Convert line breaks
    processedContent = processedContent.replacingOccurrences(of: "\n", with: "<br>\n")
    
    let html = """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="UTF-8">
      <title>Report</title>
      <style>
        body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; }
        h1 { color: #333; border-bottom: 2px solid #007AFF; padding-bottom: 10px; }
        h2 { color: #555; margin-top: 30px; }
        h3 { color: #666; margin-top: 25px; }
        h4 { color: #777; margin-top: 20px; }
        pre { background: #f5f5f5; padding: 10px; border-radius: 5px; overflow-x: auto; }
        code { background: #f0f0f0; padding: 2px 5px; border-radius: 3px; }
        img { max-width: 100%; height: auto; display: block; margin: 20px 0; border: 1px solid #ddd; border-radius: 5px; }
        table { border-collapse: collapse; width: 100%; margin: 20px 0; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background: #f5f5f5; }
      </style>
    </head>
    <body>
      <div id="content">
        \(processedContent)
      </div>
    </body>
    </html>
    """
    return html
  }
  
  private func embedImageAsBase64(path: String, altText: String) -> String? {
    // Clean the path (remove sandbox: prefix if present)
    let cleanPath = path.replacingOccurrences(of: "sandbox:", with: "")
    
    // Try to read the image file
    guard let imageData = try? Data(contentsOf: URL(fileURLWithPath: cleanPath)) else {
      // If we can't read the file, return a placeholder
      return "<p style='color: #999; font-style: italic;'>[\(altText.isEmpty ? "Image" : altText) - unable to load from: \(cleanPath)]</p>"
    }
    
    // Determine MIME type based on file extension
    let mimeType: String
    if cleanPath.lowercased().hasSuffix(".png") {
      mimeType = "image/png"
    } else if cleanPath.lowercased().hasSuffix(".jpg") || cleanPath.lowercased().hasSuffix(".jpeg") {
      mimeType = "image/jpeg"
    } else if cleanPath.lowercased().hasSuffix(".gif") {
      mimeType = "image/gif"
    } else {
      mimeType = "image/png" // Default to PNG
    }
    
    // Convert to base64
    let base64String = imageData.base64EncodedString()
    
    // Return embedded image tag
    return "<img src=\"data:\(mimeType);base64,\(base64String)\" alt=\"\(altText)\" />"
  }
  
  #if os(macOS)
  @MainActor
  private func generatePDF(from markdown: String, to path: String) async throws {
    // Convert markdown to HTML first
    let html = try convertMarkdownToHTML(markdown)
    
    // Create a WebView to render HTML with larger initial size for content measurement
    let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 612, height: 5000)) // Letter width, tall height
    
    // Load HTML content
    webView.loadHTMLString(html, baseURL: nil)
    
    // Wait for content to load
    try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
    
    // Create PDF data - let it auto-paginate
    let pdfConfiguration = WKPDFConfiguration()
    // Don't set rect to allow automatic pagination of all content
    
    let pdfData = try await webView.pdf(configuration: pdfConfiguration)
    
    // Save to file
    try pdfData.write(to: URL(fileURLWithPath: path))
  }
  #endif
}

// Extension to make WKWebView async-friendly
#if os(macOS)
extension WKWebView {
  @MainActor
  func pdf(configuration: WKPDFConfiguration) async throws -> Data {
    return try await withCheckedThrowingContinuation { continuation in
      self.createPDF(configuration: configuration) { result in
        switch result {
        case .success(let data):
          continuation.resume(returning: data)
        case .failure(let error):
          continuation.resume(throwing: error)
        }
      }
    }
  }
}
#endif
