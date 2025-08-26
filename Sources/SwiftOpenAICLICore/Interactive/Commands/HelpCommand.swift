import Foundation
import Rainbow

/// Slash command for displaying help information
public struct HelpCommand: SlashCommand {
  public let name = "help"
  public let description = "Show available commands and usage information"
  public let argumentHint: String? = "[command]"
  
  public init() {}
  
  public func execute(arguments: String?, context: inout CommandContext) async throws -> Bool {
    // If specific command requested, show its help
    if let commandName = arguments?.trimmingCharacters(in: .whitespaces), !commandName.isEmpty {
      SlashCommandRegistry.shared.printHelp(for: commandName)
    } else {
      // Show general help
      SlashCommandRegistry.shared.printHelp()
      
      // Add interactive mode tips
      print("🎮 " + "Interactive Mode Controls".cyan.bold)
      print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━".lightBlack)
      print("• " + "exit/quit".green + "     Exit interactive mode")
      print("• " + "clear".green + "          Clear conversation history")
      print("• " + "ESC".green + "            Interrupt current message (during generation)")
      print("• " + "Ctrl+C".green + "         Force quit application")
      print("• " + "Ctrl+D".green + "         Exit (EOF signal)")
      print("• " + "\\".green + " at line end   Start multiline input")
      print("")
      
      // Show multiline input help
      InputProcessor.printMultilineHelp()
    }
    
    return true  // Continue session
  }
}