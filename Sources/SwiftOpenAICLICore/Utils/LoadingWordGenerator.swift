import Foundation
import SwiftOpenAI

/// Generates contextual, funny loading words using AI
public class LoadingWordGenerator {
  public static let shared = LoadingWordGenerator()
  
  private let service = OpenAIService.shared
  
  // Fallback words by category - expanded for variety
  private let fallbackWords: [String: [String]] = [
    "default": ["Processing", "Working", "Computing", "Calculating", "Analyzing", "Crunching", 
                "Churning", "Grinding", "Munching", "Digesting", "Deciphering", "Untangling",
                "Parsing", "Compiling", "Assembling", "Brewing"],
    "file": ["Rummaging", "Excavating", "Sifting", "Hunting", "Foraging", "Spelunking",
             "Plundering", "Scavenging", "Unearthing", "Prospecting", "Ransacking", "Pillaging",
             "Burrowing", "Tunneling", "Mining", "Harvesting"],
    "bash": ["Executing", "Launching", "Deploying", "Orchestrating", "Commanding", "Summoning",
             "Invoking", "Conjuring", "Marshaling", "Unleashing", "Dispatching", "Mobilizing",
             "Activating", "Triggering", "Initiating", "Spawning"],
    "edit": ["Tweaking", "Polishing", "Massaging", "Sculpting", "Refining", "Perfecting",
             "Chiseling", "Grooming", "Buffing", "Honing", "Tuning", "Calibrating",
             "Adjusting", "Finessing", "Modifying", "Reshaping"],
    "write": ["Scribing", "Composing", "Crafting", "Authoring", "Inscribing", "Penning",
              "Drafting", "Etching", "Engraving", "Transcribing", "Jotting", "Sketching",
              "Formulating", "Articulating", "Chronicling", "Documenting"],
    "search": ["Hunting", "Sleuthing", "Investigating", "Prowling", "Detecting", "Sniffing",
               "Stalking", "Tracking", "Pursuing", "Scouring", "Probing", "Exploring",
               "Snooping", "Ferreting", "Rummaging", "Questing"],
    "grep": ["Grepping", "Scanning", "Combing", "Trawling", "Dredging", "Filtering",
             "Sieving", "Straining", "Winnowing", "Culling", "Extracting", "Harvesting",
             "Skimming", "Sweeping", "Raking", "Trolling"],
    "glob": ["Globbing", "Matching", "Wildcarding", "Expanding", "Collecting", "Gathering",
             "Accumulating", "Amassing", "Hoarding", "Stockpiling", "Clustering", "Bundling",
             "Aggregating", "Consolidating", "Corralling", "Herding"],
    "list": ["Listing", "Cataloging", "Enumerating", "Indexing", "Inventorying", "Surveying",
             "Tabulating", "Itemizing", "Tallying", "Registering", "Documenting", "Charting",
             "Mapping", "Auditing", "Reviewing", "Assessing"],
    "thinking": ["Pondering", "Cogitating", "Ruminating", "Contemplating", "Musing", "Deliberating",
                 "Brainstorming", "Noodling", "Mulling", "Meditating", "Reflecting", "Philosophizing",
                 "Scheming", "Daydreaming", "Puzzling", "Wrestling", "Considering", "Evaluating",
                 "Analyzing", "Processing", "Computing", "Ideating"],
    "mcp": ["Connecting", "Bridging", "Interfacing", "Linking", "Syncing", "Handshaking",
            "Pairing", "Bonding", "Meshing", "Integrating", "Networking", "Communicating",
            "Negotiating", "Establishing", "Coupling", "Docking"],
    "todo": ["Organizing", "Prioritizing", "Scheduling", "Tracking", "Managing", "Juggling",
             "Coordinating", "Arranging", "Orchestrating", "Delegating", "Balancing", "Streamlining",
             "Planning", "Structuring", "Categorizing", "Optimizing"]
  ]
  
  private init() {}
  
  /// Get a contextual loading word for a tool
  public func getLoadingWord(for toolName: String, useAI: Bool = true, forceAI: Bool = false) async -> String {
    // Determine category from tool name
    let category = categorizeToolAsync(toolName)
    
    // Check if we're using OpenAI provider (AI word generation only works with OpenAI)
    let provider = ConfigurationManager.shared.provider?.lowercased()
    let isOpenAI = provider == nil || provider == "openai"
    
    // Only use AI if we're on OpenAI provider AND (forceAI or useAI is true)
    let shouldUseAI = isOpenAI && (forceAI || useAI)
    
    // If AI is disabled, not forced, or not OpenAI provider, use fallback
    if !shouldUseAI {
      return getRandomFallback(for: category)
    }
    
    // Try to get AI-generated word with timeout
    let aiWord: String? = await withTaskGroup(of: String?.self) { group in
      // Add AI generation task
      group.addTask {
        await self.generateAIWord(for: toolName, category: category)
      }
      
      // Add timeout task - increased for better success rate
      group.addTask {
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1.0 second timeout
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
      
      guard let service = try? service.getService() else {
        // Service initialization failed, use fallback
        return nil
      }
      
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
  public func getThinkingWordSync() -> String {
    return fallbackWords["thinking"]?.randomElement() ?? "Thinking"
  }
  
  /// Get random fallback word for a specific tool (synchronous, no delay)
  public func getRandomFallbackForTool(_ toolName: String) -> String {
    let category = categorizeToolAsync(toolName)
    return getRandomFallback(for: category)
  }
  
  /// Get loading word for thinking/processing (async version that can use AI)
  public func getThinkingWord(useAI: Bool = false, forceAI: Bool = false) async -> String {
    // Check if we're using OpenAI provider (AI word generation only works with OpenAI)
    let provider = ConfigurationManager.shared.provider?.lowercased()
    let isOpenAI = provider == nil || provider == "openai"
    
    // Only use AI if we're on OpenAI provider AND (forceAI or useAI is true)
    let shouldUseAI = isOpenAI && (forceAI || useAI)
    
    if !shouldUseAI {
      return getRandomFallback(for: "thinking")
    }
    
    // Try to get AI-generated thinking word with longer timeout for better success rate
    let aiWord: String? = await withTaskGroup(of: String?.self) { group in
      // Add AI generation task
      group.addTask {
        await self.generateAIWord(for: "thinking", category: "thinking")
      }
      
      // Add timeout task - increased to 1.5 seconds for better AI response rate
      group.addTask {
        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 second timeout
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