import ArgumentParser
import Foundation
import Rainbow

struct MCPConfigCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "mcp",
        abstract: "Manage MCP server configurations",
        subcommands: [Add.self, Remove.self, List.self, Enable.self, Disable.self]
    )
    
    struct Add: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Add a new MCP server configuration"
        )
        
        @Argument(help: "The name of the MCP server")
        var name: String
        
        @Argument(help: "The command to run the MCP server")
        var command: String
        
        @Option(name: .long, help: "Arguments for the command (comma-separated)")
        var args: String?
        
        @Option(name: .long, help: "Environment variables (KEY=VALUE,KEY2=VALUE2)")
        var env: String?
        
        @Flag(name: .long, help: "Enable the server immediately")
        var enable = false
        
        mutating func run() async throws {
            let configManager = ConfigurationManager.shared
            var config = configManager.getConfiguration()
            
            let serverArgs = args?.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)) } ?? []
            
            var environment: [String: String]? = nil
            if let env = env {
                environment = [:]
                for pair in env.split(separator: ",") {
                    let parts = pair.split(separator: "=", maxSplits: 1)
                    if parts.count == 2 {
                        environment?[String(parts[0])] = String(parts[1])
                    }
                }
            }
            
            let serverDef = MCPServerDefinition(
                name: name,
                command: command,
                args: serverArgs.isEmpty ? nil : serverArgs,
                env: environment,  // Use 'env' for Claude Code SDK compatibility
                environment: nil,
                enabled: enable
            )
            
            // Check if server already exists
            if let servers = config.mcpServers?.allServers,
               servers.contains(where: { $0.name == name }) {
                print("❌ MCP server '\(name)' already exists".red)
                throw ExitCode.failure
            }
            
            // Add to configuration (maintain array format for now)
            if config.mcpServers == nil {
                config.mcpServers = .array([])
            }
            
            switch config.mcpServers {
            case .array(var servers):
                servers.append(serverDef)
                config.mcpServers = .array(servers)
            case .object(var dict):
                dict[name] = serverDef
                config.mcpServers = .object(dict)
            case .none:
                config.mcpServers = .array([serverDef])
            }
            
            try configManager.updateConfiguration(config)
            print("✅ Added MCP server '\(name)'".green)
            
            if enable {
                print("   Status: enabled".lightBlack)
            }
        }
    }
    
    struct Remove: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Remove an MCP server configuration"
        )
        
        @Argument(help: "The name of the MCP server to remove")
        var name: String
        
        mutating func run() async throws {
            let configManager = ConfigurationManager.shared
            var config = configManager.getConfiguration()
            
            guard let mcpServers = config.mcpServers else {
                print("❌ MCP server '\(name)' not found".red)
                throw ExitCode.failure
            }
            
            switch mcpServers {
            case .array(var servers):
                guard let index = servers.firstIndex(where: { $0.name == name }) else {
                    print("❌ MCP server '\(name)' not found".red)
                    throw ExitCode.failure
                }
                servers.remove(at: index)
                config.mcpServers = servers.isEmpty ? nil : .array(servers)
            case .object(var dict):
                guard dict.removeValue(forKey: name) != nil else {
                    print("❌ MCP server '\(name)' not found".red)
                    throw ExitCode.failure
                }
                config.mcpServers = dict.isEmpty ? nil : .object(dict)
            }
            
            try configManager.updateConfiguration(config)
            print("✅ Removed MCP server '\(name)'".green)
        }
    }
    
    struct List: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "List all configured MCP servers"
        )
        
        mutating func run() async throws {
            let configManager = ConfigurationManager.shared
            let config = configManager.getConfiguration()
            
            guard let mcpServers = config.mcpServers else {
                print("No MCP servers configured".yellow)
                return
            }
            
            let servers = mcpServers.allServers
            guard !servers.isEmpty else {
                print("No MCP servers configured".yellow)
                return
            }
            
            print("Configured MCP servers:".cyan)
            for server in servers {
                let name = server.name ?? "unnamed"
                let status = (server.enabled ?? true) ? "enabled".green : "disabled".lightBlack
                print("  • \(name): \(status)")
                print("    Command: \(server.command)".lightBlack)
                if let args = server.args, !args.isEmpty {
                    print("    Args: \(args.joined(separator: " "))".lightBlack)
                }
                let env = server.env ?? server.environment
                if let env = env, !env.isEmpty {
                    let envStr = env.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
                    print("    Environment: \(envStr)".lightBlack)
                }
            }
        }
    }
    
    struct Enable: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Enable an MCP server"
        )
        
        @Argument(help: "The name of the MCP server to enable")
        var name: String
        
        mutating func run() async throws {
            let configManager = ConfigurationManager.shared
            var config = configManager.getConfiguration()
            
            guard let mcpServers = config.mcpServers else {
                print("❌ MCP server '\(name)' not found".red)
                throw ExitCode.failure
            }
            
            switch mcpServers {
            case .array(var servers):
                guard let index = servers.firstIndex(where: { $0.name == name }) else {
                    print("❌ MCP server '\(name)' not found".red)
                    throw ExitCode.failure
                }
                var server = servers[index]
                servers[index] = MCPServerDefinition(
                    name: server.name,
                    command: server.command,
                    args: server.args,
                    env: server.env,
                    environment: server.environment,
                    enabled: true
                )
                config.mcpServers = .array(servers)
            case .object(var dict):
                guard var server = dict[name] else {
                    print("❌ MCP server '\(name)' not found".red)
                    throw ExitCode.failure
                }
                dict[name] = MCPServerDefinition(
                    name: server.name ?? name,
                    command: server.command,
                    args: server.args,
                    env: server.env,
                    environment: server.environment,
                    enabled: true
                )
                config.mcpServers = .object(dict)
            }
            
            try configManager.updateConfiguration(config)
            print("✅ Enabled MCP server '\(name)'".green)
        }
    }
    
    struct Disable: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Disable an MCP server"
        )
        
        @Argument(help: "The name of the MCP server to disable")
        var name: String
        
        mutating func run() async throws {
            let configManager = ConfigurationManager.shared
            var config = configManager.getConfiguration()
            
            guard let mcpServers = config.mcpServers else {
                print("❌ MCP server '\(name)' not found".red)
                throw ExitCode.failure
            }
            
            switch mcpServers {
            case .array(var servers):
                guard let index = servers.firstIndex(where: { $0.name == name }) else {
                    print("❌ MCP server '\(name)' not found".red)
                    throw ExitCode.failure
                }
                var server = servers[index]
                servers[index] = MCPServerDefinition(
                    name: server.name,
                    command: server.command,
                    args: server.args,
                    env: server.env,
                    environment: server.environment,
                    enabled: false
                )
                config.mcpServers = .array(servers)
            case .object(var dict):
                guard var server = dict[name] else {
                    print("❌ MCP server '\(name)' not found".red)
                    throw ExitCode.failure
                }
                dict[name] = MCPServerDefinition(
                    name: server.name ?? name,
                    command: server.command,
                    args: server.args,
                    env: server.env,
                    environment: server.environment,
                    enabled: false
                )
                config.mcpServers = .object(dict)
            }
            
            try configManager.updateConfiguration(config)
            print("✅ Disabled MCP server '\(name)'".green)
        }
    }
}