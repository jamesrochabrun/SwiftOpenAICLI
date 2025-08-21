import Foundation
import SwiftOpenAI
import MCP

class MCPToolAdapter: CLITool {
    let serverName: String
    let mcpTool: MCP.Tool
    private weak var mcpClient: MCPClient?
    
    init(serverName: String, tool: MCP.Tool, mcpClient: MCPClient) {
        self.serverName = serverName
        self.mcpTool = tool
        self.mcpClient = mcpClient
    }
    
    var name: String {
        // Claude Code SDK format: mcp__serverName__toolName
        // OpenAI API requires tool names to match pattern ^[a-zA-Z0-9_-]+$
        // Replace dots with underscores
        let sanitizedToolName = mcpTool.name.replacingOccurrences(of: ".", with: "_")
        return "mcp__\(serverName)__\(sanitizedToolName)"
    }
    
    var description: String {
        return mcpTool.description
    }
    
    var isStrictModeCompatible: Bool {
        // MCP tools from external sources may not be compatible with OpenAI's strict mode
        return false
    }
    
    var parameters: JSONSchema {
        // Convert Value to dictionary if it's an object
        if case .object(let schemaDict) = mcpTool.inputSchema {
            return convertMCPSchemaToJSONSchema(schemaDict)
        } else {
            return JSONSchema(
                type: .object,
                properties: [:],
                required: []
            )
        }
    }
    
    func execute(arguments: String) async throws -> String {
        guard let mcpClient = mcpClient else {
            throw MCPError.serverNotConnected(serverName)
        }
        
        // Convert JSON string to MCP Value type
        let mcpArgs: [String: Value]
        if arguments.isEmpty {
            mcpArgs = [:]
        } else {
            guard let data = arguments.data(using: .utf8) else {
                throw MCPError.invalidArguments
            }
            
            let json = try JSONSerialization.jsonObject(with: data)
            // Pass the tool's input schema to help with type conversion
            mcpArgs = try convertToMCPValues(json, schema: mcpTool.inputSchema)
        }
        
        let result = try await mcpClient.executeTool(
            serverName: serverName,
            toolName: mcpTool.name,
            arguments: mcpArgs
        )
        
        // Convert result content to string
        if !result.content.isEmpty {
            var outputs: [String] = []
            
            for content in result.content {
                switch content {
                case .text(let text):
                    outputs.append(text)
                case .image(let data, _, _):
                    outputs.append("[Image data: \(data.count) bytes]")
                case .resource(let uri, _, _):
                    outputs.append("[Resource: \(uri)]")
                case .audio(let data, _):
                    outputs.append("[Audio data: \(data.count) bytes]")
                }
            }
            
            return outputs.joined(separator: "\n")
        }
        
        return result.isError == true ? "Error: Tool execution failed" : "Success"
    }
    
    private func convertToMCPValues(_ json: Any, schema: Value) throws -> [String: Value] {
        guard let dict = json as? [String: Any] else {
            throw MCPError.invalidArguments
        }
        
        // Extract property schemas if available
        var propertySchemas: [String: Value] = [:]
        if case .object(let schemaDict) = schema,
           let properties = schemaDict["properties"],
           case .object(let props) = properties {
            propertySchemas = props
        }
        
        var result: [String: Value] = [:]
        for (key, value) in dict {
            // Check if we have schema information for this property
            if let propSchema = propertySchemas[key],
               case .object(let schemaDict) = propSchema,
               let typeValue = schemaDict["type"],
               case .string(let typeStr) = typeValue {
                // Convert based on expected type from schema
                result[key] = convertToValueWithType(value, expectedType: typeStr)
            } else {
                // Fall back to automatic type detection
                result[key] = convertToValue(value)
            }
        }
        return result
    }
    
    private func convertToValueWithType(_ value: Any, expectedType: String) -> Value {
        switch expectedType {
        case "boolean":
            // Handle OpenAI sending booleans as numbers
            if let num = value as? Int {
                return .bool(num != 0)
            } else if let num = value as? Double {
                return .bool(num != 0)
            } else if let bool = value as? Bool {
                return .bool(bool)
            }
            // Try to parse string as boolean
            if let str = value as? String {
                return .bool(str.lowercased() == "true" || str == "1")
            }
            return .bool(false)
        case "string":
            return .string(String(describing: value))
        case "integer":
            if let num = value as? Int {
                return .int(num)
            } else if let num = value as? Double {
                return .int(Int(num))
            }
            return .int(0)
        case "number":
            if let num = value as? Double {
                return .double(num)
            } else if let num = value as? Int {
                return .double(Double(num))
            }
            return .double(0)
        case "array":
            if let arr = value as? [Any] {
                return .array(arr.map(convertToValue))
            }
            return .array([])
        case "object":
            if let dict = value as? [String: Any] {
                var obj: [String: Value] = [:]
                for (k, v) in dict {
                    obj[k] = convertToValue(v)
                }
                return .object(obj)
            }
            return .object([:])
        default:
            return convertToValue(value)
        }
    }
    
    private func convertToValue(_ value: Any) -> Value {
        switch value {
        case let str as String:
            return .string(str)
        case let bool as Bool:
            // Check for Bool first, before checking for Int
            return .bool(bool)
        case let num as Int:
            // OpenAI sometimes sends booleans as 0/1
            // Check if this might be a boolean based on the value
            if num == 0 || num == 1 {
                // This could be a boolean, but we'll keep it as int
                // unless we have more context
                return .int(num)
            }
            return .int(num)
        case let num as Double:
            return .double(num)
        case let arr as [Any]:
            return .array(arr.map(convertToValue))
        case let dict as [String: Any]:
            var obj: [String: Value] = [:]
            for (k, v) in dict {
                obj[k] = convertToValue(v)
            }
            return .object(obj)
        case is NSNull:
            return .null
        default:
            return .string(String(describing: value))
        }
    }
    
    private func convertMCPSchemaToJSONSchema(_ schema: [String: Value]) -> JSONSchema {
        // Extract type from schema
        let typeValue = schema["type"] ?? .string("object")
        let type = extractString(from: typeValue) ?? "object"
        
        // Extract properties if present
        var jsonProperties: [String: JSONSchema] = [:]
        if let propertiesValue = schema["properties"],
           case .object(let props) = propertiesValue {
            for (key, propValue) in props {
                if case .object(let propDict) = propValue {
                    jsonProperties[key] = convertPropertyToJSONSchema(propDict)
                }
            }
        }
        
        // Extract required fields
        var required: [String] = []
        if let requiredValue = schema["required"],
           case .array(let reqArray) = requiredValue {
            required = reqArray.compactMap { extractString(from: $0) }
        }
        
        // OpenAI's strict mode requires all properties to be in the required array
        // Add any missing properties to the required array
        for key in jsonProperties.keys {
            if !required.contains(key) {
                required.append(key)
            }
        }
        
        return JSONSchema(
            type: schemaTypeFromString(type),
            properties: jsonProperties,
            required: required
        )
    }
    
    private func convertPropertyToJSONSchema(_ property: [String: Value]) -> JSONSchema {
        let type = extractString(from: property["type"] ?? .string("string")) ?? "string"
        let description = extractString(from: property["description"] ?? .null)
        
        // If it's an array type, we need to provide items schema
        if type == "array" {
            var items: JSONSchema? = nil
            if let itemsValue = property["items"],
               case .object(let itemsDict) = itemsValue {
                items = convertPropertyToJSONSchema(itemsDict)
            } else {
                // Default items schema if not provided
                items = JSONSchema(type: .string)
            }
            
            return JSONSchema(
                type: .array,
                description: description,
                items: items
            )
        }
        
        return JSONSchema(
            type: schemaTypeFromString(type),
            description: description
        )
    }
    
    private func extractString(from value: Value) -> String? {
        if case .string(let str) = value {
            return str
        }
        return nil
    }
    
    private func schemaTypeFromString(_ type: String) -> JSONSchemaType {
        switch type {
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