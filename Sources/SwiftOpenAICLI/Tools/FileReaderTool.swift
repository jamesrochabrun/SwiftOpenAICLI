import Foundation
import SwiftOpenAI

struct FileReaderTool: CLITool {
  let name = "file_reader"
  let description = "Read contents of a file from the filesystem"
  
  var parameters: JSONSchema {
    return JSONSchema(
      type: .object,
      properties: [
        "path": JSONSchema(
          type: .string,
          description: "Path to the file to read (absolute or relative to current directory)"
        ),
        "lines": JSONSchema(
          type: .optional(.integer),
          description: "Number of lines to read from the beginning (optional, defaults to entire file)"
        )
      ],
      required: ["path", "lines"]
    )
  }
  
  func execute(arguments: String) async throws -> String {
    guard let data = arguments.data(using: .utf8),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let path = json["path"] as? String else {
      return "Error: Invalid arguments. Expected 'path' field."
    }
    
    let fileURL: URL
    if path.starts(with: "/") {
      fileURL = URL(fileURLWithPath: path)
    } else {
      let currentDirectory = FileManager.default.currentDirectoryPath
      fileURL = URL(fileURLWithPath: currentDirectory).appendingPathComponent(path)
    }
    
    guard FileManager.default.fileExists(atPath: fileURL.path) else {
      return "Error: File not found at path: \(fileURL.path)"
    }
    
    do {
      let contents = try String(contentsOf: fileURL, encoding: .utf8)
      let lines = contents.components(separatedBy: .newlines)
      
      if let maxLines = json["lines"] as? Int, maxLines > 0 {
        let selectedLines = Array(lines.prefix(maxLines))
        return "File contents (first \(min(maxLines, lines.count)) lines):\n\(selectedLines.joined(separator: "\n"))"
      } else {
        return "File contents:\n\(contents)"
      }
    } catch {
      return "Error reading file: \(error.localizedDescription)"
    }
  }
}
