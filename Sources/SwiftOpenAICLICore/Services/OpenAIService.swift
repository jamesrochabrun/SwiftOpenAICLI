import Foundation
import SwiftOpenAI
import Rainbow
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

public final class OpenAIService {
  
  public static let shared = OpenAIService()
  
  private var service: (any SwiftOpenAI.OpenAIService)?
  
  private init() {}
  
  public func getService() throws -> any SwiftOpenAI.OpenAIService {
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
  
  func chat(message: String, model: String, system: String? = nil, temperature: Double = 1.0, maxTokens: Int? = nil, stream: Bool = true, plain: Bool = false, verbose: String = "medium", reasoning: String = "medium", timeout: Int = 60) async throws {
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
    
    // Start ESC monitoring
    let escMonitor = ESCMonitor.shared
    escMonitor.reset()
    escMonitor.startMonitoring()
    defer { escMonitor.stopMonitoring() }
    
    if stream {
      if !plain {
        print("Assistant: ".cyan, terminator: "")
        fflush(stdout)
      }
      
      let stream = try await openAI.startStreamedChat(parameters: parameters)
      
      for try await result in stream {
        // Check for ESC key cancellation
        if escMonitor.wasCancelled() {
          print("\n" + "Interrupted by user".yellow)
          break
        }
        
        if let content = result.choices?.first?.delta?.content {
          print(content, terminator: "")
          fflush(stdout)
        }
      }
      print() // New line after streaming
    } else {
      // Show animated loading indicator for non-streaming mode
      let indicator: LoadingIndicator?
      let useAnimated = ConfigurationManager.shared.getConfiguration().animatedLoading ?? true
      if !plain && useAnimated {
        // For non-agent mode, we don't force AI words
        let thinkingWord = await LoadingWordGenerator.shared.getThinkingWord(useAI: false, forceAI: false)
        indicator = LoadingIndicator(word: thinkingWord, color: { $0.lightBlack })
        indicator?.start()
      } else if !plain {
        // Static loading if animation is disabled
        print("Thinking...".lightBlack, terminator: "")
        fflush(stdout)
        indicator = nil
      } else {
        indicator = nil
      }
      
      // Add timeout handling with Task and ESC cancellation
      let result: ChatCompletionObject
      do {
        result = try await withThrowingTaskGroup(of: ChatCompletionObject.self) { group in
          group.addTask {
            return try await openAI.startChat(parameters: parameters)
          }
          
          // Add ESC monitoring task
          group.addTask {
            while true {
              if escMonitor.wasCancelled() {
                throw CancellationError()
              }
              try await Task.sleep(nanoseconds: 25_000_000) // 25ms - check more frequently
            }
          }
          
          group.addTask {
            // Timeout task - use provided timeout or default based on model
            let timeoutSeconds = timeout > 0 ? timeout : (normalizedModel.lowercased().contains("gpt-5") ? 180 : 60)
            try await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
            throw OpenAIServiceError.timeout(seconds: timeoutSeconds)
          }
          
          // Return the first completed task (either result or timeout)
          if let result = try await group.next() {
            group.cancelAll()
            return result
          }
          throw OpenAIServiceError.timeout(seconds: timeout)
        }
      } catch is CancellationError {
        // Handle ESC cancellation gracefully
        indicator?.stop()
        print("\n" + "Interrupted by user".yellow)
        return  // Exit gracefully without throwing
      } catch {
        // Stop indicator on any error
        indicator?.stop()
        throw error
      }
      
      // Clear the loading indicator
      indicator?.stop()
      
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
  
  func agentChat(message: String, model: String, system: String? = nil, temperature: Double = 1.0, maxTokens: Int? = nil, outputFormat: String = "plain", enabledTools: Set<String>?, verbose: String = "medium", reasoning: String = "medium", sessionId: String? = nil, mcpServers: [MCPServerConfig] = [], localToolsConfig: String? = nil, showMCPStatus: Bool = false, timeout: Int = 60, showToolEventsVerbose: Bool = false, maxToolCalls: Int = 10) async throws {
    let useStderr = (outputFormat == "json" || outputFormat == "stream-json")
    // Show MCP status if explicitly requested OR if using plain output format
    let showMCP = showMCPStatus || outputFormat == "plain"
    let toolExecutor = ToolExecutor(mcpServers: mcpServers, localToolsConfigPath: localToolsConfig, verbose: showMCP, useStderr: useStderr, showToolEventsVerbose: showToolEventsVerbose)
    
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
      sessionId: sessionId,
      timeout: timeout,
      maxToolCalls: maxToolCalls
    )
  }
  
  public func agentChatWithExecutor(message: String, model: String, toolExecutor: ToolExecutor, system: String? = nil, temperature: Double = 1.0, maxTokens: Int? = nil, outputFormat: String = "plain", enabledTools: Set<String>?, verbose: String = "medium", reasoning: String = "medium", sessionId: String? = nil, timeout: Int = 60, maxToolCalls: Int = 10) async throws {
    let openAI = try getService()
    let outputHelper = OutputHelper(outputFormat: outputFormat)
    
    // Start ESC monitoring for agent
    let escMonitor = ESCMonitor.shared
    escMonitor.reset()
    escMonitor.startMonitoring()
    defer { escMonitor.stopMonitoring() }
    
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
          outputHelper.printDiagnostic(warning, color: { $0.yellow })
        }
        
        // Perform compaction
        let compactor = ConversationCompactor()
        let compactedMessage = try await compactor.compactConversation(
          messages: messages,
          currentModel: normalizedModel,
          outputHelper: outputHelper
        )
        
        // Replace messages with compacted version
        SessionManager.shared.compactSession(sessionId, with: compactedMessage)
        messages = [compactedMessage]
        
        // Show compaction count
        let compactionCount = SessionManager.shared.getCompactionCount(for: sessionId)
        outputHelper.printDiagnostic("📚 Conversation compacted \(compactionCount) time\(compactionCount == 1 ? "" : "s")", color: { $0.lightBlack })
        outputHelper.printDiagnostic("")
      } else if let warning = TokenCalculator.formatCapacityWarning(tokens: currentTokens, for: normalizedModel) {
        // Show capacity warning if above 80%
        outputHelper.printDiagnostic(warning, color: { $0.yellow })
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
      toolChoice: tools.isEmpty ? nil : .auto,
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
    }
    
    var conversationMessages = messages
    var toolCallCount = 0
    // maxToolCalls is now passed as a parameter
    let totalCost: Double = 0.0
    var numTurns = 0
    var finalResponse = ""
    
    
    while toolCallCount < maxToolCalls {
      parameters.messages = conversationMessages
      numTurns += 1
      
      // Debug logging  
      if verbose == "high" || outputFormat == "plain" {
        print("\n🔍 Turn \(numTurns): Making API request with \(conversationMessages.count) messages".lightBlack)
        print("   Last message role: \(conversationMessages.last?.role ?? "none")".lightBlack)
        if let lastMessage = conversationMessages.last {
          if lastMessage.role == "tool" {
            let preview = String(describing: lastMessage.content).prefix(100)
            print("   Tool response preview: \(preview)...".lightBlack)
          }
        }
      }
      
      // Show loading indicator while waiting for assistant response
      let indicator: LoadingIndicator?
      if outputFormat == "interactive-stream" {
        // Always use animated indicator for consistency
        let fallbackWord = LoadingWordGenerator.shared.getThinkingWordSync()
        if numTurns > 1 {
          // After tools: add newline first for separation
          print()
        }
        indicator = LoadingIndicator(word: "("+fallbackWord+"...)", color: { $0.lightBlack })
        indicator?.start()
        
        // Fire-and-forget: Try AI word in background
        Task {
          _ = await LoadingWordGenerator.shared.getThinkingWord(useAI: false, forceAI: true)
        }
      } else {
        indicator = nil
      }
      
      // Add timeout handling with Task and ESC cancellation
      let result: ChatCompletionObject
      do {
        result = try await withThrowingTaskGroup(of: ChatCompletionObject.self) { group in
          group.addTask {
            return try await openAI.startChat(parameters: parameters)
          }
          
          // Add ESC monitoring task
          group.addTask {
            while true {
              if escMonitor.wasCancelled() {
                throw CancellationError()
              }
              try await Task.sleep(nanoseconds: 25_000_000) // 25ms - check more frequently
            }
          }
          
          group.addTask {
            // Timeout task - use provided timeout or default based on model
            let timeoutSeconds = timeout > 0 ? timeout : (normalizedModel.lowercased().contains("gpt-5") ? 180 : 60)
            try await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
            throw OpenAIServiceError.timeout(seconds: timeoutSeconds)
          }
          
          // Return the first completed task (either result or timeout)
          if let result = try await group.next() {
            group.cancelAll()
            return result
          }
          throw OpenAIServiceError.timeout(seconds: timeout)
        }
      } catch is CancellationError {
        // Handle ESC cancellation gracefully
        indicator?.stop()
        print("\n" + "Interrupted by user".yellow)
        
        // If this is the first turn with no tool calls yet, just break
        if numTurns == 1 && toolCallCount == 0 {
          break
        }
        
        // If we have pending tool calls that need responses, send "Interrupted" message
        // This shouldn't normally happen as tool calls are handled separately
        break
      } catch {
        // Stop indicators on any error
        indicator?.stop()
        throw error
      }
      
      // Don't stop loading indicator here - wait until we're about to display content
      
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
        // Stop loading indicator before showing any output
        if outputFormat == "interactive-stream" && indicator != nil {
          // We're about to show tool execution, stop without clearing
          indicator?.stopWithoutClearing()
        } else {
          indicator?.stop()
        }
        
        let assistantMessage = result.choices?.first?.message
        
        // Show assistant's narration/reasoning if present
        if outputFormat == "interactive-stream" {
          if let content = assistantMessage?.content, !content.isEmpty {
            // Display the assistant's explanation before tool execution
            print("\rAssistant: ".cyan + content.lightBlack)
            print() // Add newline before tool execution display
          } else if toolCalls.count == 1 {
            // For single tool call without narration, synthesize context with actual arguments
            if let toolCall = toolCalls.first {
              let context = synthesizeToolContext(toolCall: toolCall)
              print("\rAssistant: ".cyan + context.lightBlack)
              print()
            }
          }
        }
        
        // Debug logging
        if verbose == "high" || outputFormat == "plain" {
          print("📞 Received \(toolCalls.count) tool call\(toolCalls.count == 1 ? "" : "s") from LLM".lightBlack)
          for (index, toolCall) in toolCalls.enumerated() {
            print("   Tool \(index + 1): \(toolCall.function.name ?? "unknown")".lightBlack)
          }
        }
        
        // Save to conversation history
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
            // Overwrite loading indicator with tool execution message
            print("\r🔧 Executing tool: ".lightBlack + toolName.cyan)
            
            // Show arguments if verbose
            if verbose == "high" {
              let args = toolExecutor.truncateForDisplay(toolCall.function.arguments)
              print("   Arguments: ".lightBlack + args.lightBlack)
            }
            
            // Show animated loading indicator if enabled
            let config = ConfigurationManager.shared.getConfiguration()
            let useAnimated = config.animatedLoading ?? true
            
            let indicator: LoadingIndicator?
            if useAnimated {
              // Use fallback immediately - NO DELAY before tool execution
              let fallbackWord = LoadingWordGenerator.shared.getRandomFallbackForTool(toolName)
              indicator = LoadingIndicator(word: "   \(fallbackWord)", color: { $0.cyan })
              indicator?.start()
              
              // Fire-and-forget: Try AI word in background
              Task {
                _ = await LoadingWordGenerator.shared.getLoadingWord(for: toolName, useAI: false, forceAI: true)
              }
            } else {
              indicator = nil
            }
            
            // Check for ESC before tool execution
            if escMonitor.wasCancelled() {
              indicator?.stop()
              print("\n" + "Interrupted by user".yellow)
              break
            }
            
            let result = try await toolExecutor.executeTool(
              name: toolName,
              arguments: toolCall.function.arguments,
              outputFormat: "silent"
            )
            
            indicator?.stop()
            
            // Check for ESC after tool execution
            if escMonitor.wasCancelled() {
              print("\n" + "Interrupted by user".yellow)
              break
            }
            
            // Display result with conditional markdown rendering
            let truncatedResult = toolExecutor.truncateForDisplay(result)
            
            // Apply markdown rendering only if the tool and content benefit from it
            let renderedResult = shouldRenderMarkdown(toolName: toolName, result: truncatedResult) 
                ? MarkdownHelper.renderIfNeeded(truncatedResult)
                : truncatedResult
            
            // Check if result has multiple lines
            let resultLines = renderedResult.components(separatedBy: "\n").filter { !$0.isEmpty }
            if resultLines.count > 1 {
              print("   ✓ ".green + "Result:".lightBlack)
              for line in resultLines.prefix(10) {  // Show first 10 lines
                print("      " + line)
              }
              if resultLines.count > 10 {
                print("      " + "... (\(resultLines.count - 10) more lines)".lightBlack)
              }
            } else {
              // Single line result
              print("   ✓ ".green + renderedResult)
            }
            fflush(stdout)
            
            conversationMessages.append(.init(
              role: .tool,
              content: .text(result),
              toolCallID: toolId
            ))
            
            continue  // Skip the duplicate code below
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
            // This case shouldn't be reached anymore since we display results above
            // But keeping for safety with conditional markdown rendering
            let truncatedResult = toolExecutor.truncateForDisplay(result)
            let renderedResult = shouldRenderMarkdown(toolName: toolName, result: truncatedResult)
                ? MarkdownHelper.renderIfNeeded(truncatedResult)
                : truncatedResult
            print("   ✓ ".green + renderedResult)
            fflush(stdout)
          }
          
          conversationMessages.append(.init(
            role: .tool,
            content: .text(result),
            toolCallID: toolId
          ))
          
          // Debug logging
          if verbose == "high" || outputFormat == "plain" {
            print("✅ Added tool response to conversation (\(result.count) chars)".lightBlack)
            print("   Tool call ID: \(toolId)".lightBlack)
            // Only show preview for long responses
            if result.count > 200 {
              print("   Response preview: \(result.prefix(100))...".lightBlack)
            }
          }
        }
        
        // Check if we were interrupted during tool execution
        if escMonitor.wasCancelled() {
          // Exit the main loop if interrupted
          break
        }
        
        toolCallCount += toolCalls.count
        
        // Debug logging - show loop status
        if verbose == "high" || outputFormat == "plain" {
          print("🔄 Loop status: toolCallCount=\(toolCallCount)/\(maxToolCalls), continuing...".lightBlack)
          print("")  // Add spacing for readability
        }
      } else {
        // Final response - use streaming for interactive modes
        if outputFormat == "plain" || outputFormat == "interactive-stream" {
          // Stream the final response with ESC detection
          // Note: newline already added when starting indicator for numTurns > 1
          
          // For non-streaming mode, show Assistant label immediately
          if outputFormat != "interactive-stream" {
            print("Assistant: ".cyan, terminator: "")
          }
          // For interactive-stream mode, the loading indicator was already started before API call
          
          var streamedContent = ""
          var isFirstToken = true
          
          // Debug logging
          if verbose == "high" {
            print("[DEBUG] Starting stream, indicator=\(indicator != nil), numTurns=\(numTurns)".lightBlack)
          }
          
          let stream = try await openAI.startStreamedChat(parameters: parameters)
          
          // Stream the response
          for try await streamResult in stream {
            // Check for ESC key cancellation periodically
            if escMonitor.wasCancelled() {
              print("\n⚠️  Request cancelled by user".yellow)
              break
            }
            
            if let content = streamResult.choices?.first?.delta?.content {
              // On first token, overwrite loading with Assistant label + token
              if isFirstToken {
                if outputFormat == "interactive-stream" {
                  // Stop indicator first before any printing
                  indicator?.stopWithoutClearing()
                  
                  // Single operation to overwrite loading with content
                  let assistantLabel = "Assistant: ".cyan
                  let clearSpaces = String(repeating: " ", count: 30)
                  // Print with enough spaces to clear any loading text, then reposition
                  print("\r\(assistantLabel)\(content)\(clearSpaces)\r\(assistantLabel)\(content)", terminator: "")
                  fflush(stdout)
                } else {
                  indicator?.stop()  // Normal stop for non-interactive
                  print(content, terminator: "")
                  fflush(stdout)
                }
                isFirstToken = false
                streamedContent += content
              } else {
                // Subsequent tokens just append
                print(content, terminator: "")
                fflush(stdout)
                streamedContent += content
              }
            }
          }
          
          // Handle completion based on whether we got content
          if streamedContent.isEmpty {
            // No content received - show error message
            if outputFormat == "interactive-stream" {
              indicator?.stop()
              print("\rAssistant: [No response received - please try again]".yellow)
            }
            // Debug logging
            if verbose == "high" {
              print("\n[ERROR] Stream completed with no content".red)
            }
            // Save placeholder to maintain conversation flow
            finalResponse = "[No response]"
            conversationMessages.append(.init(role: .assistant, content: .text("[No response]")))
          } else {
            // Normal completion - add newline after content
            print()
            indicator?.stop()
            
            // Save the response
            if !escMonitor.wasCancelled() {
              finalResponse = streamedContent
              conversationMessages.append(.init(role: .assistant, content: .text(streamedContent)))
            }
          }
          
          // Debug logging
          if verbose == "high" {
            print("\n🏁 Received final response from LLM (no tool calls)".lightBlack)
            print("   Response length: \(finalResponse.count) chars".lightBlack)
          }
        } else {
          // Non-streaming mode (json, stream-json)
          if let content = result.choices?.first?.message?.content {
            finalResponse = content
            
            // Debug logging
            if verbose == "high" {
              print("🏁 Received final response from LLM (no tool calls)".lightBlack)
              print("   Response length: \(content.count) chars".lightBlack)
            }
            
            // Add assistant's response to conversation
            conversationMessages.append(.init(role: .assistant, content: .text(content)))
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
  
  // Helper function to generate context for tool calls with actual arguments
  private func synthesizeToolContext(toolCall: ToolCall) -> String {
    let toolName = toolCall.function.name ?? "tool"
    let args = toolCall.function.arguments
    
    // Try to parse arguments for more specific context
    if let data = args.data(using: .utf8),
       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
      
      // Generate specific messages based on tool and actual arguments
      switch toolName {
      case let name where name.contains("read"):
        if let path = json["file_path"] as? String {
          let displayPath = path.count > 60 ? "..." + String(path.suffix(57)) : path
          return "Reading \(displayPath)"
        }
        
      case let name where name.contains("write"):
        if let path = json["file_path"] as? String {
          let displayPath = path.count > 60 ? "..." + String(path.suffix(57)) : path
          return "Writing to \(displayPath)"
        }
        
      case let name where name.contains("edit"):
        if let path = json["file_path"] as? String {
          let displayPath = path.count > 60 ? "..." + String(path.suffix(57)) : path
          return "Editing \(displayPath)"
        }
        
      case let name where name.contains("grep") || name.contains("search"):
        if let pattern = json["pattern"] as? String {
          let displayPattern = pattern.count > 50 ? String(pattern.prefix(47)) + "..." : pattern
          return "Searching for '\(displayPattern)'"
        }
        
      case let name where name.contains("glob") || name.contains("find"):
        if let pattern = json["pattern"] as? String {
          return "Finding files matching: \(pattern)"
        }
        
      case let name where name.contains("ls") || name.contains("list"):
        if let path = json["path"] as? String {
          let displayPath = path.count > 60 ? "..." + String(path.suffix(57)) : path
          return "Listing \(displayPath)"
        }
        
      case let name where name.contains("bash") || name.contains("shell"):
        if let cmd = json["command"] as? String {
          let displayCmd = cmd.count > 50 ? String(cmd.prefix(47)) + "..." : cmd
          return "Running: \(displayCmd)"
        }
        
      case let name where name.contains("todo"):
        if let todos = json["todos"] as? [[String: Any]] {
          return "Updating \(todos.count) task\(todos.count == 1 ? "" : "s")"
        }
        
      case let name where name.contains("web"):
        if let url = json["url"] as? String {
          return "Fetching \(url)"
        }
        
      default:
        break
      }
    }
    
    // Fallback to simple context based on tool name only
    switch toolName {
    case let name where name.contains("read"):
      return "Reading file..."
    case let name where name.contains("write"):
      return "Writing file..."
    case let name where name.contains("edit"):
      return "Editing file..."
    case let name where name.contains("grep") || name.contains("search"):
      return "Searching codebase..."
    case let name where name.contains("glob") || name.contains("find"):
      return "Finding files..."
    case let name where name.contains("ls") || name.contains("list"):
      return "Listing directory..."
    case let name where name.contains("bash") || name.contains("shell"):
      return "Executing command..."
    case let name where name.contains("todo"):
      return "Updating tasks..."
    case let name where name.contains("web"):
      return "Fetching content..."
    case let name where name.contains("mcp"):
      return "Calling tool..."
    default:
      return "Processing..."
    }
  }
  
  // Simple fallback context when we can't parse arguments
  private func synthesizeSimpleContext(toolName: String) -> String {
    switch toolName {
    case let name where name.contains("read"):
      return "Reading file..."
    case let name where name.contains("write"):
      return "Writing file..."
    case let name where name.contains("edit"):
      return "Editing file..."
    case let name where name.contains("grep") || name.contains("search"):
      return "Searching codebase..."
    case let name where name.contains("glob") || name.contains("find"):
      return "Finding files..."
    case let name where name.contains("ls") || name.contains("list"):
      return "Listing directory..."
    case let name where name.contains("bash") || name.contains("shell"):
      return "Executing command..."
    case let name where name.contains("todo"):
      return "Updating tasks..."
    case let name where name.contains("web"):
      return "Fetching content..."
    case let name where name.contains("mcp"):
      return "Calling tool..."
    default:
      return "Processing..."
    }
  }
  
  // MARK: - Smart Markdown Rendering for Tool Results
  
  private func shouldRenderMarkdown(toolName: String, result: String) -> Bool {
    // Only apply markdown to tools that benefit from it
    switch toolName {
    case "isa__read":
      // Reading files - check if it looks like code by file extension patterns or content
      return containsCodePatterns(result)
    case "isa__bash", "isa__grep", "isa__ls", "isa__glob", "isa__edit", "isa__write":
      // Command outputs, file listings, search results - keep as plain text
      return false
    default:
      // Unknown tools - check content heuristically
      return MarkdownHelper.containsMarkdown(result)
    }
  }
  
  private func containsCodePatterns(_ content: String) -> Bool {
    // Check for common code patterns
    let codePatterns = [
      "func ", "class ", "struct ", "enum ", "import ",  // Swift
      "def ", "class ", "import ", "from ",              // Python
      "function", "const ", "let ", "var ",              // JavaScript
      "public ", "private ", "protected ",               // Java/C#
      "#include", "int ", "void ", "return ",            // C/C++
      "{", "}", "()", "[]", "//", "/*", "*/"           // General code symbols
    ]
    
    let lines = content.split(separator: "\n", maxSplits: 20) // Check first 20 lines
    var codeLineCount = 0
    
    for line in lines {
      let lineStr = String(line).trimmingCharacters(in: .whitespaces)
      if codePatterns.contains(where: { lineStr.contains($0) }) {
        codeLineCount += 1
      }
    }
    
    // If more than 30% of lines contain code patterns, treat as code
    return lines.count > 3 && Double(codeLineCount) / Double(lines.count) > 0.3
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
