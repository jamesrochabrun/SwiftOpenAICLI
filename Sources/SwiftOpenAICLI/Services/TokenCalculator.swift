import Foundation
import SwiftOpenAI

class TokenCalculator {
  
  // Token approximation: 1 token ≈ 4 characters
  private static let charactersPerToken: Double = 4.0
  
  // DEBUG MODE: Set to true to use small context windows for testing
  private static let debugMode = false
  
  // Model context windows in tokens
  private static let modelContextWindows: [String: Int] = [
    "gpt-5": debugMode ? 1_000 : 400_000,
    "gpt-5-mini": debugMode ? 1_000 : 400_000,
    "gpt-5-nano": debugMode ? 1_000 : 400_000,
    "gpt-4o": debugMode ? 1_000 : 128_000,
    "gpt-4o-mini": debugMode ? 1_000 : 128_000,
    "gpt-4-turbo": debugMode ? 1_000 : 128_000,
    "gpt-4": debugMode ? 1_000 : 8_192,
    "gpt-3.5-turbo": debugMode ? 1_000 : 16_385
  ]
  
  // Reserve tokens for the response and compaction
  private static let reservedTokens = debugMode ? 200 : 10_000
  
  // Compaction threshold (92% of available capacity, 85% in debug mode)
  private static let compactionThreshold: Double = debugMode ? 0.85 : 0.92
  
  static func estimateTokens(for messages: [ChatCompletionParameters.Message]) -> Int {
    var totalCharacters = 0
    
    for message in messages {
      // Add role overhead (approximately 4 tokens)
      totalCharacters += 16
      
      // Add content
      switch message.content {
      case .text(let text):
        totalCharacters += text.count
      case .contentArray(let array):
        for content in array {
          switch content {
          case .text(let text):
            totalCharacters += text.count
          case .imageUrl(_):
            // Images take roughly 85 tokens for base overhead
            totalCharacters += 340
          case .inputAudio(_):
            // Audio takes roughly 100 tokens for base overhead
            totalCharacters += 400
          }
        }
      }
      
      // Add estimated overhead for tool calls (we can't access internal toolCalls property)
      // This is a rough estimate based on typical tool call patterns
      if message.role == "assistant" {
        // Assistant messages might have tool calls, add some buffer
        totalCharacters += 100
      }
    }
    
    return Int(Double(totalCharacters) / charactersPerToken)
  }
  
  static func estimateTokens(for text: String) -> Int {
    return Int(Double(text.count) / charactersPerToken)
  }
  
  static func getContextWindow(for model: String) -> Int {
    let normalizedModel = model.lowercased()
    
    // Check for exact match first
    if let window = modelContextWindows[normalizedModel] {
      return window
    }
    
    // Check for partial matches
    for (key, value) in modelContextWindows {
      if normalizedModel.contains(key) || key.contains(normalizedModel) {
        return value
      }
    }
    
    // Default to GPT-4o context window
    return 128_000
  }
  
  static func getAvailableTokens(for model: String) -> Int {
    return getContextWindow(for: model) - reservedTokens
  }
  
  static func calculateUsagePercentage(tokens: Int, for model: String) -> Double {
    let available = Double(getAvailableTokens(for: model))
    guard available > 0 else { return 1.0 }
    return Double(tokens) / available
  }
  
  static func shouldCompact(tokens: Int, for model: String) -> Bool {
    let usage = calculateUsagePercentage(tokens: tokens, for: model)
    return usage >= compactionThreshold
  }
  
  static func getRemainingPercentageUntilCompaction(tokens: Int, for model: String) -> Int? {
    let usage = calculateUsagePercentage(tokens: tokens, for: model)
    let warningThreshold = debugMode ? 0.5 : 0.8  // Show warnings at 50% in debug mode
    
    if usage >= compactionThreshold {
      return 0
    } else if usage >= warningThreshold {
      // Only show warning when above threshold
      let remaining = (compactionThreshold - usage) * 100
      return Int(remaining)
    }
    
    return nil // Don't show percentage if below threshold
  }
  
  static func formatCapacityWarning(tokens: Int, for model: String) -> String? {
    guard let remaining = getRemainingPercentageUntilCompaction(tokens: tokens, for: model) else {
      return nil
    }
    
    if remaining == 0 {
      return "🔄 Auto-compacting conversation..."
    } else {
      let usage = Int(calculateUsagePercentage(tokens: tokens, for: model) * 100)
      return "💭 \(usage)% capacity (\(remaining)% until auto-compacting)"
    }
  }
}
