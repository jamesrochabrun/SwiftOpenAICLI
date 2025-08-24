import Foundation
import SwiftOpenAI

public protocol CLITool {
  var name: String { get }
  var description: String { get }
  var parameters: JSONSchema { get }
  var isStrictModeCompatible: Bool { get }
  
  func execute(arguments: String) async throws -> String
}

public extension CLITool {
  var isStrictModeCompatible: Bool {
    // By default, built-in tools are strict mode compatible
    return true
  }
  
  public func toChatFunction() -> ChatCompletionParameters.ChatFunction {
    return ChatCompletionParameters.ChatFunction(
      name: name,
      strict: isStrictModeCompatible,
      description: description,
      parameters: parameters
    )
  }
}
