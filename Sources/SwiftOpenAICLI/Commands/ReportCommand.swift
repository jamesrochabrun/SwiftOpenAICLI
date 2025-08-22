import ArgumentParser
import Foundation
import SwiftOpenAI
import Rainbow
#if os(macOS)
import PDFKit
import WebKit
#endif

struct ReportCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "report",
    abstract: "Generate research reports with PDF export and visualizations"
  )
  
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
  
  mutating func run() async throws {
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
      modifiedQuery += " [IMPORTANT: Take screenshots of important pages using browser_take_screenshot tool]"
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
    // Basic markdown to HTML conversion
    // In production, we'd use a proper markdown parser
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
        pre { background: #f5f5f5; padding: 10px; border-radius: 5px; overflow-x: auto; }
        code { background: #f0f0f0; padding: 2px 5px; border-radius: 3px; }
        img { max-width: 100%; height: auto; display: block; margin: 20px 0; }
        table { border-collapse: collapse; width: 100%; margin: 20px 0; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background: #f5f5f5; }
      </style>
    </head>
    <body>
      <div id="content">
        <!-- Markdown content would be converted here -->
        \(markdown.replacingOccurrences(of: "\n", with: "<br>\n"))
      </div>
    </body>
    </html>
    """
    return html
  }
  
  #if os(macOS)
  @MainActor
  private func generatePDF(from markdown: String, to path: String) async throws {
    // Convert markdown to HTML first
    let html = try convertMarkdownToHTML(markdown)
    
    // Create a WebView to render HTML
    let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 612, height: 792)) // Letter size
    
    // Load HTML content
    webView.loadHTMLString(html, baseURL: nil)
    
    // Wait for content to load
    try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
    
    // Create PDF data
    let pdfConfiguration = WKPDFConfiguration()
    pdfConfiguration.rect = CGRect(x: 0, y: 0, width: 612, height: 792)
    
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