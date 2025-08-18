import Foundation
import SwiftOpenAI

protocol CLITool {
  var name: String { get }
  var description: String { get }
  var parameters: JSONSchema { get }
  
  func execute(arguments: String) async throws -> String
}

extension CLITool {
  func toChatFunction() -> ChatCompletionParameters.ChatFunction {
    return ChatCompletionParameters.ChatFunction(
      name: name,
      strict: true,
      description: description,
      parameters: parameters
    )
  }
}
