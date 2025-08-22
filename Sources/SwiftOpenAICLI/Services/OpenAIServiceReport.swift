import Foundation
import SwiftOpenAI

extension OpenAIService {
  /// Agent chat that returns the final response content for report generation
  func agentChatForReport(
    message: String,
    model: String,
    system: String? = nil,
    temperature: Double = 1.0,
    maxTokens: Int? = nil,
    enabledTools: Set<String>?,
    verbose: String = "medium",
    reasoning: String = "medium",
    mcpServers: [MCPServerConfig] = [],
    timeout: Int = 120,
    maxToolCalls: Int = 30
  ) async throws -> String {
    let toolExecutor = ToolExecutor(
      mcpServers: mcpServers,
      verbose: false,
      useStderr: false,
      showToolEventsVerbose: false
    )
    await toolExecutor.initialize()
    
    let openAI = try getService()
    // Normalize model name inline since the method is private
    let normalizedModel = model.lowercased()
      .replacingOccurrences(of: "gpt5", with: "gpt-5")
      .replacingOccurrences(of: "gpt4", with: "gpt-4")
    
    // Build initial messages
    var messages: [ChatCompletionParameters.Message] = []
    
    if let system = system {
      messages.append(.init(role: .system, content: .text(system)))
    }
    
    messages.append(.init(role: .user, content: .text(message)))
    
    // Get tool definitions
    let toolDefinitions = toolExecutor.getToolDefinitions(for: enabledTools)
    
    var conversationMessages = messages
    var toolCallCount = 0
    var finalResponse = ""
    
    while toolCallCount < maxToolCalls {
      let parameters = ChatCompletionParameters(
        messages: conversationMessages,
        model: .custom(normalizedModel),
        tools: toolDefinitions.isEmpty ? nil : toolDefinitions,
        maxTokens: maxTokens,
        temperature: temperature
      )
      
      do {
        let response = try await openAI.startChat(parameters: parameters)
        
        guard let choice = response.choices?.first else {
          break
        }
        
        // Handle tool calls
        if let message = choice.message,
           let toolCalls = message.toolCalls,
           !toolCalls.isEmpty {
          toolCallCount += toolCalls.count
          
          // Add assistant message with tool calls
          let assistantContent: ChatCompletionParameters.Message.ContentType = 
            message.content.map { .text($0) } ?? .text("")
          
          conversationMessages.append(.init(
            role: .assistant,
            content: assistantContent,
            toolCalls: toolCalls
          ))
          
          // Execute tools
          for toolCall in toolCalls {
            guard let toolName = toolCall.function.name else { continue }
            let result = try await toolExecutor.executeTool(
              name: toolName,
              arguments: toolCall.function.arguments ?? "{}",
              outputFormat: "silent"
            )
            
            conversationMessages.append(.init(
              role: .tool,
              content: .text(result),
              toolCallID: toolCall.id
            ))
          }
        } else if let message = choice.message {
          // Got final response
          if let content = message.content {
            finalResponse = content
          }
          break
        }
      } catch {
        throw error
      }
    }
    
    return finalResponse
  }
}