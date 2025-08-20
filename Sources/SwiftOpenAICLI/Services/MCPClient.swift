import Foundation
import MCP
import Rainbow

struct MCPServerConfig {
    let name: String
    let command: String
    let args: [String]
    let environment: [String: String]?
}

actor MCPClient {
    private var activeClients: [String: Client] = [:]
    private let verbose: Bool
    
    init(verbose: Bool = false) {
        self.verbose = verbose
    }
    
    func connectToServer(_ config: MCPServerConfig) async throws {
        if verbose {
            print("🔗 Connecting to MCP server: \(config.name)".lightBlack)
        }
        
        let client = Client(
            name: "SwiftOpenAICLI",
            version: "1.0.0",
            configuration: .default
        )
        
        // Create process transport to launch the server
        let transport = ProcessTransport(
            command: config.command,
            args: config.args,
            environment: config.environment,
            verbose: verbose
        )
        
        let initResult = try await client.connect(transport: transport)
        
        if verbose {
            print("✅ Connected to: \(initResult.serverInfo.name) v\(initResult.serverInfo.version)".green)
            let capabilities = initResult.capabilities
            if capabilities.tools != nil {
                print("   Tools: supported".lightBlack)
            }
            if capabilities.resources != nil {
                print("   Resources: supported".lightBlack)
            }
            if capabilities.prompts != nil {
                print("   Prompts: supported".lightBlack)
            }
        }
        
        activeClients[config.name] = client
    }
    
    func disconnectFromServer(_ name: String) async {
        activeClients.removeValue(forKey: name)
        
        if verbose {
            print("🔌 Disconnected from MCP server: \(name)".lightBlack)
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
    
    var errorDescription: String? {
        switch self {
        case .serverNotConnected(let name):
            return "MCP server '\(name)' is not connected"
        case .toolExecutionFailed(let message):
            return "Tool execution failed: \(message)"
        case .invalidArguments:
            return "Invalid arguments provided"
        }
    }
}