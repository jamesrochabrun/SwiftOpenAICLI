import Foundation
import SwiftOpenAICLICore
import SwiftOpenAI

public class ISAGlobTool: CLITool {
  public let name = "isa__glob"
  
  public let description = """
  - Fast file pattern matching tool that works with any codebase size
  - Supports glob patterns like "**/*.js" or "src/**/*.ts"
  - Returns matching file paths sorted by modification time
  - Use this tool when you need to find files by name patterns
  - When you are doing an open ended search that may require multiple rounds of globbing and grepping, use the Agent tool instead
  - You have the capability to call multiple tools in a single response. It is always better to speculatively perform multiple searches as a batch that are potentially useful.
  """
  
  public var parameters: JSONSchema {
    return JSONSchema(
      type: .object,
      properties: [
        "pattern": JSONSchema(
          type: .string,
          description: "The glob pattern to match files against"
        ),
        "path": JSONSchema(
          type: .string,
          description: "The directory to search in. If not specified, the current working directory will be used. IMPORTANT: Omit this field to use the default directory. DO NOT enter \"undefined\" or \"null\" - simply omit it for the default behavior. Must be a valid directory path if provided."
        )
      ],
      required: ["pattern"]  // Path is optional, defaults to current directory
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
    
    // Determine search path
    let searchPath: String
    if let providedPath = args.path {
      searchPath = NSString(string: providedPath).expandingTildeInPath
    } else {
      searchPath = FileManager.default.currentDirectoryPath
    }
    
    // Verify path exists and is a directory
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: searchPath, isDirectory: &isDirectory) else {
      throw ISAToolError.directoryNotFound(searchPath)
    }
    guard isDirectory.boolValue else {
      throw ISAToolError.invalidArguments("\(searchPath) is not a directory")
    }
    
    // Convert glob pattern to regex
    let regexPattern = globToRegex(args.pattern)
    let regex = try NSRegularExpression(pattern: regexPattern, options: [])
    
    // Find matching files
    var matchedFiles: [(path: String, modifiedDate: Date)] = []
    
    let enumerator = FileManager.default.enumerator(
      at: URL(fileURLWithPath: searchPath),
      includingPropertiesForKeys: [.contentModificationDateKey],
      options: [.skipsHiddenFiles]
    )
    
    while let fileURL = enumerator?.nextObject() as? URL {
      let relativePath = fileURL.path.replacingOccurrences(of: searchPath + "/", with: "")
      
      // Check if path matches pattern
      let range = NSRange(location: 0, length: relativePath.utf16.count)
      if regex.firstMatch(in: relativePath, options: [], range: range) != nil {
        // Get modification date
        let modDate = (try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date()
        matchedFiles.append((path: fileURL.path, modifiedDate: modDate))
      }
    }
    
    // Sort by modification time (newest first)
    matchedFiles.sort { $0.modifiedDate > $1.modifiedDate }
    
    if matchedFiles.isEmpty {
      return "No files found matching pattern: \(args.pattern)"
    }
    
    // Return file paths, one per line
    return matchedFiles.map { $0.path }.joined(separator: "\n")
  }
  
  private func globToRegex(_ pattern: String) -> String {
    var regex = "^"
    var i = 0
    let chars = Array(pattern)
    
    while i < chars.count {
      let char = chars[i]
      
      switch char {
      case "*":
        // Check for **
        if i + 1 < chars.count && chars[i + 1] == "*" {
          regex += ".*"
          i += 1
        } else {
          regex += "[^/]*"
        }
      case "?":
        regex += "[^/]"
      case "[":
        // Character class - find the closing ]
        var j = i + 1
        while j < chars.count && chars[j] != "]" {
          j += 1
        }
        if j < chars.count {
          let charClass = String(chars[i...j])
          regex += charClass
          i = j
        } else {
          regex += "\\["
        }
      case ".":
        regex += "\\."
      case "/":
        regex += "/"
      case "\\":
        if i + 1 < chars.count {
          i += 1
          regex += "\\\(chars[i])"
        }
      default:
        if "(){}+^$|".contains(char) {
          regex += "\\\(char)"
        } else {
          regex += String(char)
        }
      }
      
      i += 1
    }
    
    regex += "$"
    return regex
  }
  
  private struct Arguments: Codable {
    let pattern: String
    let path: String?
  }
}