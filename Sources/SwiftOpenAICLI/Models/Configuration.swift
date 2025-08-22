import Foundation

struct Configuration: Codable {
    var apiKey: String?
    var defaultModel: String = "gpt-4o"
    var outputFormat: OutputFormat = .plain
    var temperature: Double = 1.0
    var maxTokens: Int?
    
    // Provider configuration
    var provider: String?
    var baseURL: String?
    var debugEnabled: Bool?
    
    // MCP server configuration (supports both array and object formats)
    var mcpServers: MCPServersConfig?
    
    static let defaultConfigPath = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent(".swiftopenai")
        .appendingPathComponent("config.json")
}

// Supports both array format (legacy) and object format (Claude Code SDK)
enum MCPServersConfig: Codable {
    case array([MCPServerDefinition])
    case object([String: MCPServerDefinition])
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        // Try to decode as object first (Claude Code SDK format)
        if let dict = try? container.decode([String: MCPServerDefinition].self) {
            self = .object(dict)
        }
        // Fall back to array format (legacy)
        else if let array = try? container.decode([MCPServerDefinition].self) {
            self = .array(array)
        } else {
            throw DecodingError.typeMismatch(
                MCPServersConfig.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Expected either array or object format for mcpServers"
                )
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .array(let servers):
            try container.encode(servers)
        case .object(let servers):
            try container.encode(servers)
        }
    }
    
    var allServers: [MCPServerDefinition] {
        switch self {
        case .array(let servers):
            return servers
        case .object(let dict):
            return dict.map { key, value in
                var server = value
                // Ensure the name matches the key
                if server.name == nil {
                    server.name = key
                }
                return server
            }
        }
    }
}

struct MCPServerDefinition: Codable {
    var name: String?  // Optional because in object format, name comes from the key
    let transport: String?  // "stdio" (default) or "http"
    let command: String?  // Required for stdio transport
    let url: String?  // Required for http transport
    let args: [String]?
    let env: [String: String]?  // Claude Code SDK uses 'env' not 'environment'
    let environment: [String: String]?  // Support legacy format
    let enabled: Bool?
    
    private enum CodingKeys: String, CodingKey {
        case name
        case transport
        case command
        case url
        case args
        case env
        case environment
        case enabled
    }
    
    // Custom init to maintain backward compatibility
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        transport = try container.decodeIfPresent(String.self, forKey: .transport)
        command = try container.decodeIfPresent(String.self, forKey: .command)
        url = try container.decodeIfPresent(String.self, forKey: .url)
        args = try container.decodeIfPresent([String].self, forKey: .args)
        env = try container.decodeIfPresent([String: String].self, forKey: .env)
        environment = try container.decodeIfPresent([String: String].self, forKey: .environment)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled)
        
        // Validate: must have either command (stdio) or url (http)
        if command == nil && url == nil {
            // For backward compatibility, if transport is not specified and command exists, assume stdio
            throw DecodingError.dataCorruptedError(
                forKey: .command,
                in: container,
                debugDescription: "MCP server must have either 'command' for stdio transport or 'url' for HTTP transport"
            )
        }
    }
    
    init(name: String? = nil, 
         transport: String? = nil,
         command: String? = nil,
         url: String? = nil,
         args: [String]? = nil,
         env: [String: String]? = nil,
         environment: [String: String]? = nil,
         enabled: Bool? = nil) {
        self.name = name
        self.transport = transport
        self.command = command
        self.url = url
        self.args = args
        self.env = env
        self.environment = environment
        self.enabled = enabled
    }
    
    var toMCPServerConfig: MCPServerConfig {
        return MCPServerConfig(
            name: name ?? "",
            transport: transport ?? (url != nil ? "http" : "stdio"),
            command: command,
            url: url,
            args: args ?? [],
            environment: env ?? environment  // Use env if available, fall back to environment
        )
    }
}