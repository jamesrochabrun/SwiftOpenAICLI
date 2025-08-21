import ArgumentParser
import Foundation
import SwiftOpenAI
import Rainbow
#if os(macOS) || os(Linux)
import Darwin
#endif

struct AgentCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "agent",
    abstract: "Chat with OpenAI models using tool capabilities"
  )
  
  @Argument(help: "The message to send to the AI agent")
  var message: String?
  
  @Option(name: [.short, .long], help: "The model to use")
  var model: String = "gpt-5"
  
  @Option(name: .long, help: "System prompt")
  var system: String?
  
  @Option(name: .long, help: "Temperature (0.0-2.0)")
  var temperature: Double = 1.0
  
  @Option(name: .long, help: "Maximum tokens to generate")
  var maxTokens: Int?
  
  @Option(name: .long, help: "Output format (plain, json, stream-json)")
  var outputFormat: String = "plain"
  
  @Option(name: .long, help: "Session ID for resuming conversations")
  var sessionId: String?
  
  @Option(name: .long, help: "Reserved for future use (MCP tools are automatically available)")
  var tools: String = ""
  
  @Option(name: .long, help: "Enable specific MCP servers (comma-separated names from config)")
  var mcpServers: String?
  
  @Option(name: .long, help: "Explicit list of allowed tools (overrides --tools and MCP auto-discovery). Use glob patterns like 'mcp__*' or 'mcp__github__*'")
  var allowedTools: String?
  
  @Flag(name: [.short, .long], help: "Interactive agent mode")
  var interactive = false
  
  @Flag(name: [.short, .long], help: "Verbose output for debugging")
  var verbose = false
  
  @Flag(name: .long, help: "Show tool events in interactive mode")
  var showToolEvents = false
  
  @Flag(name: .long, help: "Show MCP connection status")
  var showMCPStatus = false
  
  @Option(name: .long, help: "Verbosity level for GPT-5 models (low, medium, high)")
  var modelVerbosity: VerbosityLevel = .medium
  
  @Option(name: .long, help: "Reasoning effort for GPT-5 models (minimal, low, medium, high)")
  var reasoning: ReasoningEffort = .medium
  
  mutating func run() async throws {
    let mcpConfigs = try loadMCPServers()
    
    // Determine which tools to enable
    let enabledTools: Set<String>?
    if let allowedTools = allowedTools {
      // Use explicit allowed tools list with pattern matching
      enabledTools = parseAllowedTools(allowedTools)
    } else {
      // Use the default tools list
      enabledTools = parseTools(tools)
    }
    
    if interactive {
      try await runInteractiveMode(mcpConfigs: mcpConfigs, enabledTools: enabledTools)
    } else if let message = message {
      try await OpenAIService.shared.agentChat(
        message: message,
        model: model,
        system: system,
        temperature: temperature,
        maxTokens: maxTokens,
        outputFormat: outputFormat,
        enabledTools: enabledTools,
        verbose: modelVerbosity.rawValue,
        reasoning: reasoning.rawValue,
        sessionId: sessionId,
        mcpServers: mcpConfigs,
        showMCPStatus: showMCPStatus
      )
    } else {
      print("Please provide a message or use --interactive flag".red)
      throw ExitCode.failure
    }
  }
  
  private func parseTools(_ toolString: String) -> Set<String> {
    let toolNames = toolString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    return Set(toolNames)
  }
  
  private func parseAllowedTools(_ patterns: String) -> Set<String>? {
    // Return nil to indicate "use all matching patterns"
    // The actual pattern matching will be done in ToolExecutor
    let patterns = patterns.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    return Set(patterns)
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
          if showMCPStatus {
            print("🔌 Enabling MCP server: \(serverName)".lightBlack)
          }
        }
      }
    }
    
    return configs
  }
  
  private func runInteractiveMode(mcpConfigs: [MCPServerConfig] = [], enabledTools: Set<String>? = nil) async throws {
    // Check if we're in a proper terminal
#if os(macOS) || os(Linux)
    guard isatty(STDIN_FILENO) != 0 else {
      print("Error: Interactive mode requires a terminal environment".red)
      print("For non-interactive use, provide a message directly:".yellow)
      print("  swiftopenai agent \"Your message here\"".lightBlack)
      throw ExitCode.failure
    }
#endif
    
    if outputFormat != "plain" && outputFormat != "interactive" {
      print("Interactive mode only supports plain output format".red)
      throw ExitCode.failure
    }
    
    // Create persistent ToolExecutor for the session
    // In interactive mode, always show MCP status and never use stderr
    let toolExecutor = ToolExecutor(mcpServers: mcpConfigs, verbose: true, useStderr: false)
    await toolExecutor.initialize()
    
    print("🤖 OpenAI Agent Mode (\(model))".cyan)
    if let allowedTools = allowedTools {
      print("Allowed tools: \(allowedTools)".lightBlack)
    }
    if !mcpConfigs.isEmpty {
      print("MCP servers: \(mcpConfigs.map { $0.name }.joined(separator: ", "))".lightBlack)
      print("🚀 MCP servers initialized once for this session".green)
    }
    if showToolEvents {
      print("Tool events: ON".lightBlack)
    }
    let contextWindow = TokenCalculator.getContextWindow(for: model)
    print("Context window: \(contextWindow / 1000)K tokens".lightBlack)
    if contextWindow <= 5000 {
      print("⚠️  DEBUG MODE: Using reduced context window for testing".yellow)
    }
    print("Type 'exit' to quit, 'clear' to clear history, Ctrl+C to interrupt".lightBlack)
    print("")
    
    var currentSessionId = UUID().uuidString
    
    // Set up signal handler for graceful exit
    // Note: Can't capture toolExecutor in signal handler, so cleanup happens in normal exit paths
    signal(SIGINT) { _ in
      print("\n\nInterrupted. Goodbye!".yellow)
      Darwin.exit(0)
    }
    
    while true {
      print("You: ".green, terminator: "")
      fflush(stdout)
      
      // Handle EOF (Ctrl+D) and read input
      guard let input = readLine() else {
        // EOF detected (Ctrl+D)
        print("\nCleaning up MCP connections...".yellow)
        await toolExecutor.cleanup()
        print("Goodbye!".yellow)
        break
      }
      
      // Trim whitespace and newlines
      let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
      
      // Skip empty lines without re-prompting
      guard !trimmedInput.isEmpty else {
        continue
      }
      
      // Check for exit command
      if trimmedInput.lowercased() == "exit" || trimmedInput.lowercased() == "quit" {
        print("Cleaning up MCP connections...".yellow)
        await toolExecutor.cleanup()
        print("Goodbye!".yellow)
        break
      }
      
      // Check for clear command
      if trimmedInput.lowercased() == "clear" {
        print("Conversation cleared.".yellow)
        SessionManager.shared.clearSession(currentSessionId)
        currentSessionId = UUID().uuidString
        continue
      }
      
      // Validate input length (prevent extremely long inputs)
      guard trimmedInput.count <= 10000 else {
        print("Error: Message too long (max 10000 characters)".red)
        continue
      }
      
      do {
        let format = showToolEvents ? "interactive-stream" : "plain"
        try await OpenAIService.shared.agentChatWithExecutor(
          message: trimmedInput,
          model: model,
          toolExecutor: toolExecutor,
          system: system,
          temperature: temperature,
          maxTokens: maxTokens,
          outputFormat: format,
          enabledTools: enabledTools,
          verbose: modelVerbosity.rawValue,
          reasoning: reasoning.rawValue,
          sessionId: currentSessionId
        )
        print()
      } catch {
        // Provide user-friendly error messages
        if error.localizedDescription.contains("401") {
          print("Error: Invalid API key. Please check your configuration.".red)
        } else if error.localizedDescription.contains("429") {
          print("Error: Rate limit exceeded. Please wait a moment and try again.".red)
        } else if error.localizedDescription.contains("timeout") {
          print("Error: Request timed out. Please try again.".red)
        } else {
          print("Error: \(error.localizedDescription)".red)
        }
        // Continue the session despite errors
      }
    }
    
    // Cleanup MCP connections when exiting
    await toolExecutor.cleanup()
    
    // Reset signal handler
    signal(SIGINT, SIG_DFL)
  }
}
