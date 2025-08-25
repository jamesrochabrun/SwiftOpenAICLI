import Foundation
import Rainbow

/// Registry for managing slash commands
public class SlashCommandRegistry {
  private var commands: [String: SlashCommand] = [:]
  private let queue = DispatchQueue(label: "com.swiftopenai.commandregistry", attributes: .concurrent)
  
  public static let shared = SlashCommandRegistry()
  
  private init() {
    // Register built-in commands on initialization
    registerBuiltinCommands()
  }
  
  /// Register a slash command
  public func register(_ command: SlashCommand) {
    queue.async(flags: .barrier) {
      self.commands[command.name.lowercased()] = command
    }
  }
  
  /// Unregister a command by name
  public func unregister(_ name: String) {
    queue.async(flags: .barrier) {
      self.commands.removeValue(forKey: name.lowercased())
    }
  }
  
  /// Get a command by name
  public func getCommand(_ name: String) -> SlashCommand? {
    queue.sync {
      commands[name.lowercased()]
    }
  }
  
  /// Get all registered commands
  public func getAllCommands() -> [SlashCommand] {
    queue.sync {
      Array(commands.values).sorted { $0.name < $1.name }
    }
  }
  
  /// Parse and execute a command string
  public func execute(_ input: String, context: inout CommandContext) async throws -> Bool {
    let parsed = parseCommand(input)
    
    guard let command = getCommand(parsed.name) else {
      throw CommandError.commandNotFound(parsed.name)
    }
    
    // Validate arguments
    switch command.validateArguments(parsed.arguments) {
    case .failure(let error):
      throw error
    case .success:
      break
    }
    
    // Execute command
    return try await command.execute(arguments: parsed.arguments, context: &context)
  }
  
  /// Parse a command string into name and arguments
  public func parseCommand(_ input: String) -> ParsedCommand {
    // Remove leading slash if present
    let cleanInput = input.hasPrefix("/") ? String(input.dropFirst()) : input
    
    // Split into command and arguments
    let parts = cleanInput.split(separator: " ", maxSplits: 1)
    let name = String(parts.first ?? "")
    let arguments = parts.count > 1 ? String(parts[1]).trimmingCharacters(in: .whitespaces) : nil
    
    return ParsedCommand(name: name, arguments: arguments)
  }
  
  /// Check if input is a slash command
  public static func isSlashCommand(_ input: String) -> Bool {
    input.hasPrefix("/") && input.count > 1
  }
  
  /// Register all built-in commands
  private func registerBuiltinCommands() {
    // Register core commands
    register(HelpCommand())
    register(ClearCommand())
    register(ModelsSlashCommand())
    register(ConfigSlashCommand())
    
    // More commands will be added here
  }
  
  /// Print help for all commands
  public func printHelp() {
    print("\n📚 " + "Available Slash Commands".cyan.bold)
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━".lightBlack)
    
    let commands = getAllCommands()
    
    if commands.isEmpty {
      print("No commands available".lightBlack)
      return
    }
    
    // Calculate max width for alignment
    let maxNameWidth = commands.map { $0.name.count + ($0.argumentHint?.count ?? 0) + 3 }.max() ?? 20
    
    for cmd in commands {
      let nameWithHint = "/\(cmd.name)" + (cmd.argumentHint.map { " \($0)" } ?? "")
      let padding = String(repeating: " ", count: max(1, maxNameWidth - nameWithHint.count))
      print("\(nameWithHint.green)\(padding) \(cmd.description)")
    }
    
    print("\n💡 " + "Tips:".yellow)
    print("• Type /help <command> for detailed help on a specific command".lightBlack)
    print("• Use Tab for command completion".lightBlack)
    print("• Commands are case-insensitive".lightBlack)
    print("")
  }
  
  /// Print help for a specific command
  public func printHelp(for commandName: String) {
    guard let command = getCommand(commandName) else {
      print("Unknown command: /\(commandName)".red)
      return
    }
    
    print("\n📖 " + "/\(command.name)".cyan.bold)
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━".lightBlack)
    print("Description: \(command.description)")
    
    if let hint = command.argumentHint {
      print("Usage: /\(command.name) \(hint)".green)
    }
    
    if command.requiresArguments {
      print("⚠️  This command requires arguments".yellow)
    }
    print("")
  }
}