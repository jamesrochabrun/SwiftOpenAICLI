import ArgumentParser
import Foundation
import Rainbow

public struct MCPConfigCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "mcp",
        abstract: "Manage MCP server configurations",
        subcommands: [Add.self, AddHTTP.self, Remove.self, List.self, Enable.self, Disable.self]
    )

    public init() {}

    
    struct Add: AsyncParsableCommand {
        public static let configuration = CommandConfiguration(
            abstract: "Add a new MCP server configuration"
        )

    public init() {}

        
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
        
        public mutating func run() async throws {
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
    
    struct AddHTTP: AsyncParsableCommand {
        public static let configuration = CommandConfiguration(
            commandName: "add-http",
            abstract: "Add a new HTTP-based MCP server configuration (e.g., Zapier)"
        )

    public init() {}

        
        @Argument(help: "The name of the MCP server")
        var name: String
        
        @Argument(help: "The HTTP endpoint URL for the MCP server")
        var url: String
        
        @Option(name: .long, help: "Environment variables (KEY=VALUE,KEY2=VALUE2)")
        var env: String?
        
        @Flag(name: .long, help: "Enable the server immediately")
        var enable = false
        
        public mutating func run() async throws {
            let configManager = ConfigurationManager.shared
            var config = configManager.getConfiguration()
            
            // Validate URL
            guard URL(string: url) != nil else {
                print("❌ Invalid URL: \(url)".red)
                throw ExitCode.failure
            }
            
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
                transport: "http",
                command: nil,
                url: url,
                args: nil,
                env: environment,
                environment: nil,
                enabled: enable
            )
            
            // Check if server already exists
            if let servers = config.mcpServers?.allServers,
               servers.contains(where: { $0.name == name }) {
                print("❌ MCP server '\(name)' already exists".red)
                throw ExitCode.failure
            }
            
            // Add to configuration
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
            print("✅ Added HTTP MCP server '\(name)'".green)
            print("   URL: \(url)".lightBlack)
            
            if enable {
                print("   Status: enabled".lightBlack)
            }
            
            // Security warning for HTTP servers
            print("\n⚠️  Security Notice:".yellow)
            print("   This URL contains authentication tokens.".yellow)
            print("   Treat it like a password and do not share it.".yellow)
        }
    }
    
    struct Remove: AsyncParsableCommand {
        public static let configuration = CommandConfiguration(
            abstract: "Remove an MCP server configuration"
        )

    public init() {}

        
        @Argument(help: "The name of the MCP server to remove")
        var name: String
        
        public mutating func run() async throws {
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
        public static let configuration = CommandConfiguration(
            abstract: "List all configured MCP servers"
        )

    public init() {}

        
        public mutating func run() async throws {
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
                let transport = server.transport ?? "stdio"
                print("  • \(name): \(status) [\(transport)]")
                
                if let command = server.command {
                    print("    Command: \(command)".lightBlack)
                    if let args = server.args, !args.isEmpty {
                        print("    Args: \(args.joined(separator: " "))".lightBlack)
                    }
                } else if let url = server.url {
                    // Mask the URL to hide sensitive tokens
                    let maskedUrl = maskSensitiveUrl(url)
                    print("    URL: \(maskedUrl)".lightBlack)
                }
                
                let env = server.env ?? server.environment
                if let env = env, !env.isEmpty {
                    let envStr = env.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
                    print("    Environment: \(envStr)".lightBlack)
                }
            }
        }
        
        private func maskSensitiveUrl(_ url: String) -> String {
            // Parse URL and mask the path/token portion
            if let urlComponents = URLComponents(string: url) {
                var masked = "\(urlComponents.scheme ?? "https")://\(urlComponents.host ?? "")"
                if let port = urlComponents.port {
                    masked += ":\(port)"
                }
                if let path = urlComponents.path.split(separator: "/").first {
                    masked += "/\(path)/..."
                }
                return masked + " (use 'config get' to see full URL)"
            }
            return url
        }
    }
    
    struct Enable: AsyncParsableCommand {
        public static let configuration = CommandConfiguration(
            abstract: "Enable an MCP server"
        )

    public init() {}

        
        @Argument(help: "The name of the MCP server to enable")
        var name: String
        
        public mutating func run() async throws {
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
                let server = servers[index]
                servers[index] = MCPServerDefinition(
                    name: server.name,
                    transport: server.transport,
                    command: server.command,
                    url: server.url,
                    args: server.args,
                    env: server.env,
                    environment: server.environment,
                    enabled: true
                )
                config.mcpServers = .array(servers)
            case .object(var dict):
                guard let server = dict[name] else {
                    print("❌ MCP server '\(name)' not found".red)
                    throw ExitCode.failure
                }
                dict[name] = MCPServerDefinition(
                    name: server.name ?? name,
                    transport: server.transport,
                    command: server.command,
                    url: server.url,
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
        public static let configuration = CommandConfiguration(
            abstract: "Disable an MCP server"
        )

    public init() {}

        
        @Argument(help: "The name of the MCP server to disable")
        var name: String
        
        public mutating func run() async throws {
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
                let server = servers[index]
                servers[index] = MCPServerDefinition(
                    name: server.name,
                    transport: server.transport,
                    command: server.command,
                    url: server.url,
                    args: server.args,
                    env: server.env,
                    environment: server.environment,
                    enabled: false
                )
                config.mcpServers = .array(servers)
            case .object(var dict):
                guard let server = dict[name] else {
                    print("❌ MCP server '\(name)' not found".red)
                    throw ExitCode.failure
                }
                dict[name] = MCPServerDefinition(
                    name: server.name ?? name,
                    transport: server.transport,
                    command: server.command,
                    url: server.url,
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
