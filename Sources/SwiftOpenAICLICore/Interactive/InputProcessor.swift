import Foundation
import Rainbow
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// Processes user input in interactive mode
public class InputProcessor {
  private let registry = SlashCommandRegistry.shared
  private var multilineMode = false
  private var multilineBuffer: [String] = []
  
  public init() {}
  
  /// Process a line of input and determine action
  public func processInput(_ input: String) -> InputAction {
    // Check for EOF
    if input.isEmpty && !multilineMode {
      return .empty
    }
    
    // Handle multiline mode
    if multilineMode {
      return handleMultilineInput(input)
    }
    
    // Check for multiline start (ending with backslash)
    if input.hasSuffix("\\") && !input.hasSuffix("\\\\") {
      startMultilineMode(String(input.dropLast()))
      return .continueMultiline
    }
    
    // Check for built-in keywords (exit, clear)
    let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
    let lowercased = trimmed.lowercased()
    
    if lowercased == "exit" || lowercased == "quit" {
      return .exit
    }
    
    if lowercased == "clear" {
      return .clearScreen
    }
    
    // Check for slash command
    if SlashCommandRegistry.isSlashCommand(trimmed) {
      return .slashCommand(trimmed)
    }
    
    // Regular message
    return .message(trimmed)
  }
  
  /// Handle input in multiline mode
  private func handleMultilineInput(_ input: String) -> InputAction {
    // Check for end of multiline (empty line or single dot)
    if input.isEmpty || input == "." {
      let fullMessage = multilineBuffer.joined(separator: "\n")
      endMultilineMode()
      return .message(fullMessage)
    }
    
    // Check for escape from multiline (double backslash)
    if input == "\\\\" {
      endMultilineMode()
      return .cancelMultiline
    }
    
    // Add line to buffer
    multilineBuffer.append(input)
    return .continueMultiline
  }
  
  /// Start multiline input mode
  private func startMultilineMode(_ firstLine: String) {
    multilineMode = true
    multilineBuffer = [firstLine]
  }
  
  /// End multiline input mode
  private func endMultilineMode() {
    multilineMode = false
    multilineBuffer.removeAll()
  }
  
  /// Check if currently in multiline mode
  public var isInMultilineMode: Bool {
    multilineMode
  }
  
  /// Get appropriate prompt for current mode
  public func getPrompt() -> String {
    if multilineMode {
      return "... ".lightBlack  // Continuation prompt
    } else {
      return "You: ".green
    }
  }
  
  /// Read a line of input with appropriate prompt
  public func readInput() -> String? {
    print(getPrompt(), terminator: "")
    fflush(stdout)
    return readLine()
  }
  
  /// Print multiline help
  public static func printMultilineHelp() {
    print("\n📝 " + "Multiline Input".cyan.bold)
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━".lightBlack)
    print("• End line with \\ to continue on next line".lightBlack)
    print("• Enter empty line or single . to finish".lightBlack)
    print("• Enter \\\\ to cancel multiline input".lightBlack)
    print("")
  }
}

/// Actions that can result from processing input
public enum InputAction {
  case message(String)          // Regular message to process
  case slashCommand(String)     // Slash command to execute
  case exit                     // Exit interactive mode
  case clearScreen             // Clear the screen
  case empty                   // Empty input (skip)
  case continueMultiline       // Continue multiline input
  case cancelMultiline         // Cancel multiline input
  
  public var shouldContinue: Bool {
    switch self {
    case .exit:
      return false
    default:
      return true
    }
  }
}