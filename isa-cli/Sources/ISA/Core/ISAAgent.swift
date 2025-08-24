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
    
    while true {
      // Show prompt
      TerminalUI.showPrompt()
      
      guard let input = readLine() else { break }
      let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
      
      // Handle special commands
      if trimmed.lowercased() == "exit" || trimmed.lowercased() == "quit" {
        TerminalUI.showGoodbye()
        break
      }
      
      if trimmed.lowercased() == "clear" {
        TerminalUI.clearScreen()
        TerminalUI.showISABanner()
        continue
      }
      
      if trimmed.lowercased() == "todos" {
        TerminalUI.showTodoList(todoList)
        continue
      }
      
      if trimmed.lowercased() == "help" {
        TerminalUI.showInteractiveHelp()
        continue
      }
      
      if trimmed.isEmpty {
        continue
      }
      
      // Process the message
      do {
        if planMode {
          let plan = try await generatePlan(for: trimmed, system: system)
          TerminalUI.showPlan(plan)
          
          guard TerminalUI.confirmPlan() else {
            TerminalUI.showCancelled()
            continue
          }
        }
        
        try await openAIService.agentChatWithExecutor(
          message: trimmed,
          model: model,
          toolExecutor: toolExecutor,
          system: system,
          temperature: temperature,
          maxTokens: nil,
          outputFormat: "plain",
          enabledTools: parseAllowedTools(allowedTools),
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