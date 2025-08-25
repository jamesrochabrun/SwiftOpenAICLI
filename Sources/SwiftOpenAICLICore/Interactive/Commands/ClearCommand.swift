import Foundation
import Rainbow

/// Slash command for clearing conversation history
public struct ClearCommand: SlashCommand {
  public let name = "clear"
  public let description = "Clear conversation history and start fresh"
  public let argumentHint: String? = nil
  
  public init() {}
  
  public func execute(arguments: String?, context: inout CommandContext) async throws -> Bool {
    // Clear the session
    SessionManager.shared.clearSession(context.sessionId)
    
    // Clear screen
    print("\u{001B}[2J\u{001B}[H")  // ANSI escape codes to clear screen
    
    print("✅ Conversation cleared".green)
    print("Starting fresh conversation...".lightBlack)
    print("")
    
    return true  // Continue session
  }
}