import Foundation
import SwiftOpenAI

class LocalTool: CLITool {
    private let toolName: String
    private let toolDescription: String
    private let command: String?
    private let script: String?
    private let toolParameters: JSONSchema
    private let workingDirectory: String?
    
    init(name: String, description: String, command: String? = nil, script: String? = nil, parameters: JSONSchema, workingDirectory: String? = nil) {
        self.toolName = name
        self.toolDescription = description
        self.command = command
        self.script = script
        self.toolParameters = parameters
        self.workingDirectory = workingDirectory
    }
    
    var name: String {
        return "local__\(toolName)"
    }
    
    var description: String {
        return toolDescription
    }
    
    var parameters: JSONSchema {
        return toolParameters
    }
    
    var isStrictModeCompatible: Bool {
        return true
    }
    
    func execute(arguments: String) async throws -> String {
        let args = try parseArguments(arguments)
        
        if let command = command {
            return try await executeCommand(command, with: args)
        } else if let script = script {
            return try await executeScript(script, with: args)
        } else {
            throw LocalToolError.noExecutableSpecified
        }
    }
    
    private func parseArguments(_ jsonString: String) throws -> [String: Any] {
        guard !jsonString.isEmpty else { return [:] }
        
        guard let data = jsonString.data(using: .utf8) else {
            throw LocalToolError.invalidArguments("Failed to convert arguments to data")
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LocalToolError.invalidArguments("Arguments must be a JSON object")
        }
        
        return json
    }
    
    private func executeCommand(_ command: String, with args: [String: Any]) async throws -> String {
        let interpolatedCommand = interpolateCommand(command, with: args)
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", interpolatedCommand]
        
        if let workingDirectory = workingDirectory {
            process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
        }
        
        let pipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = pipe
        process.standardError = errorPipe
        
        try process.run()
        process.waitUntilExit()
        
        let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        
        if process.terminationStatus != 0 {
            let errorOutput = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw LocalToolError.commandFailed(errorOutput)
        }
        
        let output = String(data: outputData, encoding: .utf8) ?? ""
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func executeScript(_ scriptPath: String, with args: [String: Any]) async throws -> String {
        let scriptURL = URL(fileURLWithPath: scriptPath)
        
        guard FileManager.default.fileExists(atPath: scriptPath) else {
            throw LocalToolError.scriptNotFound(scriptPath)
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: args)
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
        
        let process = Process()
        process.executableURL = scriptURL
        process.arguments = [jsonString]
        
        if let workingDirectory = workingDirectory {
            process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
        }
        
        let pipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = pipe
        process.standardError = errorPipe
        
        try process.run()
        process.waitUntilExit()
        
        let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        
        if process.terminationStatus != 0 {
            let errorOutput = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw LocalToolError.scriptFailed(errorOutput)
        }
        
        let output = String(data: outputData, encoding: .utf8) ?? ""
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func interpolateCommand(_ command: String, with args: [String: Any]) -> String {
        var result = command
        
        for (key, value) in args {
            let placeholder = "{{\(key)}}"
            let escapedValue = escapeShellArgument(String(describing: value))
            result = result.replacingOccurrences(of: placeholder, with: escapedValue)
        }
        
        return result
    }
    
    private func escapeShellArgument(_ arg: String) -> String {
        let specialCharacters = CharacterSet(charactersIn: "\"'\\$`! ")
        if arg.rangeOfCharacter(from: specialCharacters) != nil {
            let escaped = arg.replacingOccurrences(of: "'", with: "'\\''")
            return "'\(escaped)'"
        }
        return arg
    }
}

enum LocalToolError: LocalizedError {
    case noExecutableSpecified
    case invalidArguments(String)
    case commandFailed(String)
    case scriptNotFound(String)
    case scriptFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .noExecutableSpecified:
            return "No command or script specified for local tool"
        case .invalidArguments(let message):
            return "Invalid arguments: \(message)"
        case .commandFailed(let error):
            return "Command execution failed: \(error)"
        case .scriptNotFound(let path):
            return "Script not found: \(path)"
        case .scriptFailed(let error):
            return "Script execution failed: \(error)"
        }
    }
}