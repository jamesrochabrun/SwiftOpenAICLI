import Foundation
import SwiftOpenAI

/// Generates contextual, funny loading words using AI
public class LoadingWordGenerator {
  public static let shared = LoadingWordGenerator()
  
  private let service = OpenAIService.shared
  
  // Fallback words by category
  private let fallbackWords: [String: [String]] = [
    "default": ["Processing", "Working", "Computing", "Calculating", "Analyzing", "Crunching"],
    "file": ["Rummaging", "Excavating", "Sifting", "Hunting", "Foraging", "Spelunking"],
    "bash": ["Executing", "Launching", "Deploying", "Orchestrating", "Commanding", "Summoning"],
    "edit": ["Tweaking", "Polishing", "Massaging", "Sculpting", "Refining", "Perfecting"],
    "write": ["Scribing", "Composing", "Crafting", "Authoring", "Inscribing", "Penning"],
    "search": ["Hunting", "Sleuthing", "Investigating", "Prowling", "Detecting", "Sniffing"],
    "grep": ["Grepping", "Scanning", "Combing", "Trawling", "Dredging", "Filtering"],
    "glob": ["Globbing", "Matching", "Wildcarding", "Expanding", "Collecting", "Gathering"],
    "list": ["Listing", "Cataloging", "Enumerating", "Indexing", "Inventorying", "Surveying"],
    "thinking": ["Pondering", "Cogitating", "Ruminating", "Contemplating", "Musing", "Deliberating"],
    "mcp": ["Connecting", "Bridging", "Interfacing", "Linking", "Syncing", "Handshaking"],
    "todo": ["Organizing", "Prioritizing", "Scheduling", "Tracking", "Managing", "Juggling"]
  ]
  
  private init() {}
  
  /// Get a contextual loading word for a tool
  public func getLoadingWord(for toolName: String, useAI: Bool = true, forceAI: Bool = false) async -> String {
    // Determine category from tool name
    let category = categorizeToolAsync(toolName)
    
    // Force AI mode for agent/ISA mode, otherwise use provided setting
    let shouldUseAI = forceAI || useAI
    
    // If AI is disabled and not forced, use fallback
    if !shouldUseAI {
      return getRandomFallback(for: category)
    }
    
    // Try to get AI-generated word with timeout
    let aiWord: String? = await withTaskGroup(of: String?.self) { group in
      // Add AI generation task
      group.addTask {
        await self.generateAIWord(for: toolName, category: category)
      }
      
      // Add timeout task
      group.addTask {
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second timeout
        return nil
      }
      
      // Return first non-nil result
      for await result in group {
        if let word = result {
          group.cancelAll()
          return word
        }
      }
      
      return nil
    }
    
    // Use AI word if we got one, otherwise fallback
    return aiWord ?? getRandomFallback(for: category)
  }
  
  /// Generate a word using GPT-4o-mini
  private func generateAIWord(for toolName: String, category: String) async -> String? {
    do {
      let prompt = """
      Generate ONE single creative and slightly funny verb (present participle ending in -ing) 
      for what a '\(toolName)' tool is doing. The word should be:
      - Relevant but playful
      - Single word only
      - Ending in -ing
      - Between 6-12 characters
      
      Examples: Rummaging, Noodling, Spelunking, Wrangling
      
      Just respond with the single word, nothing else.
      """
      
      let service = try service.getService()
      
      let params = ChatCompletionParameters(
        messages: [.init(role: .user, content: .text(prompt))],
        model: .custom("gpt-4o-mini"),
        maxTokens: 10,
        temperature: 1.2  // Higher temperature for creativity
      )
      
      let result = try await service.startChat(parameters: params)
      
      if let content = result.choices?.first?.message?.content {
        // Clean up the response (remove quotes, spaces, etc.)
        let word = content
          .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
          .replacingOccurrences(of: "\"", with: "")
          .replacingOccurrences(of: "'", with: "")
          .replacingOccurrences(of: ".", with: "")
        
        // Validate it's a single word ending in "ing"
        if word.count >= 6 && word.count <= 15 && 
           !word.contains(" ") && 
           word.hasSuffix("ing") {
          return word.capitalizeFirst()
        }
      }
    } catch {
      // Silently fail and use fallback
    }
    
    return nil
  }
  
  /// Get loading word for thinking/processing (synchronous fallback version)
  public func getThinkingWord() -> String {
    return fallbackWords["thinking"]?.randomElement() ?? "Thinking"
  }
  
  /// Get loading word for thinking/processing (async version that can use AI)
  public func getThinkingWord(useAI: Bool = false, forceAI: Bool = false) async -> String {
    // Force AI mode for agent/ISA mode, otherwise use provided setting
    let shouldUseAI = forceAI || useAI
    
    if !shouldUseAI {
      return getRandomFallback(for: "thinking")
    }
    
    // Try to get AI-generated thinking word with timeout
    let aiWord: String? = await withTaskGroup(of: String?.self) { group in
      // Add AI generation task
      group.addTask {
        await self.generateAIWord(for: "thinking", category: "thinking")
      }
      
      // Add timeout task
      group.addTask {
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second timeout
        return nil
      }
      
      // Return first non-nil result
      for await result in group {
        if let word = result {
          group.cancelAll()
          return word
        }
      }
      
      return nil
    }
    
    // Use AI word if we got one, otherwise fallback
    return aiWord ?? getRandomFallback(for: "thinking")
  }
  
  /// Categorize tool based on name
  private func categorizeToolAsync(_ toolName: String) -> String {
    let lowercased = toolName.lowercased()
    
    if lowercased.contains("read") || lowercased.contains("file") {
      return "file"
    } else if lowercased.contains("bash") || lowercased.contains("exec") {
      return "bash"
    } else if lowercased.contains("edit") || lowercased.contains("modify") {
      return "edit"
    } else if lowercased.contains("write") || lowercased.contains("create") {
      return "write"
    } else if lowercased.contains("grep") || lowercased.contains("search") {
      return "search"
    } else if lowercased.contains("glob") || lowercased.contains("match") {
      return "glob"
    } else if lowercased.contains("ls") || lowercased.contains("list") {
      return "list"
    } else if lowercased.contains("mcp") {
      return "mcp"
    } else if lowercased.contains("todo") {
      return "todo"
    } else {
      return "default"
    }
  }
  
  /// Get a random fallback word for a category
  private func getRandomFallback(for category: String) -> String {
    let words = fallbackWords[category] ?? fallbackWords["default"]!
    return words.randomElement() ?? "Processing"
  }
}

extension String {
  func capitalizeFirst() -> String {
    return prefix(1).capitalized + dropFirst()
  }
}