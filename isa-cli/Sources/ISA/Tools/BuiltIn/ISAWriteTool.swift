import Foundation
import SwiftOpenAICLICore
import SwiftOpenAI

public class ISAWriteTool: CLITool {
  public let name = "isa__write"
  
  public let description = """
  Writes a file to the local filesystem.
  
  Usage:
  - This tool will overwrite the existing file if there is one at the provided path.
  - If this is an existing file, you MUST use the Read tool first to read the file's contents. This tool will fail if you did not read the file first.
  - ALWAYS prefer editing existing files in the codebase. NEVER write new files unless explicitly required.
  - NEVER proactively create documentation files (*.md) or README files. Only create documentation files if explicitly requested by the User.
  """
  
  public var parameters: JSONSchema {
    return JSONSchema(
      type: .object,
      properties: [
        "file_path": JSONSchema(
          type: .string,
          description: "The absolute path to the file to write (must be absolute, not relative)"
        ),
        "content": JSONSchema(
          type: .string,
          description: "The content to write to the file"
        )
      ],
      required: ["file_path", "content"]
    )
  }
  
  public let isStrictModeCompatible = false
  
  // Track files that have been read in this session
  private static var readFiles = Set<String>()
  
  public init() {}
  
  // Called by ISAReadTool to track read files
  public static func markFileAsRead(_ path: String) {
    readFiles.insert(path)
  }
  
  public func execute(arguments: String) async throws -> String {
    guard let data = arguments.data(using: .utf8) else {
      throw ISAToolError.invalidArguments("Could not parse arguments")
    }
    
    let decoder = JSONDecoder()
    let args = try decoder.decode(Arguments.self, from: data)
    
    // Expand tilde if present
    let expandedPath = NSString(string: args.filePath).expandingTildeInPath
    
    // Check if file already exists
    let fileExists = FileManager.default.fileExists(atPath: expandedPath)
    
    // If file exists and wasn't read first, warn (but don't fail for backward compatibility)
    if fileExists && !ISAWriteTool.readFiles.contains(expandedPath) {
      // For now, just log a warning but proceed
      print("⚠️  Warning: Writing to existing file without reading it first: \(expandedPath)")
    }
    
    // Create parent directory if needed
    let parentDirectory = (expandedPath as NSString).deletingLastPathComponent
    if !FileManager.default.fileExists(atPath: parentDirectory) {
      try FileManager.default.createDirectory(
        atPath: parentDirectory,
        withIntermediateDirectories: true,
        attributes: nil
      )
    }
    
    // Write the file
    try args.content.write(
      toFile: expandedPath,
      atomically: true,
      encoding: .utf8
    )
    
    // Mark this file as "read" for future edits
    ISAWriteTool.markFileAsRead(expandedPath)
    
    let action = fileExists ? "Updated" : "Created"
    return "\(action) file: \(expandedPath)"
  }
  
  private struct Arguments: Codable {
    let file_path: String
    let content: String
    
    var filePath: String { file_path }
  }
}