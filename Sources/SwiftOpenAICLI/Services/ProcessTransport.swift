import Foundation
import MCP
import System
import Logging

/// A transport that launches and communicates with an MCP server process
actor ProcessTransport: Transport {
    private let command: String
    private let args: [String]
    private let environment: [String: String]?
    private let verbose: Bool
    private var process: Process?
    private var inputPipe: Pipe?
    private var outputPipe: Pipe?
    private var errorPipe: Pipe?
    private var stdioTransport: StdioTransport?
    
    nonisolated let logger = Logger(label: "ProcessTransport")
    
    init(command: String, args: [String] = [], environment: [String: String]? = nil, verbose: Bool = false) {
        self.command = command
        self.args = args
        self.environment = environment
        self.verbose = verbose
    }
    
    private func resolveCommand(_ command: String) -> String {
        // If the command is already an absolute path, use it as-is
        if command.hasPrefix("/") {
            return command
        }
        
        // Try to find the command using 'which' to resolve it from PATH
        let whichProcess = Process()
        whichProcess.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        whichProcess.arguments = [command]
        
        let pipe = Pipe()
        whichProcess.standardOutput = pipe
        whichProcess.standardError = Pipe()
        
        do {
            try whichProcess.run()
            whichProcess.waitUntilExit()
            
            if whichProcess.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !path.isEmpty {
                    if verbose {
                        print("[ProcessTransport] Resolved '\(command)' to '\(path)'")
                    }
                    return path
                }
            }
        } catch {
            if verbose {
                print("[ProcessTransport] Failed to resolve '\(command)' via which: \(error)")
            }
        }
        
        // If 'which' fails, fall back to the original command
        // The shell might still be able to find it
        return command
    }
    
    func connect() async throws {
        let process = Process()
        
        // Try to resolve the command through the shell to handle PATH properly
        let resolvedCommand = resolveCommand(command)
        process.executableURL = URL(fileURLWithPath: resolvedCommand)
        
        // If this is npx, automatically add -y flag for auto-installation
        var processArgs = args
        if command == "npx" || resolvedCommand.hasSuffix("/npx") {
            // Check if -y flag is not already present
            if !args.contains("-y") && !args.contains("--yes") {
                processArgs = ["-y"] + args
            }
        }
        process.arguments = processArgs
        
        // Inherit the current environment to ensure PATH is available
        var processEnvironment = ProcessInfo.processInfo.environment
        if let environment = environment {
            processEnvironment.merge(environment) { _, new in new }
        }
        process.environment = processEnvironment
        
        let inputPipe = Pipe()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        if verbose {
            // Monitor stderr for debugging
            errorPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty, let error = String(data: data, encoding: .utf8) {
                    print("[MCP Server Error] \(error)")
                }
            }
        }
        
        try process.run()
        
        self.process = process
        self.inputPipe = inputPipe
        self.outputPipe = outputPipe
        self.errorPipe = errorPipe
        
        // Create StdioTransport with the pipes using FileDescriptor
        let inputFD = FileDescriptor(rawValue: outputPipe.fileHandleForReading.fileDescriptor)
        let outputFD = FileDescriptor(rawValue: inputPipe.fileHandleForWriting.fileDescriptor)
        
        self.stdioTransport = StdioTransport(
            input: inputFD,
            output: outputFD
        )
        
        try await stdioTransport?.connect()
    }
    
    func disconnect() async {
        await stdioTransport?.disconnect()
        
        errorPipe?.fileHandleForReading.readabilityHandler = nil
        
        if let process = process, process.isRunning {
            process.terminate()
        }
        
        self.process = nil
        self.inputPipe = nil
        self.outputPipe = nil
        self.errorPipe = nil
        self.stdioTransport = nil
    }
    
    func send(_ data: Data) async throws {
        guard let transport = stdioTransport else {
            throw TransportError.notConnected
        }
        try await transport.send(data)
    }
    
    nonisolated func receive() -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            Task { [weak self] in
                guard let self = self else {
                    continuation.finish(throwing: TransportError.notConnected)
                    return
                }
                
                guard let transport = await self.stdioTransport else {
                    continuation.finish(throwing: TransportError.notConnected)
                    return
                }
                
                // StdioTransport receive() is an actor method, so we need to await it
                let stream = await transport.receive()
                
                do {
                    for try await data in stream {
                        continuation.yield(data)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

enum TransportError: LocalizedError {
    case notConnected
    
    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Transport is not connected"
        }
    }
}