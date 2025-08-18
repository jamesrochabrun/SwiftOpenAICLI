import Foundation
import SwiftOpenAI
import Rainbow

class ConversationCompactor {
  
  private let openAIService: OpenAIService
  
  init() {
    self.openAIService = OpenAIService.shared
  }
  
  func compactConversation(messages: [ChatCompletionParameters.Message],
                           currentModel: String) async throws -> ChatCompletionParameters.Message {
    
    // Prepare the conversation for summarization (limit size to prevent compaction from failing)
    var conversationText = formatConversationForSummary(messages)
    
    // Limit conversation text to prevent the compaction itself from exceeding limits
    let maxCharacters = 10000 // Roughly 2500 tokens
    if conversationText.count > maxCharacters {
      // Keep the most recent messages
      let startIndex = conversationText.index(conversationText.endIndex, offsetBy: -maxCharacters, limitedBy: conversationText.startIndex) ?? conversationText.startIndex
      conversationText = "...[earlier conversation truncated]...\n\n" + String(conversationText[startIndex...])
    }
    
    let compactionPrompt = """
        You are a conversation summarizer. Compress the following conversation into a structured summary that preserves all critical information.
        The summary will be used as context for continuing the conversation.
        
        Format your response using these XML tags:
        
        <conversation_summary>
        <user_profile>
        Include any mentioned names, preferences, background, or personal details about the user
        </user_profile>
        
        <key_facts>
        List all important facts, data, or information established in the conversation
        </key_facts>
        
        <decisions_made>
        Document all decisions, choices, or agreements made during the conversation
        </decisions_made>
        
        <tools_and_results>
        List any tools used and their important results (calculations, file operations, etc.)
        </tools_and_results>
        
        <current_context>
        Describe what the user and assistant are currently working on or discussing
        Include the most recent topic and any unfinished tasks
        </current_context>
        
        <important_code>
        If any code was written or discussed, include the most important snippets or descriptions
        </important_code>
        </conversation_summary>
        
        Conversation to summarize:
        ---
        \(conversationText)
        ---
        
        Create a comprehensive but concise summary that allows the conversation to continue seamlessly.
        """
    
    let service = try openAIService.getService()
    
    // Try compaction with different models
    let compactionModels = ["gpt-5-mini", "gpt-4o-mini", "gpt-3.5-turbo"]
    var summaryContent: String? = nil
    var lastError: Error? = nil
    
    for model in compactionModels {
      print("\n🔄 Auto-compacting conversation with \(model)...".yellow)
      
      let parameters = ChatCompletionParameters(
        messages: [
          .init(role: .system, content: .text("You are a precise conversation summarizer.")),
          .init(role: .user, content: .text(compactionPrompt))
        ],
        model: .custom(model),
        maxTokens: 2000, // Reduced to ensure it fits
        temperature: 0.3 // Lower temperature for more consistent summaries
      )
      
      do {
        let result = try await service.startChat(parameters: parameters)
        summaryContent = result.choices?.first?.message?.content
        if summaryContent != nil {
          break // Success, exit loop
        }
      } catch {
        lastError = error
        print("   ⚠️ Failed with \(model): \(error.localizedDescription)".red)
        if model != compactionModels.last {
          print("   Trying fallback model...".yellow)
        }
      }
    }
    
    guard let summaryContent = summaryContent else {
      print("❌ All compaction models failed".red)
      throw lastError ?? CompactionError.failedToGenerateSummary
    }
    
    // Create a new system message with the compacted conversation
    let compactedMessage = ChatCompletionParameters.Message(
      role: .system,
      content: .text("""
            [Previous conversation has been auto-compacted. Summary follows:]
            
            \(summaryContent)
            
            [Continue the conversation naturally, using the above context.]
            """)
    )
    
    let originalTokens = TokenCalculator.estimateTokens(for: messages)
    let compactedTokens = TokenCalculator.estimateTokens(for: summaryContent)
    let compressionRatio = Double(compactedTokens) / Double(originalTokens) * 100
    
    print("✅ Compaction complete!".green)
    print("   Original: ~\(originalTokens) tokens".lightBlack)
    print("   Compacted: ~\(compactedTokens) tokens".lightBlack)
    print("   Compression: \(String(format: "%.1f", compressionRatio))% of original size".lightBlack)
    print("")
    
    return compactedMessage
  }
  
  private func formatConversationForSummary(_ messages: [ChatCompletionParameters.Message]) -> String {
    var formatted = ""
    
    for message in messages {
      let role = message.role.capitalized
      let content: String
      
      switch message.content {
      case .text(let text):
        content = text
      case .contentArray(let array):
        content = array.compactMap { item in
          switch item {
          case .text(let text):
            return text
          case .imageUrl(_):
            return "[Image]"
          case .inputAudio(_):
            return "[Audio]"
          }
        }.joined(separator: " ")
      }
      
      formatted += "\(role): \(content)\n\n"
      
      // Note: We can't access internal toolCalls property, but tool results
      // will be captured in tool role messages
    }
    
    return formatted
  }
  
  enum CompactionError: LocalizedError {
    case failedToGenerateSummary
    
    var errorDescription: String? {
      switch self {
      case .failedToGenerateSummary:
        return "Failed to generate conversation summary"
      }
    }
  }
}
