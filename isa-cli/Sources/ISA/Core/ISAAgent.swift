import Foundation
import SwiftOpenAICLICore
import SwiftOpenAI
import Rainbow

class ISAAgent {
  private let model: String
  private let temperature: Double
  private let verbose: Bool
  private let planMode: Bool
  private let showTodos: Bool
  private var todoList: TodoList
  private let openAIService: SwiftOpenAICLICore.OpenAIService
  
  init(model: String, temperature: Double, verbose: Bool, planMode: Bool, showTodos: Bool) throws {
    self.model = model
    self.temperature = temperature
    self.verbose = verbose
    self.planMode = planMode
    self.showTodos = showTodos
    self.todoList = TodoList()
    self.openAIService = SwiftOpenAICLICore.OpenAIService.shared
  }
  
  func processMessage(
    _ message: String,
    system: String?,
    maxTokens: Int?,
    outputFormat: String,
    sessionId: String?,
    mcpServers: String?,
    allowedTools: String?,
    localToolsConfig: String?,
    showToolEvents: Bool,
    timeout: Int?,
    maxToolCalls: Int
  ) async throws {
    
    // If plan mode, generate and confirm plan first
    if planMode {
      let plan = try await generatePlan(for: message, system: system)
      TerminalUI.showPlan(plan)
      
      guard TerminalUI.confirmPlan() else {
        TerminalUI.showCancelled()
        return
      }
    }
    
    // Show working indicator if verbose
    if verbose {
      TerminalUI.showWorking(on: "Processing request")
    }
    
    // Parse MCP servers
    let mcpConfigs = try parseMCPServers(mcpServers)
    
    // Enhanced local tools path resolution
    let resolvedToolsPath = resolveToolsPath(localToolsConfig)
    
    // Create tool executor with ISA tools
    let toolExecutor = try await createISAToolExecutor(
      mcpConfigs: mcpConfigs,
      localToolsPath: resolvedToolsPath,
      showToolEvents: showToolEvents
    )
    
    // Execute using SwiftOpenAICLI's agent chat
    try await openAIService.agentChatWithExecutor(
      message: message,
      model: model,
      toolExecutor: toolExecutor,
      system: system,
      temperature: temperature,
      maxTokens: maxTokens,
      outputFormat: outputFormat,
      enabledTools: parseAllowedTools(allowedTools),
      verbose: getVerbosityLevel(),
      reasoning: getReasoningLevel(),
      sessionId: sessionId,
      maxToolCalls: maxToolCalls
    )
    
    // Show final todos if enabled
    if showTodos && !todoList.todos.isEmpty {
      TerminalUI.showTodoSummary(todoList)
    }
  }
  
  func runInteractive(
    system: String?,
    sessionId: String?,
    mcpServers: String?,
    allowedTools: String?,
    localToolsConfig: String?,
    showToolEvents: Bool,
    timeout: Int?,
    maxToolCalls: Int
  ) async throws {
    
    TerminalUI.showInteractiveHelp()
    
    // Parse configurations once for the session
    let mcpConfigs = try parseMCPServers(mcpServers)
    let resolvedToolsPath = resolveToolsPath(localToolsConfig)
    let toolExecutor = try await createISAToolExecutor(
      mcpConfigs: mcpConfigs,
      localToolsPath: resolvedToolsPath,
      showToolEvents: showToolEvents
    )
    
    var currentSessionId = sessionId ?? UUID().uuidString
    
    // Initialize input processor and slash command registry
    let inputProcessor = InputProcessor()
    let registry = SlashCommandRegistry.shared
    
    // Create command context to track session state
    var commandContext = CommandContext(
      sessionId: currentSessionId,
      currentModel: model,
      temperature: temperature,
      maxTokens: nil,
      isAgentMode: true,
      enabledTools: parseAllowedTools(allowedTools)
    )
    
    // Keep track of current settings that might be changed by slash commands
    var currentModel = model
    var currentTemperature = temperature
    var currentMaxTokens: Int? = nil
    
    while true {
      // Use input processor for proper prompt handling
      guard let input = inputProcessor.readInput() else {
        // EOF detected (Ctrl+D)
        await toolExecutor.cleanup()
        TerminalUI.showGoodbye()
        break
      }
      
      // Process input through the input processor
      let action = inputProcessor.processInput(input)
      
      switch action {
      case .empty:
        continue
        
      case .exit:
        await toolExecutor.cleanup()
        TerminalUI.showGoodbye()
        break
        
      case .clearScreen:
        TerminalUI.clearScreen()
        TerminalUI.showISABanner()
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
        // Handle ISA-specific commands that aren't slash commands yet
        if command == "/todos" {
          TerminalUI.showTodoList(todoList)
          continue
        }
        
        do {
          // Execute slash command through registry
          let shouldContinue = try await registry.execute(command, context: &commandContext)
          if !shouldContinue {
            await toolExecutor.cleanup()
            TerminalUI.showGoodbye()
            break
          }
          // Update local variables if model or settings changed
          currentModel = commandContext.currentModel
          currentTemperature = commandContext.temperature
          currentMaxTokens = commandContext.maxTokens
        } catch {
          print("\(error.localizedDescription)".red)
        }
        continue
        
      case .message(let trimmedInput):
        // Validate input length
        guard trimmedInput.count <= 10000 else {
          TerminalUI.showError("Message too long (max 10000 characters)")
          continue
        }
        
        // Process the message
        do {
          if planMode {
            let plan = try await generatePlan(for: trimmedInput, system: system)
            TerminalUI.showPlan(plan)
            
            guard TerminalUI.confirmPlan() else {
              TerminalUI.showCancelled()
              continue
            }
          }
          
          try await openAIService.agentChatWithExecutor(
            message: trimmedInput,
            model: currentModel,  // Use potentially updated model
            toolExecutor: toolExecutor,
            system: system,
            temperature: currentTemperature,  // Use potentially updated temperature
            maxTokens: currentMaxTokens,  // Use potentially updated max tokens
            outputFormat: "plain",
            enabledTools: commandContext.enabledTools,  // Use context's enabled tools
            verbose: getVerbosityLevel(),
            reasoning: getReasoningLevel(),
            sessionId: currentSessionId,
            maxToolCalls: maxToolCalls
          )
          
          if showTodos && !todoList.todos.isEmpty {
            TerminalUI.showTodoSummary(todoList)
          }
          
          print() // Empty line for readability
          
        } catch {
          TerminalUI.showError("Error: \(error.localizedDescription)")
        }
      }
    }
  }
  
  private func generatePlan(for message: String, system: String?) async throws -> String {
    // Use a smaller model for planning
    let planningPrompt = """
    Generate a concise plan for accomplishing this task: \(message)
    
    List the key steps that would be taken to complete this request.
    Be specific and actionable.
    """
    
    // Use SwiftOpenAICLI's service for planning
    let service = try openAIService.getService()
    
    var messages: [ChatCompletionParameters.Message] = []
    if let system = system {
      messages.append(.init(role: .system, content: .text(system)))
    }
    messages.append(.init(role: .user, content: .text(planningPrompt)))
    
    let params = ChatCompletionParameters(
      messages: messages,
      model: .custom("gpt-5-mini"), // Use smaller model for planning
      temperature: 0.7
    )
    
    let result = try await service.startChat(parameters: params)
    return result.choices?.first?.message?.content ?? "No plan generated"
  }
  
  private func createISAToolExecutor(
    mcpConfigs: [MCPServerConfig],
    localToolsPath: String?,
    showToolEvents: Bool
  ) async throws -> ToolExecutor {
    
    // Create base tool executor
    let toolExecutor = ToolExecutor(
      mcpServers: mcpConfigs,
      localToolsConfigPath: localToolsPath,
      verbose: verbose,
      useStderr: false,
      showToolEventsVerbose: showToolEvents
    )
    
    // Initialize MCP and base tools
    await toolExecutor.initialize()
    
    // Add ISA-specific built-in tools
    registerISATools(to: toolExecutor)
    
    return toolExecutor
  }
  
  private func registerISATools(to executor: ToolExecutor) {
    // Register ISA's built-in tools
    
    // File and system tools
    executor.registerLocalTool(ISAReadTool())
    executor.registerLocalTool(ISAWriteTool())
    executor.registerLocalTool(ISAEditTool())
    executor.registerLocalTool(ISAGlobTool())
    executor.registerLocalTool(ISAGrepTool())
    executor.registerLocalTool(ISALSTool())
    executor.registerLocalTool(ISABashTool())
    
    // Task management tool
    executor.registerLocalTool(ISATodoTool(todoList: todoList))
    
    if verbose {
      print("✅ Registered ISA built-in tools".green)
    }
  }
  
  private func parseMCPServers(_ mcpServers: String?) throws -> [MCPServerConfig] {
    guard let mcpServers = mcpServers else { return [] }
    
    let configManager = ConfigurationManager.shared
    let config = configManager.getConfiguration()
    
    let requestedServers = Set(mcpServers.split(separator: ",").map { 
      String($0.trimmingCharacters(in: .whitespaces)) 
    })
    
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
  
  private func parseAllowedTools(_ patterns: String?) -> Set<String>? {
    guard let patterns = patterns else { return nil }
    let toolPatterns = patterns.split(separator: ",").map { 
      $0.trimmingCharacters(in: .whitespaces) 
    }
    return Set(toolPatterns)
  }
  
  private func resolveToolsPath(_ path: String?) -> String? {
    guard let path = path else {
      // Check for default ISA tools location
      let homeDir = FileManager.default.homeDirectoryForCurrentUser
      let isaToolsPath = homeDir.appendingPathComponent(".isa/tools.json").path
      if FileManager.default.fileExists(atPath: isaToolsPath) {
        return isaToolsPath
      }
      return nil
    }
    
    // Expand tilde if present
    if path.hasPrefix("~") {
      let homeDirectory = FileManager.default.homeDirectoryForCurrentUser.path
      return path.replacingOccurrences(of: "~", with: homeDirectory, 
        range: path.startIndex..<path.index(after: path.startIndex))
    }
    
    return path
  }
  
  private func getVerbosityLevel() -> String {
    return verbose ? "high" : "medium"
  }
  
  private func getReasoningLevel() -> String {
    return planMode ? "high" : "medium"
  }
}