import Foundation
import SwiftOpenAICLICore
import SwiftOpenAI

public class ISAReadTool: CLITool {
  public let name = "isa__read"
  
  public let description = """
  Reads a file from the local filesystem. You can access any file directly by using this tool.
  Assume this tool is able to read all files on the machine. If the User provides a path to a file assume that path is valid. It is okay to read a file that does not exist; an error will be returned.
  
  Usage:
  - The file_path parameter must be an absolute path, not a relative path
  - By default, it reads up to 2000 lines starting from the beginning of the file
  - You can optionally specify a line offset and limit (especially handy for long files), but it's recommended to read the whole file by not providing these parameters
  - Any lines longer than 2000 characters will be truncated
  - Results are returned using cat -n format, with line numbers starting at 1
  - This tool allows reading images (eg PNG, JPG, etc). When reading an image file the contents are presented as base64
  - You have the capability to call multiple tools in a single response. It is always better to speculatively read multiple files as a batch that are potentially useful
  """
  
  public var parameters: JSONSchema {
    return JSONSchema(
      type: .object,
      properties: [
        "file_path": JSONSchema(
          type: .string,
          description: "The absolute path to the file to read"
        ),
        "offset": JSONSchema(
          type: .number,
          description: "The line number to start reading from. Only provide if the file is too large to read at once"
        ),
        "limit": JSONSchema(
          type: .number,
          description: "The number of lines to read. Only provide if the file is too large to read at once."
        )
      ],
      required: ["file_path", "offset", "limit"]
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
    
    // Track that this file has been read (for ISAWriteTool)
    ISAWriteTool.markFileAsRead(expandedPath)
    
    // Check if it's an image file
    let imageExtensions = ["png", "jpg", "jpeg", "gif", "bmp", "tiff", "webp", "svg"]
    let pathExtension = (expandedPath as NSString).pathExtension.lowercased()
    
    if imageExtensions.contains(pathExtension) {
      // Read image as base64
      let imageData = try Data(contentsOf: URL(fileURLWithPath: expandedPath))
      let base64String = imageData.base64EncodedString()
      return "Image file (\(pathExtension)):\n\(base64String)"
    }
    
    // Read text file
    let content = try String(contentsOfFile: expandedPath, encoding: .utf8)
    let lines = content.components(separatedBy: .newlines)
    
    let offset = args.offset ?? 1
    let limit = args.limit ?? 2000
    
    // Validate offset
    guard offset > 0 else {
      throw ISAToolError.invalidArguments("Offset must be greater than 0")
    }
    
    // Calculate range
    let startIndex = offset - 1
    let endIndex = min(startIndex + limit, lines.count)
    
    guard startIndex < lines.count else {
      return "No lines to display (offset beyond file length)"
    }
    
    // Format output with line numbers (cat -n style)
    var result = ""
    for i in startIndex..<endIndex {
      let lineNumber = i + 1
      var line = lines[i]
      
      // Truncate long lines
      if line.count > 2000 {
        line = String(line.prefix(2000)) + "... [truncated]"
      }
      
      result += String(format: "%6d\t%@\n", lineNumber, line)
    }
    
    // Add indication if there are more lines
    if endIndex < lines.count {
      result += "\n... [\(lines.count - endIndex) more lines]"
    }
    
    return result
  }
  
  private struct Arguments: Codable {
    let file_path: String
    let offset: Int?
    let limit: Int?
    
    var filePath: String { file_path }
  }
}