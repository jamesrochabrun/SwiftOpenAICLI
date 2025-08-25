import ArgumentParser
import Foundation
import SwiftOpenAI
import Rainbow
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

public struct AgentCommand: AsyncParsableCommand {
  public static let configuration = CommandConfiguration(
    commandName: "agent",
    abstract: "Chat with OpenAI models using tool capabilities"
  )

    public init() {}

  
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
  
  @Option(name: .long, help: "Path to local tools configuration file (JSON)")
  var localToolsConfig: String?
  
  @Flag(name: [.short, .long], help: "Interactive agent mode")
  var interactive = false
  
  @Flag(name: [.short, .long], help: "Verbose output for debugging")
  var verbose = false
  
  @Flag(name: .long, help: "Show tool events in interactive mode")
  var showToolEvents = false
  
  @Flag(name: .long, help: "Show full tool results without truncation")
  var showToolEventsVerbose = false
  
  @Flag(name: .long, help: "Show MCP connection status")
  var showMCPStatus = false
  
  @Option(name: .long, help: "Request timeout in seconds (default: model-specific)")
  var timeout: Int?
  
  @Option(name: .long, help: "Verbosity level for GPT-5 models (low, medium, high)")
  var modelVerbosity: VerbosityLevel = .medium
  
  @Option(name: .long, help: "Reasoning effort for GPT-5 models (minimal, low, medium, high)")
  var reasoning: ReasoningEffort = .medium
  
  @Option(name: .long, help: "Maximum number of tool calls allowed (default: 10)")
  var maxToolCalls: Int = 10
  
  public mutating func run() async throws {
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
    
    // Determine timeout based on model if not explicitly set
    let effectiveTimeout = timeout ?? getDefaultTimeout(for: model)
    
    // Resolve local tools config path
    let resolvedLocalToolsPath = resolveLocalToolsPath(localToolsConfig)
    
    // Get maxToolCalls from config if not provided via CLI (CLI takes precedence)
    let effectiveMaxToolCalls: Int
    if maxToolCalls != 10 {  // Non-default value means it was set via CLI
      effectiveMaxToolCalls = maxToolCalls
    } else if let configMaxToolCalls = ConfigurationManager.shared.getConfiguration().maxToolCalls {
      effectiveMaxToolCalls = configMaxToolCalls
    } else {
      effectiveMaxToolCalls = 10  // Default value
    }
    
    if interactive {
      try await runInteractiveMode(mcpConfigs: mcpConfigs, localToolsConfig: resolvedLocalToolsPath, enabledTools: enabledTools, effectiveMaxToolCalls: effectiveMaxToolCalls)
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
        localToolsConfig: resolvedLocalToolsPath,
        showMCPStatus: showMCPStatus,
        timeout: effectiveTimeout,
        showToolEventsVerbose: showToolEventsVerbose,
        maxToolCalls: effectiveMaxToolCalls
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
  
  private func getDefaultTimeout(for model: String) -> Int {
    let lowercased = model.lowercased()
    if lowercased.contains("gpt-5") || lowercased.contains("gpt5") {
      return 180 // 3 minutes for GPT-5
    } else if lowercased.contains("gpt-4o-mini") || lowercased.contains("gpt4o-mini") {
      return 30 // 30 seconds for GPT-4o-mini
    } else {
      return 60 // 1 minute default for other models
    }
  }
  
  private func resolveLocalToolsPath(_ path: String?) -> String? {
    guard let path = path else { return nil }
    
    // Expand tilde if present
    if path.hasPrefix("~") {
      let homeDirectory = FileManager.default.homeDirectoryForCurrentUser.path
      return path.replacingOccurrences(of: "~", with: homeDirectory, range: path.startIndex..<path.index(after: path.startIndex))
    }
    
    return path
  }
  
  private func runInteractiveMode(mcpConfigs: [MCPServerConfig] = [], localToolsConfig: String? = nil, enabledTools: Set<String>? = nil, effectiveMaxToolCalls: Int = 10) async throws {
    // Check if we're in a proper terminal
#if canImport(Darwin) || canImport(Glibc)
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
    let toolExecutor = ToolExecutor(
      mcpServers: mcpConfigs,
      localToolsConfigPath: localToolsConfig,
      verbose: true, 
      useStderr: false,
      showToolEventsVerbose: showToolEventsVerbose
    )
    await toolExecutor.initialize()
    
    // Default to showing tool events in interactive mode
    // Tool events are always shown in interactive mode
    
    print("🤖 OpenAI Agent Mode (\(model))".cyan)
    if let allowedTools = allowedTools {
      print("Allowed tools: \(allowedTools)".lightBlack)
    }
    if !mcpConfigs.isEmpty {
      print("MCP servers: \(mcpConfigs.map { $0.name }.joined(separator: ", "))".lightBlack)
    }
    if let localToolsConfig = localToolsConfig {
      print("Local tools config: \(localToolsConfig)".lightBlack)
    }
    if !mcpConfigs.isEmpty || localToolsConfig != nil {
      print("🚀 Tools initialized once for this session".green)
    }
    print("Tool events: \(showToolEventsVerbose ? "VERBOSE" : "COMPACT")".lightBlack)
    let contextWindow = TokenCalculator.getContextWindow(for: model)
    print("Context window: \(contextWindow / 1000)K tokens".lightBlack)
    if contextWindow <= 5000 {
      print("⚠️  DEBUG MODE: Using reduced context window for testing".yellow)
    }
    print("Type 'exit' to quit, 'clear' to clear history, '/help' for commands, Ctrl+C to interrupt".lightBlack)
    print("")
    
    var currentSessionId = UUID().uuidString
    
    // Initialize input processor and slash command registry
    let inputProcessor = InputProcessor()
    let registry = SlashCommandRegistry.shared
    
    // Create command context
    var commandContext = CommandContext(
      sessionId: currentSessionId,
      currentModel: model,
      temperature: temperature,
      maxTokens: maxTokens,
      maxToolCalls: effectiveMaxToolCalls
    )
    
    // Keep track of current settings that might be changed by slash commands
    var currentModel = model
    var currentTemperature = temperature
    var currentMaxTokens = maxTokens
    var currentMaxToolCalls = effectiveMaxToolCalls
    
    // Set up signal handler for graceful exit
    // Note: Can't capture toolExecutor in signal handler, so cleanup happens in normal exit paths
    signal(SIGINT) { _ in
      print("\n\nInterrupted. Goodbye!".yellow)
      #if canImport(Darwin)
      Darwin.exit(0)
      #elseif canImport(Glibc)
      Glibc.exit(0)
      #endif
    }
    
    while true {
      // Use input processor for reading input with proper prompt
      guard let input = inputProcessor.readInput() else {
        // EOF detected (Ctrl+D)
        print("\nCleaning up MCP connections...".yellow)
        await toolExecutor.cleanup()
        print("Goodbye!".yellow)
        break
      }
      
      // Process input through the input processor
      let action = inputProcessor.processInput(input)
      
      switch action {
      case .empty:
        continue
        
      case .exit:
        print("Cleaning up MCP connections...".yellow)
        await toolExecutor.cleanup()
        print("Goodbye!".yellow)
        break
        
      case .clearScreen:
        print("Conversation cleared.".yellow)
        SessionManager.shared.clearSession(currentSessionId)
        currentSessionId = UUID().uuidString
        commandContext.sessionId = currentSessionId
        continue
        
      case .continueMultiline:
        continue
        
      case .cancelMultiline:
        print("Multiline input cancelled".yellow)
        continue
        
      case .slashCommand(let command):
        do {
          // Execute slash command
          let shouldContinue = try await registry.execute(command, context: &commandContext)
          if !shouldContinue {
            print("Cleaning up MCP connections...".yellow)
            await toolExecutor.cleanup()
            print("Goodbye!".yellow)
            break
          }
          // Update local variables if settings changed
          currentModel = commandContext.currentModel
          currentTemperature = commandContext.temperature
          currentMaxTokens = commandContext.maxTokens
          currentMaxToolCalls = commandContext.maxToolCalls ?? effectiveMaxToolCalls
        } catch {
          print("\(error.localizedDescription)".red)
        }
        continue
        
      case .message(let trimmedInput):
        // Validate input length (prevent extremely long inputs)
        guard trimmedInput.count <= 10000 else {
          print("Error: Message too long (max 10000 characters)".red)
          continue
        }
        
        do {
          // Always show tool events in interactive mode
          let format = "interactive-stream"
          // Note: We could pass timeout here if agentChatWithExecutor supported it
          try await OpenAIService.shared.agentChatWithExecutor(
            message: trimmedInput,
            model: currentModel,
            toolExecutor: toolExecutor,
            system: system,
            temperature: currentTemperature,
            maxTokens: currentMaxTokens,
            outputFormat: format,
            enabledTools: enabledTools,
            verbose: modelVerbosity.rawValue,
            reasoning: reasoning.rawValue,
            sessionId: currentSessionId,
            maxToolCalls: currentMaxToolCalls
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
      } // end switch
    }
    
    // Cleanup MCP connections when exiting
    await toolExecutor.cleanup()
    
    // Reset signal handler
    signal(SIGINT, SIG_DFL)
  }
}
