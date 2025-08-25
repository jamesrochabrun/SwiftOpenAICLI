import Foundation

/// Protocol for implementing slash commands in interactive mode
public protocol SlashCommand {
  /// The command name (without the leading slash)
  var name: String { get }
  
  /// Brief description shown in help
  var description: String { get }
  
  /// Hint for expected arguments (e.g., "[model-name]" or "<required> [optional]")
  var argumentHint: String? { get }
  
  /// Whether this command requires additional arguments
  var requiresArguments: Bool { get }
  
  /// Execute the command with given arguments
  /// - Parameters:
  ///   - arguments: The arguments passed to the command (if any)
  ///   - context: The execution context containing session info, current model, etc.
  /// - Returns: Whether to continue the interactive session (false to exit)
  func execute(arguments: String?, context: inout CommandContext) async throws -> Bool
  
  /// Validate arguments before execution (optional)
  func validateArguments(_ arguments: String?) -> Result<Void, CommandError> 
}

// Default implementation for optional protocol methods
public extension SlashCommand {
  var argumentHint: String? { nil }
  var requiresArguments: Bool { false }
  
  func validateArguments(_ arguments: String?) -> Result<Void, CommandError> {
    if requiresArguments && (arguments?.isEmpty ?? true) {
      return .failure(.missingArguments(command: name, hint: argumentHint))
    }
    return .success(())
  }
}

/// Context passed to slash commands during execution
public struct CommandContext {
  public var sessionId: String
  public var currentModel: String
  public var temperature: Double
  public var maxTokens: Int?
  public let isAgentMode: Bool
  public var enabledTools: Set<String>?
  
  public init(
    sessionId: String,
    currentModel: String,
    temperature: Double = 1.0,
    maxTokens: Int? = nil,
    isAgentMode: Bool = false,
    enabledTools: Set<String>? = nil
  ) {
    self.sessionId = sessionId
    self.currentModel = currentModel
    self.temperature = temperature
    self.maxTokens = maxTokens
    self.isAgentMode = isAgentMode
    self.enabledTools = enabledTools
  }
}

/// Errors that can occur during command execution
public enum CommandError: LocalizedError {
  case commandNotFound(String)
  case missingArguments(command: String, hint: String?)
  case invalidArguments(String)
  case executionFailed(String)
  case cancelled
  
  public var errorDescription: String? {
    switch self {
    case .commandNotFound(let cmd):
      return "Unknown command: /\(cmd). Type /help for available commands."
    case .missingArguments(let cmd, let hint):
      if let hint = hint {
        return "Command /\(cmd) requires arguments: \(hint)"
      }
      return "Command /\(cmd) requires arguments"
    case .invalidArguments(let msg):
      return "Invalid arguments: \(msg)"
    case .executionFailed(let msg):
      return "Command failed: \(msg)"
    case .cancelled:
      return "Command cancelled"
    }
  }
}

/// Result of parsing a command input
public struct ParsedCommand {
  public let name: String
  public let arguments: String?
  
  public init(name: String, arguments: String?) {
    self.name = name
    self.arguments = arguments
  }
}