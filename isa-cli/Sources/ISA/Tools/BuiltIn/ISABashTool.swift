import Foundation
import SwiftOpenAICLICore
import SwiftOpenAI

public class ISABashTool: CLITool {
  public let name = "isa__bash"
  
  public let description = """
  Executes a given bash command in a persistent shell session with optional timeout, ensuring proper handling and security measures.
  
  Before executing the command, please follow these steps:
  
  1. Directory Verification:
     - If the command will create new directories or files, first use the LS tool to verify the parent directory exists and is the correct location
     - For example, before running "mkdir foo/bar", first use LS to check that "foo" exists and is the intended parent directory
  
  2. Command Execution:
     - Always quote file paths that contain spaces with double quotes (e.g., cd "path with spaces/file.txt")
     - Examples of proper quoting:
       - cd "/Users/name/My Documents" (correct)
       - cd /Users/name/My Documents (incorrect - will fail)
       - python "/path/with spaces/script.py" (correct)
       - python /path/with spaces/script.py (incorrect - will fail)
     - After ensuring proper quoting, execute the command.
     - Capture the output of the command.
  
  Usage notes:
    - The command argument is required.
    - You can specify an optional timeout in milliseconds (up to 600000ms / 10 minutes). If not specified, commands will timeout after 120000ms (2 minutes).
    - It is very helpful if you write a clear, concise description of what this command does in 5-10 words.
    - If the output exceeds 30000 characters, output will be truncated before being returned to you.
    - You can use the `run_in_background` parameter to run the command in the background, which allows you to continue working while the command runs.
    - VERY IMPORTANT: You MUST avoid using search commands like `find` and `grep`. Instead use Grep, Glob tools to search.
    - If you _still_ need to run `grep`, STOP. ALWAYS USE ripgrep at `rg` first, which all ISA users have pre-installed.
    - When issuing multiple commands, use the ';' or '&&' operator to separate them. DO NOT use newlines (newlines are ok in quoted strings).
    - Try to maintain your current working directory throughout the session by using absolute paths and avoiding usage of `cd`.
  """
  
  public var parameters: JSONSchema {
    return JSONSchema(
      type: .object,
      properties: [
        "command": JSONSchema(
          type: .string,
          description: "The command to execute"
        ),
        "timeout": JSONSchema(
          type: .number,
          description: "Optional timeout in milliseconds (max 600000)"
        ),
        "description": JSONSchema(
          type: .string,
          description: "Clear, concise description of what this command does in 5-10 words."
        ),
        "run_in_background": JSONSchema(
          type: .boolean,
          description: "Set to true to run this command in the background."
        )
      ],
      required: ["command"]  // Only command is required
    )
  }
  
  public let isStrictModeCompatible = false
  
  // Track background processes
  private static var backgroundProcesses: [String: Process] = [:]
  private static var processCounter = 0
  
  public init() {}
  
  public func execute(arguments: String) async throws -> String {
    guard let data = arguments.data(using: .utf8) else {
      throw ISAToolError.invalidArguments("Could not parse arguments")
    }
    
    let decoder = JSONDecoder()
    let args = try decoder.decode(Arguments.self, from: data)
    
    // Validate timeout
    let timeout = args.timeout ?? 120000
    guard timeout > 0 && timeout <= 600000 else {
      throw ISAToolError.invalidArguments("Timeout must be between 1 and 600000 milliseconds")
    }
    
    // Check for dangerous commands
    let dangerousPatterns = [
      "rm -rf /",
      "rm -rf /*",
      ":(){ :|:& };:",  // Fork bomb
      "> /dev/sda",
      "dd if=/dev/random of=/dev/sda"
    ]
    
    for pattern in dangerousPatterns {
      if args.command.contains(pattern) {
        throw ISAToolError.dangerousCommand("Refusing to execute potentially dangerous command")
      }
    }
    
    // Setup process
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/bash")
    process.arguments = ["-c", args.command]
    process.currentDirectoryURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    
    // Setup environment
    var environment = ProcessInfo.processInfo.environment
    environment["ISA_TOOL"] = "true"
    process.environment = environment
    
    let outputPipe = Pipe()
    let errorPipe = Pipe()
    process.standardOutput = outputPipe
    process.standardError = errorPipe
    
    // Handle background execution
    if args.runInBackground == true {
      let processId = "bg_\(ISABashTool.processCounter)"
      ISABashTool.processCounter += 1
      ISABashTool.backgroundProcesses[processId] = process
      
      try process.run()
      
      return """
      Started background process: \(processId)
      Command: \(args.command)
      \(args.description ?? "")
      
      Process is running in the background. Check status with appropriate commands.
      """
    }
    
    // Normal execution with timeout
    try process.run()
    
    // Setup timeout
    let timeoutWorkItem = DispatchWorkItem {
      if process.isRunning {
        process.terminate()
      }
    }
    
    DispatchQueue.global().asyncAfter(
      deadline: .now() + .milliseconds(Int(timeout)),
      execute: timeoutWorkItem
    )
    
    process.waitUntilExit()
    timeoutWorkItem.cancel()
    
    // Read output
    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
    
    var output = String(data: outputData, encoding: .utf8) ?? ""
    let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
    
    // Check if process was terminated due to timeout
    if process.terminationReason == .uncaughtSignal && process.terminationStatus == 15 {
      throw ISAToolError.timeout("Command timed out after \(timeout)ms")
    }
    
    // Combine stdout and stderr
    if !errorOutput.isEmpty {
      if !output.isEmpty {
        output += "\n"
      }
      output += errorOutput
    }
    
    // Truncate if too long
    if output.count > 30000 {
      output = String(output.prefix(30000)) + "\n... [Output truncated - \(output.count - 30000) characters omitted]"
    }
    
    // Add exit status if non-zero
    if process.terminationStatus != 0 {
      output += "\n[Exit code: \(process.terminationStatus)]"
    }
    
    return output.isEmpty ? "[Command completed with no output]" : output
  }
  
  private struct Arguments: Codable {
    let command: String
    let timeout: Double?
    let description: String?
    let runInBackground: Bool?
    
    private enum CodingKeys: String, CodingKey {
      case command, timeout, description
      case runInBackground = "run_in_background"
    }
  }
}