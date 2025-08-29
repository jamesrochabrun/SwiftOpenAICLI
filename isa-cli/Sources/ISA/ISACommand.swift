import ArgumentParser
import Foundation
import SwiftOpenAICLICore
import SwiftOpenAI
import Rainbow

@main
struct ISACommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "isa",
    abstract: "Intelligent Software Assistant - A powerful AI agent for developers",
    discussion: """
    ISA is an intelligent AI agent that helps you with coding tasks, file operations,
    and system automation. Built on SwiftOpenAICLI with Claude Code-inspired enhancements.
    
    QUICK START:
      isa                          # Start interactive mode (default)
      isa                          # Same as 'isa --interactive'
      isa "Help me refactor this"  # Process single message and exit
    
    FEATURES:
      • All SwiftOpenAICLI agent capabilities (MCP, tools, sessions)
      • Claude Code-inspired prompting and task management
      • Context-aware assistance with isa.md support
      • Beautiful terminal UI with progress indicators
      • Built-in and custom tools
      • Task management with visual todo lists
    
    CONTEXT FILES:
      Create an 'isa.md' file in your project root to provide context:
      - Project conventions and preferences
      - Important files and architecture
      - Custom instructions for ISA
    
    Version: 1.3.4
    """,
    version: "1.3.4"
  )
  
  @Argument(help: "The message to send to ISA")
  var message: String?
  
  @Option(name: [.short, .long], help: "The model to use")
  var model: String?
  
  @Option(name: .long, help: "System prompt (will be enhanced with ISA context)")
  var system: String?
  
  @Option(name: .long, help: "Temperature (0.0-2.0)")
  var temperature: Double?
  
  @Option(name: .long, help: "Maximum tokens to generate")
  var maxTokens: Int?
  
  @Option(name: .long, help: "Output format (plain, json, stream-json)")
  var outputFormat: String = "plain"
  
  @Option(name: .long, help: "Session ID for resuming conversations")
  var sessionId: String?
  
  @Option(name: .long, help: "Enable specific MCP servers (comma-separated)")
  var mcpServers: String?
  
  @Option(name: .long, help: "Allowed tools (glob patterns like 'mcp__*')")
  var allowedTools: String?
  
  @Option(name: .long, help: "Path to local tools configuration")
  var localToolsConfig: String?
  
  @Flag(name: [.short, .long], help: "Interactive mode")
  var interactive = false
  
  @Flag(name: [.short, .long], help: "Verbose output")
  var verbose = false
  
  @Flag(name: .long, help: "Plan mode - show plan before execution")
  var planMode = false
  
  @Flag(name: .long, help: "Show todo list in real-time")
  var showTodos = false
  
  @Flag(name: .long, help: "Show tool events")
  var showToolEvents = false
  
  @Option(name: .long, help: "Request timeout in seconds")
  var timeout: Int?
  
  @Option(name: .long, help: "Maximum tool calls allowed")
  var maxToolCalls: Int = 20
  
  mutating func run() async throws {
    // Default to interactive mode if no message provided
    let isInteractive = interactive || message == nil
    
    // Show ASCII art on startup
    if isInteractive {
      // Show appropriate banner based on provider
      let config = ConfigurationManager.shared.getConfiguration()
      if config.provider?.lowercased() == "xai" {
        TerminalUI.showGrokBanner()
      } else {
        TerminalUI.showISABanner()
      }
    }
    
    // Use configured default model and temperature if not specified
    let effectiveModel = model ?? ConfigurationManager.shared.defaultModel
    let effectiveTemperature = temperature ?? ConfigurationManager.shared.getConfiguration().temperature
    
    // Create ISA agent with enhanced capabilities
    let agent = try ISAAgent(
      model: effectiveModel,
      temperature: effectiveTemperature,
      verbose: verbose,
      planMode: planMode,
      showTodos: showTodos
    )
    
    // Load and apply ISA context
    let contextLoader = ISAContextLoader()
    let enhancedSystem = contextLoader.loadAndEnhancePrompt(basePrompt: system)
    
    if let message = message, !isInteractive {
      // Single message mode (only if explicitly not interactive)
      try await agent.processMessage(
        message,
        system: enhancedSystem,
        maxTokens: maxTokens,
        outputFormat: outputFormat,
        sessionId: sessionId,
        mcpServers: mcpServers,
        allowedTools: allowedTools,
        localToolsConfig: localToolsConfig,
        showToolEvents: showToolEvents,
        timeout: timeout,
        maxToolCalls: maxToolCalls
      )
    } else {
      // Interactive mode (default)
      try await agent.runInteractive(
        system: enhancedSystem,
        sessionId: sessionId,
        mcpServers: mcpServers,
        allowedTools: allowedTools,
        localToolsConfig: localToolsConfig,
        showToolEvents: showToolEvents,
        timeout: timeout,
        maxToolCalls: maxToolCalls
      )
    }
  }
}