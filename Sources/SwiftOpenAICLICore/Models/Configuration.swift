import Foundation

public struct Configuration: Codable {
    public var apiKey: String?
    public var defaultModel: String = "gpt-4o"
    public var outputFormat: OutputFormat = .plain
    public var temperature: Double = 1.0
    public var maxTokens: Int?
    public var maxToolCalls: Int?  // Maximum tool calls allowed per session
    
    // Provider configuration
    public var provider: String?
    public var baseURL: String?
    public var debugEnabled: Bool?
    
    // Loading indicator configuration
    public var animatedLoading: Bool?  // Enable animated loading indicators
    
    // MCP server configuration (supports both array and object formats)
    public var mcpServers: MCPServersConfig?
    
    static let defaultConfigPath = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent(".swiftopenai")
        .appendingPathComponent("config.json")
}

// Supports both array format (legacy) and object format (Claude Code SDK)
public enum MCPServersConfig: Codable {
    case array([MCPServerDefinition])
    case object([String: MCPServerDefinition])
    
    public init(from decoder: Decoder) throws {
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
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .array(let servers):
            try container.encode(servers)
        case .object(let servers):
            try container.encode(servers)
        }
    }
    
    public var allServers: [MCPServerDefinition] {
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

public struct MCPServerDefinition: Codable {
    public var name: String?  // Optional because in object format, name comes from the key
    public let transport: String?  // "stdio" (default) or "http"
    public let command: String?  // Required for stdio transport
    public let url: String?  // Required for http transport
    public let args: [String]?
    public let env: [String: String]?  // Claude Code SDK uses 'env' not 'environment'
    public let environment: [String: String]?  // Support legacy format
    public let enabled: Bool?
    
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
    public init(from decoder: Decoder) throws {
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
    
    public init(name: String? = nil, 
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
    
    public var toMCPServerConfig: MCPServerConfig {
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