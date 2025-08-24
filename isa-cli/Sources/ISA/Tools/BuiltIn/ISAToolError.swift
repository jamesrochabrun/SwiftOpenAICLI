import Foundation

public enum ISAToolError: LocalizedError {
  case invalidArguments(String)
  case fileNotFound(String)
  case directoryNotFound(String)
  case stringNotFound(String)
  case ambiguousMatch(String)
  case commandNotFound(String)
  case commandFailed(String)
  case dangerousCommand(String)
  case timeout(String)
  case executionFailed(String)
  
  public var errorDescription: String? {
    switch self {
    case .invalidArguments(let message):
      return "Invalid arguments: \(message)"
    case .fileNotFound(let path):
      return "File not found: \(path)"
    case .directoryNotFound(let path):
      return "Directory not found: \(path)"
    case .stringNotFound(let message):
      return "String not found: \(message)"
    case .ambiguousMatch(let message):
      return "Ambiguous match: \(message)"
    case .commandNotFound(let command):
      return "Command not found: \(command)"
    case .commandFailed(let message):
      return "Command failed: \(message)"
    case .dangerousCommand(let message):
      return "Dangerous command blocked: \(message)"
    case .timeout(let message):
      return "Timeout: \(message)"
    case .executionFailed(let message):
      return "Execution failed: \(message)"
    }
  }
}