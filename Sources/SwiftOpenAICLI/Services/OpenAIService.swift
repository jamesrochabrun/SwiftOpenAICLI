import Foundation
import SwiftOpenAI
import Rainbow

final class OpenAIService {
  
  static let shared = OpenAIService()
  
  private var service: (any SwiftOpenAI.OpenAIService)?
  
  private init() {}
  
  func getService() throws -> any SwiftOpenAI.OpenAIService {
    guard let apiKey = ConfigurationManager.shared.apiKey else {
      print("✗ No API key found!".red)
      print("Set your API key using one of these methods:".yellow)
      print("1. Environment variable: export OPENAI_API_KEY=sk-...")
      print("2. CLI config: swiftopenai config set api-key sk-...")
      throw OpenAIServiceError.noAPIKey
    }
    
    if service == nil {
      // Check if we have a custom provider configuration
      if let _ = ConfigurationManager.shared.provider,
         let baseURL = ConfigurationManager.shared.baseURL {
        // Use custom provider configuration
        let debugEnabled = ConfigurationManager.shared.debugEnabled ?? false
        service = OpenAIServiceFactory.service(
          apiKey: apiKey,
          overrideBaseURL: baseURL,
          debugEnabled: debugEnabled
        )
      } else {
        // Use standard OpenAI configuration
        let debugEnabled = ConfigurationManager.shared.debugEnabled ?? false
        service = OpenAIServiceFactory.service(
          apiKey: apiKey,
          debugEnabled: debugEnabled
        )
      }
    }
    
    return service!
  }
  
  /// Normalizes model names to match OpenAI API expectations
  /// Maps common aliases to official model names (e.g., gpt5 → gpt-5)
  private func normalizeModelName(_ model: String) -> String {
    let lowercased = model.lowercased()
    
    // GPT-5 model aliases
    switch lowercased {
    case "gpt5":
      return "gpt-5"
    case "gpt5mini", "gpt5-mini":
      return "gpt-5-mini"
    case "gpt5nano", "gpt5-nano":
      return "gpt-5-nano"
    default:
      // Return the original model name for all other models
      return model
    }
  }
  
  func chat(message: String, model: String, system: String? = nil, temperature: Double = 1.0, maxTokens: Int? = nil, stream: Bool = true, plain: Bool = false, verbose: String = "medium", reasoning: String = "medium") async throws {
    let openAI = try getService()
    
    // Normalize the model name
    let normalizedModel = normalizeModelName(model)
    
    var messages: [ChatCompletionParameters.Message] = []
    
    if let system = system {
      messages.append(.init(role: .system, content: .text(system)))
    }
    
    messages.append(.init(role: .user, content: .text(message)))
    
    // Check if this is a GPT-5 model (using normalized name for consistency)
    let isGPT5Model = normalizedModel.lowercased().contains("gpt-5")
    
    var parameters = ChatCompletionParameters(
      messages: messages,
      model: .custom(normalizedModel),
      maxTokens: maxTokens,
      temperature: temperature
    )
    
    // Add verbosity and reasoning parameters for GPT-5 models
    if isGPT5Model {
      parameters.verbosity = verbose
      parameters.reasoningEffort = reasoning
    }
    
    if stream {
      if !plain {
        print("Assistant: ".cyan, terminator: "")
        fflush(stdout)
      }
      
      let stream = try await openAI.startStreamedChat(parameters: parameters)
      
      for try await result in stream {
        if let content = result.choices?.first?.delta?.content {
          print(content, terminator: "")
          fflush(stdout)
        }
      }
      print() // New line after streaming
    } else {
      // Show loading indicator for non-streaming mode
      if !plain {
        print("Thinking...".lightBlack, terminator: "")
        fflush(stdout)
      }
      
      // Add timeout handling with Task
      let result = try await withThrowingTaskGroup(of: ChatCompletionObject.self) { group in
        group.addTask {
          return try await openAI.startChat(parameters: parameters)
        }
        
        group.addTask {
          // Timeout task - increase timeout for GPT-5 models
          let timeoutSeconds = normalizedModel.lowercased().contains("gpt-5") ? 180 : 60
          try await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
          throw OpenAIServiceError.timeout(seconds: timeoutSeconds)
        }
        
        // Return the first completed task (either result or timeout)
        if let result = try await group.next() {
          group.cancelAll()
          return result
        }
        throw OpenAIServiceError.timeout(seconds: 60)
      }
      
      // Clear the loading indicator
      if !plain {
        print("\r", terminator: "") // Carriage return to overwrite "Thinking..."
        fflush(stdout)
      }
      
      if let content = result.choices?.first?.message?.content {
        if plain {
          print(content)
        } else {
          print("Assistant: ".cyan + content)
        }
      }
    }
  }
  
  func listModels() async throws -> [ModelObject] {
    let openAI = try getService()
    let response = try await openAI.listModels()
    return response.data.sorted { $0.id < $1.id }
  }
  
  func generateImage(prompt: String, model: String, size: String, quality: String, n: Int) async throws -> CreateImageResponse {
    let openAI = try getService()
    
    let imageModel: CreateImageParameters.Model = model == "dall-e-2" ? .dallE2 : .dallE3
    let imageQuality: CreateImageParameters.Quality = quality == "hd" ? .hd : .standard
    
    let parameters = CreateImageParameters(
      prompt: prompt,
      model: imageModel,
      n: n,
      quality: imageQuality,
      size: size
    )
    
    return try await openAI.createImages(parameters: parameters)
  }
  
  // Completions API is deprecated, use chat instead
  
  func generateEmbedding(text: String, model: String, dimensions: Int? = nil) async throws -> [Float] {
    let openAI = try getService()
    
    let parameters = EmbeddingParameter(
      input: text,
      model: .textEmbeddingAda002,  // Only ada-002 is supported in the enum
      encodingFormat: "float",
      dimensions: dimensions
    )
    
    let response = try await openAI.createEmbeddings(parameters: parameters)
    return response.data.first?.embedding ?? []
  }
  
  func agentChat(message: String, model: String, system: String? = nil, temperature: Double = 1.0, maxTokens: Int? = nil, outputFormat: String = "plain", enabledTools: Set<String>?, verbose: String = "medium", reasoning: String = "medium", sessionId: String? = nil, mcpServers: [MCPServerConfig] = [], showMCPStatus: Bool = false, timeout: Int = 60, showToolEventsVerbose: Bool = false) async throws {
    let useStderr = (outputFormat == "json" || outputFormat == "stream-json")
    // Show MCP status if explicitly requested OR if using plain output format
    let showMCP = showMCPStatus || outputFormat == "plain"
    let toolExecutor = ToolExecutor(mcpServers: mcpServers, verbose: showMCP, useStderr: useStderr, showToolEventsVerbose: showToolEventsVerbose)
    
    // Initialize MCP servers if any
    await toolExecutor.initialize()
    
    // Delegate to the executor-based method
    try await agentChatWithExecutor(
      message: message,
      model: model,
      toolExecutor: toolExecutor,
      system: system,
      temperature: temperature,
      maxTokens: maxTokens,
      outputFormat: outputFormat,
      enabledTools: enabledTools,
      verbose: verbose,
      reasoning: reasoning,
      sessionId: sessionId
    )
  }
  
  func agentChatWithExecutor(message: String, model: String, toolExecutor: ToolExecutor, system: String? = nil, temperature: Double = 1.0, maxTokens: Int? = nil, outputFormat: String = "plain", enabledTools: Set<String>?, verbose: String = "medium", reasoning: String = "medium", sessionId: String? = nil) async throws {
    let openAI = try getService()
    
    let normalizedModel = normalizeModelName(model)
    let isGPT5Model = normalizedModel.lowercased().contains("gpt-5")
    
    var messages: [ChatCompletionParameters.Message] = []
    
    // Get existing session messages if session ID is provided
    if let sessionId = sessionId {
      messages = SessionManager.shared.getMessages(for: sessionId)
      
      // Check if we need to compact before adding new message
      let currentTokens = TokenCalculator.estimateTokens(for: messages)
      let newMessageTokens = TokenCalculator.estimateTokens(for: message)
      let projectedTokens = currentTokens + newMessageTokens
      
      if TokenCalculator.shouldCompact(tokens: projectedTokens, for: normalizedModel) {
        // Show compaction warning
        if let warning = TokenCalculator.formatCapacityWarning(tokens: currentTokens, for: normalizedModel) {
          print(warning.yellow)
        }
        
        // Perform compaction
        let compactor = ConversationCompactor()
        let compactedMessage = try await compactor.compactConversation(
          messages: messages,
          currentModel: normalizedModel
        )
        
        // Replace messages with compacted version
        SessionManager.shared.compactSession(sessionId, with: compactedMessage)
        messages = [compactedMessage]
        
        // Show compaction count
        let compactionCount = SessionManager.shared.getCompactionCount(for: sessionId)
        print("📚 Conversation compacted \(compactionCount) time\(compactionCount == 1 ? "" : "s")".lightBlack)
        print("")
      } else if let warning = TokenCalculator.formatCapacityWarning(tokens: currentTokens, for: normalizedModel) {
        // Show capacity warning if above 80%
        print(warning.yellow)
      }
      
      // Add system message if not already present and provided
      if let system = system, !messages.contains(where: { msg in
        msg.role == "system"
      }) {
        messages.insert(.init(role: .system, content: .text(system)), at: 0)
      }
    } else if let system = system {
      messages.append(.init(role: .system, content: .text(system)))
    }
    
    // Add the new user message
    let userMessage = ChatCompletionParameters.Message(role: .user, content: .text(message))
    messages.append(userMessage)
    
    // Save initial state if session exists
    if let sessionId = sessionId, !SessionManager.shared.sessionExists(sessionId) {
      SessionManager.shared.updateMessages(messages, for: sessionId)
    }
    
    let tools = toolExecutor.getToolDefinitions(for: enabledTools)
    
    var parameters = ChatCompletionParameters(
      messages: messages,
      model: .custom(normalizedModel),
      tools: tools.isEmpty ? nil : tools,
      maxTokens: maxTokens,
      temperature: temperature
    )
    
    if isGPT5Model {
      parameters.verbosity = verbose
      parameters.reasoningEffort = reasoning
    }
    
    let session = sessionId ?? UUID().uuidString
    let startTime = Date()
    
    // Emit init event for stream-json format
    if outputFormat == "stream-json" {
      let initEvent: [String: Any] = [
        "type": "system",
        "subtype": "init",
        "session_id": session,
        "model": normalizedModel,
        "tools": enabledTools != nil ? Array(enabledTools!) : [],
        "cwd": FileManager.default.currentDirectoryPath
      ]
      if let jsonData = try? JSONSerialization.data(withJSONObject: initEvent, options: []),
         let jsonString = String(data: jsonData, encoding: .utf8) {
        print(jsonString)
        fflush(stdout)
      }
    } else if outputFormat == "plain" || outputFormat == "interactive-stream" {
      print("Assistant: ".cyan + "(thinking...)", terminator: "")
      fflush(stdout)
    }
    
    var conversationMessages = messages
    var toolCallCount = 0
    let maxToolCalls = 10
    var totalCost: Double = 0.0
    var numTurns = 0
    var finalResponse = ""
    
    while toolCallCount < maxToolCalls {
      parameters.messages = conversationMessages
      numTurns += 1
      
      // Add timeout handling with Task
      let result = try await withThrowingTaskGroup(of: ChatCompletionObject.self) { group in
        group.addTask {
          return try await openAI.startChat(parameters: parameters)
        }
        
        group.addTask {
          // Timeout task - increase timeout for GPT-5 models
          let timeoutSeconds = normalizedModel.lowercased().contains("gpt-5") ? 180 : 60
          try await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
          throw OpenAIServiceError.timeout(seconds: timeoutSeconds)
        }
        
        // Return the first completed task (either result or timeout)
        if let result = try await group.next() {
          group.cancelAll()
          return result
        }
        throw OpenAIServiceError.timeout(seconds: 60)
      }
      
      if outputFormat == "plain" || outputFormat == "interactive-stream" {
        print("\r", terminator: "")
        fflush(stdout)
      }
      
      // Emit assistant message event for stream-json
      if outputFormat == "stream-json" {
        let messageEvent: [String: Any] = [
          "type": "assistant",
          "session_id": session,
          "message": [
            "role": "assistant",
            "content": result.choices?.first?.message?.content ?? ""
          ]
        ]
        if let jsonData = try? JSONSerialization.data(withJSONObject: messageEvent, options: []),
           let jsonString = String(data: jsonData, encoding: .utf8) {
          print(jsonString)
          fflush(stdout)
        }
      }
      
      if let toolCalls = result.choices?.first?.message?.toolCalls, !toolCalls.isEmpty {
        let assistantMessage = result.choices?.first?.message
        if let content = assistantMessage?.content {
          conversationMessages.append(.init(
            role: .assistant,
            content: .text(content),
            toolCalls: toolCalls
          ))
        } else {
          conversationMessages.append(.init(
            role: .assistant,
            content: .text(""),
            toolCalls: toolCalls
          ))
        }
        
        for toolCall in toolCalls {
          guard let toolId = toolCall.id,
                let toolName = toolCall.function.name else { continue }
          
          // Emit tool call event for stream-json and interactive-stream
          if outputFormat == "stream-json" {
            let toolEvent: [String: Any] = [
              "type": "tool_call",
              "session_id": session,
              "tool": toolName,
              "arguments": toolCall.function.arguments
            ]
            if let jsonData = try? JSONSerialization.data(withJSONObject: toolEvent, options: []),
               let jsonString = String(data: jsonData, encoding: .utf8) {
              print(jsonString)
              fflush(stdout)
            }
          } else if outputFormat == "interactive-stream" {
            print("\n→ ".lightBlack + "Calling tool: ".lightBlack + toolName.yellow + " " + toolCall.function.arguments.lightBlack)
            fflush(stdout)
          }
          
          let effectiveFormat = outputFormat == "interactive-stream" ? "silent" : outputFormat
          let result = try await toolExecutor.executeTool(
            name: toolName,
            arguments: toolCall.function.arguments,
            outputFormat: effectiveFormat
          )
          
          // Emit tool result event
          if outputFormat == "stream-json" {
            let resultEvent: [String: Any] = [
              "type": "tool_result",
              "session_id": session,
              "tool": toolName,
              "result": result
            ]
            if let jsonData = try? JSONSerialization.data(withJSONObject: resultEvent, options: []),
               let jsonString = String(data: jsonData, encoding: .utf8) {
              print(jsonString)
              fflush(stdout)
            }
          } else if outputFormat == "interactive-stream" {
            print("← ".lightBlack + "Result: ".lightBlack + result.green)
            fflush(stdout)
          }
          
          conversationMessages.append(.init(
            role: .tool,
            content: .text(result),
            toolCallID: toolId
          ))
        }
        
        toolCallCount += toolCalls.count
      } else {
        // Final response
        if let content = result.choices?.first?.message?.content {
          finalResponse = content
          // Add assistant's response to conversation
          conversationMessages.append(.init(role: .assistant, content: .text(content)))
          
          if outputFormat == "plain" || outputFormat == "interactive-stream" {
            if outputFormat == "interactive-stream" {
              print() // Add newline after tool results
            }
            print("Assistant: ".cyan + content)
          }
        }
        break
      }
    }
    
    // Save updated conversation to session if session ID is provided
    if let sessionId = sessionId {
      SessionManager.shared.updateMessages(conversationMessages, for: sessionId)
    }
    
    let duration = Date().timeIntervalSince(startTime) * 1000
    
    // Emit result event
    if outputFormat == "stream-json" {
      let resultEvent: [String: Any] = [
        "type": "result",
        "subtype": toolCallCount >= maxToolCalls ? "error_max_turns" : "success",
        "session_id": session,
        "duration_ms": Int(duration),
        "num_turns": numTurns,
        "is_error": toolCallCount >= maxToolCalls,
        "result": finalResponse,
        "total_cost_usd": totalCost
      ]
      if let jsonData = try? JSONSerialization.data(withJSONObject: resultEvent, options: []),
         let jsonString = String(data: jsonData, encoding: .utf8) {
        print(jsonString)
        fflush(stdout)
      }
    } else if outputFormat == "json" {
      let result: [String: Any] = [
        "type": "result",
        "subtype": "success",
        "total_cost_usd": totalCost,
        "is_error": false,
        "duration_ms": Int(duration),
        "num_turns": numTurns,
        "result": finalResponse,
        "session_id": session
      ]
      if let jsonData = try? JSONSerialization.data(withJSONObject: result, options: .prettyPrinted),
         let jsonString = String(data: jsonData, encoding: .utf8) {
        print(jsonString)
      }
    } else if toolCallCount >= maxToolCalls && (outputFormat == "plain" || outputFormat == "interactive-stream") {
      print("\n⚠️  Maximum tool calls reached".yellow)
    }
  }
}

enum OpenAIServiceError: LocalizedError {
  case noAPIKey
  case timeout(seconds: Int)
  
  var errorDescription: String? {
    switch self {
    case .noAPIKey:
      return "No OpenAI API key configured"
    case .timeout(let seconds):
      return "Request timed out after \(seconds) seconds"
    }
  }
}
