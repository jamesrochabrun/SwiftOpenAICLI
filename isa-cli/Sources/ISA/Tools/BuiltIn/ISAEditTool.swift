import Foundation
import SwiftOpenAICLICore
import SwiftOpenAI

public class ISAEditTool: CLITool {
  public let name = "isa__edit"
  
  public let description = """
  Performs exact string replacements in files.
  
  Usage:
  - You must use your Read tool at least once in the conversation before editing. This tool will error if you attempt an edit without reading the file.
  - When editing text from Read tool output, ensure you preserve the exact indentation (tabs/spaces) as it appears AFTER the line number prefix. The line number prefix format is: spaces + line number + tab. Everything after that tab is the actual file content to match. Never include any part of the line number prefix in the old_string or new_string.
  - ALWAYS prefer editing existing files in the codebase. NEVER write new files unless explicitly required.
  - The edit will FAIL if old_string is not unique in the file. Either provide a larger string with more surrounding context to make it unique or use replace_all to change every instance of old_string.
  - Use replace_all for replacing and renaming strings across the file. This parameter is useful if you want to rename a variable for instance.
  """
  
  public var parameters: JSONSchema {
    return JSONSchema(
      type: .object,
      properties: [
        "file_path": JSONSchema(
          type: .string,
          description: "The absolute path to the file to modify"
        ),
        "old_string": JSONSchema(
          type: .string,
          description: "The text to replace"
        ),
        "new_string": JSONSchema(
          type: .string,
          description: "The text to replace it with (must be different from old_string)"
        ),
        "replace_all": JSONSchema(
          type: .boolean,
          description: "Replace all occurences of old_string (default false)"
        )
      ],
      required: ["file_path", "old_string", "new_string"]  // replace_all is optional
    )
  }
  
  public let isStrictModeCompatible = false
  
  public init() {}
  
  public func execute(arguments: String) async throws -> String {
    guard let data = arguments.data(using: .utf8) else {
      throw ISAToolError.invalidArguments("Could not parse arguments")
    }
    
    let decoder = JSONDecoder()
    let args = try decoder.decode(Arguments.self, from: data)
    
    // Expand tilde if present
    let expandedPath = NSString(string: args.filePath).expandingTildeInPath
    
    // Check if file exists
    guard FileManager.default.fileExists(atPath: expandedPath) else {
      throw ISAToolError.fileNotFound(expandedPath)
    }
    
    // Validate that old_string and new_string are different
    guard args.oldString != args.newString else {
      throw ISAToolError.invalidArguments("old_string and new_string must be different")
    }
    
    // Read file content
    let content = try String(contentsOfFile: expandedPath, encoding: .utf8)
    
    // Check if old_string exists in the file
    guard content.contains(args.oldString) else {
      throw ISAToolError.stringNotFound("Could not find '\(args.oldString)' in file")
    }
    
    // Count occurrences
    let occurrences = content.components(separatedBy: args.oldString).count - 1
    
    // If not replace_all and multiple occurrences, fail
    if !args.replaceAll && occurrences > 1 {
      throw ISAToolError.ambiguousMatch(
        "Found \(occurrences) occurrences of old_string. Use replace_all=true or provide more context to make it unique"
      )
    }
    
    // Perform replacement
    let newContent: String
    if args.replaceAll {
      newContent = content.replacingOccurrences(of: args.oldString, with: args.newString)
    } else {
      // Replace only first occurrence
      if let range = content.range(of: args.oldString) {
        newContent = content.replacingCharacters(in: range, with: args.newString)
      } else {
        // Should never reach here due to earlier check
        throw ISAToolError.stringNotFound("Could not find string to replace")
      }
    }
    
    // Write back to file
    try newContent.write(toFile: expandedPath, atomically: true, encoding: .utf8)
    
    // Mark file as read for ISAWriteTool tracking
    ISAWriteTool.markFileAsRead(expandedPath)
    
    let replacedCount = args.replaceAll ? occurrences : 1
    return "Successfully replaced \(replacedCount) occurrence(s) in \(expandedPath)"
  }
  
  private struct Arguments: Codable {
    let file_path: String
    let old_string: String
    let new_string: String
    let replace_all: Bool?
    
    var filePath: String { file_path }
    var oldString: String { old_string }
    var newString: String { new_string }
    var replaceAll: Bool { replace_all ?? false }
  }
}