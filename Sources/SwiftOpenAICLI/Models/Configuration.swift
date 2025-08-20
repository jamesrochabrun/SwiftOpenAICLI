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
    let command: String
    let args: [String]?
    let env: [String: String]?  // Claude Code SDK uses 'env' not 'environment'
    let environment: [String: String]?  // Support legacy format
    let enabled: Bool?
    
    private enum CodingKeys: String, CodingKey {
        case name
        case command
        case args
        case env
        case environment
        case enabled
    }
    
    var toMCPServerConfig: MCPServerConfig {
        return MCPServerConfig(
            name: name ?? "",
            command: command,
            args: args ?? [],
            environment: env ?? environment  // Use env if available, fall back to environment
        )
    }
}