import Foundation

class ISAContextLoader {
  
  func loadAndEnhancePrompt(basePrompt: String?) -> String {
    var components: [String] = []
    
    // Add Claude Code-inspired system prompt
    components.append(getClaudeCodePrompt())
    
    // Add user's base prompt if provided
    if let basePrompt = basePrompt {
      components.append(basePrompt)
    }
    
    // Load and add ISA context from project
    if let contextContent = loadProjectContext() {
      components.append("""
      
      # Project Context (from isa.md):
      \(contextContent)
      """)
    }
    
    // Add current environment info
    components.append(getEnvironmentInfo())
    
    return components.joined(separator: "\n\n")
  }
  
  private func getClaudeCodePrompt() -> String {
    return """
    You are ISA (Intelligent Software Assistant), an AI agent inspired by Claude Code.
    You help users with software development tasks, file operations, and system automation.
    
    # Core Principles
    - Keep things simple and debuggable
    - Use tools effectively to accomplish tasks
    - Maintain a todo list for complex tasks
    - Be concise and direct in responses
    - Follow user preferences from isa.md files
    
    # Tool Usage Policy
    - ALWAYS use Read tool before Edit to understand file contents
    - Prefer Grep/Glob over manual searching
    - Use Bash for system commands with safety checks
    - Update todo list as you work through tasks
    - When doing file search, prefer using specialized search tools
    
    # Tone and Style
    - Be concise and to the point
    - IMPORTANT: Avoid unnecessary preambles or postambles
    - Show progress through actions, not words
    - Use emojis sparingly and only when appropriate
    - Answer directly without elaboration unless asked
    
    # Task Management
    When working on complex tasks:
    1. Break down the task into clear steps
    2. Use TodoWrite tool to track progress
    3. Mark tasks as in_progress when starting
    4. Mark tasks as completed immediately when done
    5. Only ONE task should be in_progress at a time
    
    # Following Conventions
    When making changes to files:
    - First understand the file's code conventions
    - Mimic code style and patterns
    - Use existing libraries and utilities
    - Follow existing naming conventions
    - NEVER assume a library is available without checking
    
    # Code Style
    - IMPORTANT: DO NOT ADD COMMENTS unless explicitly asked
    - Maintain consistent indentation
    - Follow project-specific conventions from isa.md
    
    # Proactiveness
    Be proactive and take action immediately when the user asks you to do something:
    - Start working on tasks right away without asking for permission
    - Take necessary follow-up actions to complete the task
    - Use tools immediately when needed
    - Only ask for clarification if the request is genuinely ambiguous
    - Don't ask for permission to use tools or search files
    
    IMPORTANT: Always think step-by-step before taking actions.
    IMPORTANT: Keep responses short and direct.
    VERY IMPORTANT: Minimize output tokens while maintaining helpfulness.
    """
  }
  
  private func loadProjectContext() -> String? {
    let currentDir = FileManager.default.currentDirectoryPath
    
    // Check for isa.md in current directory
    let isaPath = (currentDir as NSString).appendingPathComponent("isa.md")
    if FileManager.default.fileExists(atPath: isaPath) {
      return try? String(contentsOfFile: isaPath, encoding: .utf8)
    }
    
    // Check for .isa/context.md
    let altPath = (currentDir as NSString).appendingPathComponent(".isa/context.md")
    if FileManager.default.fileExists(atPath: altPath) {
      return try? String(contentsOfFile: altPath, encoding: .utf8)
    }
    
    // Check for CLAUDE.md (compatibility with Claude Code)
    let claudePath = (currentDir as NSString).appendingPathComponent("CLAUDE.md")
    if FileManager.default.fileExists(atPath: claudePath) {
      return try? String(contentsOfFile: claudePath, encoding: .utf8)
    }
    
    // Check for .claude/CLAUDE.md
    let claudeAltPath = (currentDir as NSString).appendingPathComponent(".claude/CLAUDE.md")
    if FileManager.default.fileExists(atPath: claudeAltPath) {
      return try? String(contentsOfFile: claudeAltPath, encoding: .utf8)
    }
    
    return nil
  }
  
  private func getEnvironmentInfo() -> String {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    let today = dateFormatter.string(from: Date())
    
    let platform = ProcessInfo.processInfo.operatingSystemVersionString
    let workingDir = FileManager.default.currentDirectoryPath
    
    // Check if current directory is a git repo
    let isGitRepo = FileManager.default.fileExists(atPath: "\(workingDir)/.git")
    
    return """
    # Environment
    Working directory: \(workingDir)
    Is git repository: \(isGitRepo ? "Yes" : "No")
    Platform: macOS
    OS Version: \(platform)
    Today's date: \(today)
    ISA Version: 1.0.0
    """
  }
}