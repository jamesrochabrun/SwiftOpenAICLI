import Foundation
import MCP
import Rainbow

struct MCPServerConfig {
    let name: String
    let transport: String  // "stdio" or "http"
    let command: String?  // For stdio transport
    let url: String?  // For http transport
    let args: [String]
    let environment: [String: String]?
}

actor MCPClient {
    private var activeClients: [String: Client] = [:]
    private let verbose: Bool
    private let useStderr: Bool
    
    init(verbose: Bool = false, useStderr: Bool = false) {
        self.verbose = verbose
        self.useStderr = useStderr
    }
    
    private func printStatus(_ message: String) {
        if useStderr {
            FileHandle.standardError.write(Data("\(message)\n".utf8))
        } else {
            print(message)
        }
    }
    
    func connectToServer(_ config: MCPServerConfig) async throws {
        if verbose {
            printStatus("🔗 Connecting to MCP server: \(config.name)".lightBlack)
        }
        
        let client = Client(
            name: "SwiftOpenAICLI",
            version: "1.0.0",
            configuration: .default
        )
        
        // Choose transport based on type
        if config.transport == "http", let urlString = config.url, let url = URL(string: urlString) {
            if verbose {
                printStatus("   Using HTTP transport: \(url)".lightBlack)
            }
            
            // Check if this is a Zapier URL - use custom transport for proper header handling
            let transport: any Transport
            if url.host?.contains("zapier.com") == true {
                if verbose {
                    printStatus("   Detected Zapier MCP server, using custom transport".lightBlack)
                }
                transport = ZapierHTTPTransport(endpoint: url)
            } else {
                if verbose {
                    printStatus("   Using standard HTTPClientTransport".lightBlack)
                }
                transport = HTTPClientTransport(
                    endpoint: url,
                    streaming: true  // Enable Server-Sent Events for real-time updates
                )
            }
            
            if verbose {
                printStatus("   Attempting to connect...".lightBlack)
            }
            
            do {
                let initResult = try await client.connect(transport: transport)
                
                if verbose {
                    printStatus("✅ Connected to: \(initResult.serverInfo.name) v\(initResult.serverInfo.version)".green)
                    let capabilities = initResult.capabilities
                    if capabilities.tools != nil {
                        printStatus("   Tools: supported".lightBlack)
                    }
                    if capabilities.resources != nil {
                        printStatus("   Resources: supported".lightBlack)
                    }
                    if capabilities.prompts != nil {
                        printStatus("   Prompts: supported".lightBlack)
                    }
                }
            } catch {
                if verbose {
                    printStatus("❌ Failed to connect to HTTP server: \(error)".red)
                }
                throw error
            }
        } else if let command = config.command {
            // Create process transport to launch local server
            if verbose {
                printStatus("   Using stdio transport: \(command)".lightBlack)
            }
            
            // When using stderr for our output, disable ProcessTransport verbose to avoid stdout pollution
            let transport = ProcessTransport(
                command: command,
                args: config.args,
                environment: config.environment,
                verbose: verbose && !useStderr
            )
            
            let initResult = try await client.connect(transport: transport)
            
            if verbose {
                printStatus("✅ Connected to: \(initResult.serverInfo.name) v\(initResult.serverInfo.version)".green)
                let capabilities = initResult.capabilities
                if capabilities.tools != nil {
                    printStatus("   Tools: supported".lightBlack)
                }
                if capabilities.resources != nil {
                    printStatus("   Resources: supported".lightBlack)
                }
                if capabilities.prompts != nil {
                    printStatus("   Prompts: supported".lightBlack)
                }
            }
        } else {
            throw MCPError.invalidConfiguration("Server \(config.name) has neither command nor URL")
        }
        
        activeClients[config.name] = client
    }
    
    func disconnectFromServer(_ name: String) async {
        activeClients.removeValue(forKey: name)
        
        if verbose {
            printStatus("🔌 Disconnected from MCP server: \(name)".lightBlack)
        }
    }
    
    func disconnectAll() async {
        for name in activeClients.keys {
            await disconnectFromServer(name)
        }
    }
    
    func getAvailableTools() async throws -> [String: MCP.Tool] {
        var allTools: [String: MCP.Tool] = [:]
        
        for (serverName, client) in activeClients {
            let (tools, _) = try await client.listTools()
            
            for tool in tools {
                allTools["\(serverName).\(tool.name)"] = tool
            }
        }
        
        return allTools
    }
    
    func executeTool(serverName: String, toolName: String, arguments: [String: Value]) async throws -> (content: [MCP.Tool.Content], isError: Bool?) {
        guard let client = activeClients[serverName] else {
            throw MCPError.serverNotConnected(serverName)
        }
        
        let result = try await client.callTool(
            name: toolName,
            arguments: arguments
        )
        
        return result
    }
    
    func getResources() async throws -> [String: Resource] {
        var allResources: [String: Resource] = [:]
        
        for (serverName, client) in activeClients {
            let (resources, _) = try await client.listResources()
            
            for resource in resources {
                allResources["\(serverName).\(resource.uri)"] = resource
            }
        }
        
        return allResources
    }
    
    func readResource(serverName: String, uri: String) async throws -> [Resource.Content] {
        guard let client = activeClients[serverName] else {
            throw MCPError.serverNotConnected(serverName)
        }
        
        let result = try await client.readResource(uri: uri)
        return result
    }
    
    func getPrompts() async throws -> [String: Prompt] {
        var allPrompts: [String: Prompt] = [:]
        
        for (serverName, client) in activeClients {
            let (prompts, _) = try await client.listPrompts()
            
            for prompt in prompts {
                allPrompts["\(serverName).\(prompt.name)"] = prompt
            }
        }
        
        return allPrompts
    }
    
    func getPrompt(serverName: String, name: String, arguments: [String: Value]? = nil) async throws -> (messages: [Prompt.Message], description: String?) {
        guard let client = activeClients[serverName] else {
            throw MCPError.serverNotConnected(serverName)
        }
        
        let result = try await client.getPrompt(
            name: name,
            arguments: arguments ?? [:]
        )
        return (messages: result.messages, description: result.description)
    }
}

enum MCPError: LocalizedError {
    case serverNotConnected(String)
    case toolExecutionFailed(String)
    case invalidArguments
    case invalidConfiguration(String)
    
    var errorDescription: String? {
        switch self {
        case .serverNotConnected(let name):
            return "MCP server '\(name)' is not connected"
        case .toolExecutionFailed(let message):
            return "Tool execution failed: \(message)"
        case .invalidArguments:
            return "Invalid arguments provided"
        case .invalidConfiguration(let message):
            return "Invalid configuration: \(message)"
        }
    }
}