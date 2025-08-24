import Foundation
import SwiftOpenAICLICore
import SwiftOpenAI

public class ISAGrepTool: CLITool {
  public let name = "isa__grep"
  
  public let description = """
  A powerful search tool built on ripgrep
  
  Usage:
  - ALWAYS use Grep for search tasks. NEVER invoke `grep` or `rg` as a Bash command. The Grep tool has been optimized for correct permissions and access.
  - Supports full regex syntax (e.g., "log.*Error", "function\\s+\\w+")
  - Filter files with glob parameter (e.g., "*.js", "**/*.tsx") or type parameter (e.g., "js", "py", "rust")
  - Output modes: "content" shows matching lines, "files_with_matches" shows only file paths (default), "count" shows match counts
  - Use Task tool for open-ended searches requiring multiple rounds
  - Pattern syntax: Uses ripgrep (not grep) - literal braces need escaping (use `interface\\{\\}` to find `interface{}` in Go code)
  - Multiline matching: By default patterns match within single lines only. For cross-line patterns like `struct \\{[\\s\\S]*?field`, use `multiline: true`
  """
  
  public var parameters: JSONSchema {
    return JSONSchema(
      type: .object,
      properties: [
        "pattern": JSONSchema(
          type: .string,
          description: "The regular expression pattern to search for in file contents"
        ),
        "path": JSONSchema(
          type: .string,
          description: "File or directory to search in (rg PATH). Defaults to current working directory."
        ),
        "glob": JSONSchema(
          type: .string,
          description: "Glob pattern to filter files (e.g. \"*.js\", \"*.{ts,tsx}\") - maps to rg --glob"
        ),
        "type": JSONSchema(
          type: .string,
          description: "File type to search (rg --type). Common types: js, py, rust, go, java, etc. More efficient than include for standard file types."
        ),
        "output_mode": JSONSchema(
          type: .string,
          description: "Output mode: \"content\" shows matching lines (supports -A/-B/-C context, -n line numbers, head_limit), \"files_with_matches\" shows file paths (supports head_limit), \"count\" shows match counts (supports head_limit). Defaults to \"files_with_matches\".",
          enum: ["content", "files_with_matches", "count"]
        ),
        "case_insensitive": JSONSchema(
          type: .boolean,
          description: "Case insensitive search (rg -i)"
        ),
        "line_numbers": JSONSchema(
          type: .boolean,
          description: "Show line numbers in output (rg -n). Requires output_mode: \"content\", ignored otherwise."
        ),
        "after_context": JSONSchema(
          type: .number,
          description: "Number of lines to show after each match (rg -A). Requires output_mode: \"content\", ignored otherwise."
        ),
        "before_context": JSONSchema(
          type: .number,
          description: "Number of lines to show before each match (rg -B). Requires output_mode: \"content\", ignored otherwise."
        ),
        "context": JSONSchema(
          type: .number,
          description: "Number of lines to show before and after each match (rg -C). Requires output_mode: \"content\", ignored otherwise."
        ),
        "multiline": JSONSchema(
          type: .boolean,
          description: "Enable multiline mode where . matches newlines and patterns can span lines (rg -U --multiline-dotall). Default: false."
        ),
        "head_limit": JSONSchema(
          type: .number,
          description: "Limit output to first N lines/entries, equivalent to \"| head -N\". Works across all output modes: content (limits output lines), files_with_matches (limits file paths), count (limits count entries). When unspecified, shows all results from ripgrep."
        )
      ],
      required: ["pattern", "path", "glob", "type", "output_mode", "case_insensitive", "line_numbers", "after_context", "before_context", "context", "multiline", "head_limit"]
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
    
    // Build ripgrep command
    var command = ["rg"]
    
    // Add pattern (properly escaped)
    command.append(args.pattern)
    
    // Add path if specified
    if let path = args.path {
      command.append(NSString(string: path).expandingTildeInPath)
    }
    
    // Add flags based on output mode
    let outputMode = args.outputMode ?? "files_with_matches"
    switch outputMode {
    case "files_with_matches":
      command.append("--files-with-matches")
    case "count":
      command.append("--count")
    case "content":
      // Default behavior - show matching lines
      if args.lineNumbers == true {
        command.append("-n")
      }
      if let a = args.afterContext {
        command.append("-A")
        command.append("\(Int(a))")
      }
      if let b = args.beforeContext {
        command.append("-B")
        command.append("\(Int(b))")
      }
      if let c = args.context {
        command.append("-C")
        command.append("\(Int(c))")
      }
    default:
      break
    }
    
    // Add other flags
    if args.caseInsensitive == true {
      command.append("-i")
    }
    
    if args.multiline == true {
      command.append("-U")
      command.append("--multiline-dotall")
    }
    
    if let glob = args.glob {
      command.append("--glob")
      command.append(glob)
    }
    
    if let type = args.type, !type.isEmpty {
      command.append("--type")
      command.append(type)
    }
    
    // Execute ripgrep
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = command
    
    let pipe = Pipe()
    let errorPipe = Pipe()
    process.standardOutput = pipe
    process.standardError = errorPipe
    
    do {
      try process.run()
      process.waitUntilExit()
    } catch {
      // Check if ripgrep is installed
      let checkProcess = Process()
      checkProcess.executableURL = URL(fileURLWithPath: "/usr/bin/which")
      checkProcess.arguments = ["rg"]
      let checkPipe = Pipe()
      checkProcess.standardOutput = checkPipe
      try? checkProcess.run()
      checkProcess.waitUntilExit()
      
      if checkProcess.terminationStatus != 0 {
        throw ISAToolError.commandNotFound("ripgrep (rg) is not installed. Please install it with: brew install ripgrep")
      }
      throw error
    }
    
    let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
    var output = String(data: outputData, encoding: .utf8) ?? ""
    
    // Apply head limit if specified
    if let headLimit = args.headLimit {
      let lines = output.components(separatedBy: .newlines)
      let limited = lines.prefix(Int(headLimit))
      output = limited.joined(separator: "\n")
      
      if lines.count > Int(headLimit) {
        output += "\n... [\(lines.count - Int(headLimit)) more results]"
      }
    }
    
    // Handle empty results
    if output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      if process.terminationStatus == 1 {
        // No matches found (this is normal)
        return "No matches found for pattern: \(args.pattern)"
      } else if process.terminationStatus != 0 {
        // Error occurred
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let errorOutput = String(data: errorData, encoding: .utf8) ?? "Unknown error"
        throw ISAToolError.commandFailed("ripgrep failed: \(errorOutput)")
      }
      return "No matches found"
    }
    
    return output
  }
  
  private struct Arguments: Codable {
    let pattern: String
    let path: String?
    let glob: String?
    let type: String?
    let outputMode: String?
    let caseInsensitive: Bool?
    let lineNumbers: Bool?
    let afterContext: Double?
    let beforeContext: Double?
    let context: Double?
    let multiline: Bool?
    let headLimit: Double?
    
    private enum CodingKeys: String, CodingKey {
      case pattern, path, glob, type
      case outputMode = "output_mode"
      case caseInsensitive = "case_insensitive"
      case lineNumbers = "line_numbers"
      case afterContext = "after_context"
      case beforeContext = "before_context"
      case context = "context"
      case multiline
      case headLimit = "head_limit"
    }
  }
}