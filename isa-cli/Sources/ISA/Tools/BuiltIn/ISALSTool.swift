import Foundation
import SwiftOpenAICLICore
import SwiftOpenAI

public class ISALSTool: CLITool {
  public let name = "isa__ls"
  
  public let description = """
  Lists files and directories in a given path. The path parameter must be an absolute path, not a relative path. You can optionally provide an array of glob patterns to ignore with the ignore parameter. You should generally prefer the Glob and Grep tools, if you know which directories to search.
  """
  
  public var parameters: JSONSchema {
    return JSONSchema(
      type: .object,
      properties: [
        "path": JSONSchema(
          type: .string,
          description: "The absolute path to the directory to list (must be absolute, not relative)"
        ),
        "ignore": JSONSchema(
          type: .array,
          description: "List of glob patterns to ignore",
          items: JSONSchema(type: .string)
        )
      ],
      required: ["path"]
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
    
    // Validate that path is absolute
    guard args.path.hasPrefix("/") || args.path.hasPrefix("~") else {
      throw ISAToolError.invalidArguments("Path must be absolute (starting with / or ~)")
    }
    
    // Expand tilde if present
    let expandedPath = NSString(string: args.path).expandingTildeInPath
    
    // Check if path exists and is a directory
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: expandedPath, isDirectory: &isDirectory) else {
      throw ISAToolError.directoryNotFound(expandedPath)
    }
    guard isDirectory.boolValue else {
      throw ISAToolError.invalidArguments("\(expandedPath) is not a directory")
    }
    
    // Get directory contents
    let contents = try FileManager.default.contentsOfDirectory(atPath: expandedPath)
    
    // Filter out ignored patterns
    var filteredContents = contents
    if let ignorePatterns = args.ignore, !ignorePatterns.isEmpty {
      filteredContents = contents.filter { item in
        !shouldIgnore(item, patterns: ignorePatterns)
      }
    }
    
    // Sort and format output
    var output: [String] = []
    
    for item in filteredContents.sorted() {
      let itemPath = (expandedPath as NSString).appendingPathComponent(item)
      var isDir: ObjCBool = false
      FileManager.default.fileExists(atPath: itemPath, isDirectory: &isDir)
      
      if isDir.boolValue {
        output.append("\(item)/")
      } else {
        // Get file size
        if let attributes = try? FileManager.default.attributesOfItem(atPath: itemPath),
           let fileSize = attributes[.size] as? Int64 {
          let sizeStr = formatFileSize(fileSize)
          output.append("\(item) (\(sizeStr))")
        } else {
          output.append(item)
        }
      }
    }
    
    if output.isEmpty {
      return "Directory is empty or all contents are ignored"
    }
    
    // Add summary
    let dirCount = filteredContents.filter { item in
      let itemPath = (expandedPath as NSString).appendingPathComponent(item)
      var isDir: ObjCBool = false
      FileManager.default.fileExists(atPath: itemPath, isDirectory: &isDir)
      return isDir.boolValue
    }.count
    
    let fileCount = filteredContents.count - dirCount
    
    var result = output.joined(separator: "\n")
    result += "\n\nTotal: \(fileCount) file(s), \(dirCount) directory(ies)"
    
    return result
  }
  
  private func shouldIgnore(_ item: String, patterns: [String]) -> Bool {
    for pattern in patterns {
      if matchesGlob(item, pattern: pattern) {
        return true
      }
    }
    return false
  }
  
  private func matchesGlob(_ item: String, pattern: String) -> Bool {
    // Simple glob matching
    if pattern.contains("*") {
      let regexPattern = pattern
        .replacingOccurrences(of: ".", with: "\\.")
        .replacingOccurrences(of: "*", with: ".*")
      
      if let regex = try? NSRegularExpression(pattern: "^\(regexPattern)$", options: []) {
        let range = NSRange(location: 0, length: item.utf16.count)
        return regex.firstMatch(in: item, options: [], range: range) != nil
      }
    }
    return item == pattern
  }
  
  private func formatFileSize(_ bytes: Int64) -> String {
    let formatter = ByteCountFormatter()
    formatter.countStyle = .file
    formatter.includesUnit = true
    formatter.isAdaptive = true
    return formatter.string(fromByteCount: bytes)
  }
  
  private struct Arguments: Codable {
    let path: String
    let ignore: [String]?
  }
}