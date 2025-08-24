import Foundation
import SwiftOpenAI

struct LocalToolsConfig: Codable {
    let tools: [LocalToolDefinition]
}

struct LocalToolDefinition: Codable {
    let name: String
    let description: String
    let command: String?
    let script: String?
    let workingDirectory: String?
    let parameters: LocalToolParameters
    
    enum CodingKeys: String, CodingKey {
        case name
        case description
        case command
        case script
        case workingDirectory = "working_directory"
        case parameters
    }
}

struct LocalToolParameters: Codable {
    let type: String
    let properties: [String: LocalToolProperty]?
    let required: [String]?
    
    func toJSONSchema() -> JSONSchema {
        var jsonProperties: [String: JSONSchema] = [:]
        
        if let properties = properties {
            for (key, prop) in properties {
                jsonProperties[key] = prop.toJSONSchema()
            }
        }
        
        // OpenAI requires all properties to be in the required array for strict mode
        var requiredFields = required ?? []
        for key in jsonProperties.keys {
            if !requiredFields.contains(key) {
                requiredFields.append(key)
            }
        }
        
        return JSONSchema(
            type: .object,
            properties: jsonProperties,
            required: requiredFields
        )
    }
}

indirect enum LocalToolProperty: Codable {
    case simple(type: String, description: String?, enumValues: [String]?, defaultValue: String?)
    case array(description: String?, items: LocalToolProperty)
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        let description = try container.decodeIfPresent(String.self, forKey: .description)
        
        if type == "array" {
            if let items = try container.decodeIfPresent(LocalToolProperty.self, forKey: .items) {
                self = .array(description: description, items: items)
            } else {
                // Default to string array if items not specified
                self = .array(description: description, items: .simple(type: "string", description: nil, enumValues: nil, defaultValue: nil))
            }
        } else {
            let enumValues = try container.decodeIfPresent([String].self, forKey: .enumValues)
            let defaultValue = try container.decodeIfPresent(String.self, forKey: .defaultValue)
            self = .simple(type: type, description: description, enumValues: enumValues, defaultValue: defaultValue)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .simple(let type, let description, let enumValues, let defaultValue):
            try container.encode(type, forKey: .type)
            try container.encodeIfPresent(description, forKey: .description)
            try container.encodeIfPresent(enumValues, forKey: .enumValues)
            try container.encodeIfPresent(defaultValue, forKey: .defaultValue)
            
        case .array(let description, let items):
            try container.encode("array", forKey: .type)
            try container.encodeIfPresent(description, forKey: .description)
            try container.encode(items, forKey: .items)
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case type
        case description
        case items
        case enumValues = "enum"
        case defaultValue = "default"
    }
    
    func toJSONSchema() -> JSONSchema {
        switch self {
        case .simple(let type, let description, _, _):
            return JSONSchema(
                type: JSONSchemaType.fromString(type),
                description: description
            )
        case .array(let description, let items):
            return JSONSchema(
                type: .array,
                description: description,
                items: items.toJSONSchema()
            )
        }
    }
}

extension JSONSchemaType {
    static func fromString(_ type: String) -> JSONSchemaType {
        switch type.lowercased() {
        case "string":
            return .string
        case "number":
            return .number
        case "integer":
            return .integer
        case "boolean":
            return .boolean
        case "array":
            return .array
        case "object":
            return .object
        case "null":
            return .null
        default:
            return .string
        }
    }
}

class LocalToolsLoader {
    static func loadTools(from path: String) throws -> [LocalTool] {
        let url = URL(fileURLWithPath: path)
        
        guard FileManager.default.fileExists(atPath: path) else {
            throw LocalToolsError.fileNotFound(path)
        }
        
        let data = try Data(contentsOf: url)
        let config = try JSONDecoder().decode(LocalToolsConfig.self, from: data)
        
        return config.tools.map { definition in
            LocalTool(
                name: definition.name,
                description: definition.description,
                command: definition.command,
                script: definition.script,
                parameters: definition.parameters.toJSONSchema(),
                workingDirectory: definition.workingDirectory
            )
        }
    }
    
    static func loadTools(from url: URL) throws -> [LocalTool] {
        return try loadTools(from: url.path)
    }
}

enum LocalToolsError: LocalizedError {
    case fileNotFound(String)
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "Local tools configuration file not found: \(path)"
        }
    }
}