import XCTest
import SwiftOpenAI
@testable import SwiftOpenAICLI

final class LocalToolsConfigTests: XCTestCase {
    
    // MARK: - Basic Configuration Parsing
    
    func testParseValidConfiguration() throws {
        let json = """
        {
            "tools": [
                {
                    "name": "test_tool",
                    "description": "A test tool",
                    "command": "echo {{message}}",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "message": {
                                "type": "string",
                                "description": "Message to echo"
                            }
                        },
                        "required": ["message"]
                    }
                }
            ]
        }
        """
        
        let data = json.data(using: .utf8)!
        let config = try JSONDecoder().decode(LocalToolsConfig.self, from: data)
        
        XCTAssertEqual(config.tools.count, 1)
        XCTAssertEqual(config.tools[0].name, "test_tool")
        XCTAssertEqual(config.tools[0].description, "A test tool")
        XCTAssertEqual(config.tools[0].command, "echo {{message}}")
        XCTAssertNil(config.tools[0].script)
    }
    
    func testParseConfigurationWithScript() throws {
        let json = """
        {
            "tools": [
                {
                    "name": "script_tool",
                    "description": "A script tool",
                    "script": "/usr/local/bin/my-script.sh",
                    "working_directory": "/tmp",
                    "parameters": {
                        "type": "object",
                        "properties": {}
                    }
                }
            ]
        }
        """
        
        let data = json.data(using: .utf8)!
        let config = try JSONDecoder().decode(LocalToolsConfig.self, from: data)
        
        XCTAssertEqual(config.tools[0].script, "/usr/local/bin/my-script.sh")
        XCTAssertEqual(config.tools[0].workingDirectory, "/tmp")
        XCTAssertNil(config.tools[0].command)
    }
    
    // MARK: - Parameter Type Tests
    
    func testSimpleParameterTypes() throws {
        let json = """
        {
            "tools": [
                {
                    "name": "test",
                    "description": "Test",
                    "command": "test",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "string_param": {
                                "type": "string",
                                "description": "A string parameter"
                            },
                            "number_param": {
                                "type": "number",
                                "description": "A number parameter"
                            },
                            "boolean_param": {
                                "type": "boolean",
                                "description": "A boolean parameter"
                            }
                        }
                    }
                }
            ]
        }
        """
        
        let data = json.data(using: .utf8)!
        let config = try JSONDecoder().decode(LocalToolsConfig.self, from: data)
        let schema = config.tools[0].parameters.toJSONSchema()
        
        XCTAssertEqual(schema.type, .object)
        XCTAssertEqual(schema.properties?.count, 3)
        XCTAssertEqual(schema.properties?["string_param"]?.type, .string)
        XCTAssertEqual(schema.properties?["number_param"]?.type, .number)
        XCTAssertEqual(schema.properties?["boolean_param"]?.type, .boolean)
    }
    
    func testArrayParameterType() throws {
        let json = """
        {
            "tools": [
                {
                    "name": "test",
                    "description": "Test",
                    "command": "test",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "files": {
                                "type": "array",
                                "description": "List of files",
                                "items": {
                                    "type": "string",
                                    "description": "File path"
                                }
                            }
                        }
                    }
                }
            ]
        }
        """
        
        let data = json.data(using: .utf8)!
        let config = try JSONDecoder().decode(LocalToolsConfig.self, from: data)
        let schema = config.tools[0].parameters.toJSONSchema()
        
        XCTAssertEqual(schema.properties?["files"]?.type, .array)
        XCTAssertNotNil(schema.properties?["files"]?.items)
        XCTAssertEqual(schema.properties?["files"]?.items?.type, .string)
    }
    
    func testNestedArrayTypes() throws {
        let json = """
        {
            "tools": [
                {
                    "name": "test",
                    "description": "Test",
                    "command": "test",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "matrix": {
                                "type": "array",
                                "description": "2D array",
                                "items": {
                                    "type": "array",
                                    "items": {
                                        "type": "number"
                                    }
                                }
                            }
                        }
                    }
                }
            ]
        }
        """
        
        let data = json.data(using: .utf8)!
        let config = try JSONDecoder().decode(LocalToolsConfig.self, from: data)
        let schema = config.tools[0].parameters.toJSONSchema()
        
        XCTAssertEqual(schema.properties?["matrix"]?.type, .array)
        XCTAssertEqual(schema.properties?["matrix"]?.items?.type, .array)
        XCTAssertEqual(schema.properties?["matrix"]?.items?.items?.type, .number)
    }
    
    // MARK: - Required Fields Tests
    
    func testRequiredFieldsHandling() throws {
        let json = """
        {
            "tools": [
                {
                    "name": "test",
                    "description": "Test",
                    "command": "test",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "required_field": {
                                "type": "string"
                            },
                            "optional_field": {
                                "type": "string"
                            }
                        },
                        "required": ["required_field"]
                    }
                }
            ]
        }
        """
        
        let data = json.data(using: .utf8)!
        let config = try JSONDecoder().decode(LocalToolsConfig.self, from: data)
        let schema = config.tools[0].parameters.toJSONSchema()
        
        // For OpenAI strict mode, all properties should be in required array
        XCTAssertEqual(schema.required?.count, 2)
        XCTAssertTrue(schema.required?.contains("required_field") ?? false)
        XCTAssertTrue(schema.required?.contains("optional_field") ?? false)
    }
    
    func testEmptyRequiredFields() throws {
        let json = """
        {
            "tools": [
                {
                    "name": "test",
                    "description": "Test",
                    "command": "test",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "field1": {"type": "string"},
                            "field2": {"type": "number"}
                        }
                    }
                }
            ]
        }
        """
        
        let data = json.data(using: .utf8)!
        let config = try JSONDecoder().decode(LocalToolsConfig.self, from: data)
        let schema = config.tools[0].parameters.toJSONSchema()
        
        // All fields should be required for OpenAI strict mode
        XCTAssertEqual(schema.required?.count, 2)
    }
    
    // MARK: - LocalToolsLoader Tests
    
    func testLoadToolsFromFile() throws {
        let json = """
        {
            "tools": [
                {
                    "name": "tool1",
                    "description": "Tool 1",
                    "command": "echo 1",
                    "parameters": {"type": "object", "properties": {}}
                },
                {
                    "name": "tool2",
                    "description": "Tool 2",
                    "command": "echo 2",
                    "parameters": {"type": "object", "properties": {}}
                }
            ]
        }
        """
        
        let tempDir = FileManager.default.temporaryDirectory
        let configPath = tempDir.appendingPathComponent("test-config.json").path
        
        try json.write(toFile: configPath, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: configPath) }
        
        let tools = try LocalToolsLoader.loadTools(from: configPath)
        
        XCTAssertEqual(tools.count, 2)
        XCTAssertEqual(tools[0].name, "local__tool1")
        XCTAssertEqual(tools[1].name, "local__tool2")
    }
    
    func testLoadToolsFromNonexistentFile() {
        let path = "/nonexistent/path/config.json"
        
        XCTAssertThrowsError(try LocalToolsLoader.loadTools(from: path)) { error in
            XCTAssertTrue(error is LocalToolsError)
            if case LocalToolsError.fileNotFound(let errorPath) = error {
                XCTAssertEqual(errorPath, path)
            }
        }
    }
    
    // MARK: - Edge Cases
    
    func testEmptyToolsList() throws {
        let json = """
        {
            "tools": []
        }
        """
        
        let data = json.data(using: .utf8)!
        let config = try JSONDecoder().decode(LocalToolsConfig.self, from: data)
        
        XCTAssertEqual(config.tools.count, 0)
    }
    
    func testToolWithoutCommandOrScript() throws {
        let json = """
        {
            "tools": [
                {
                    "name": "broken",
                    "description": "Broken tool",
                    "parameters": {"type": "object", "properties": {}}
                }
            ]
        }
        """
        
        let data = json.data(using: .utf8)!
        let config = try JSONDecoder().decode(LocalToolsConfig.self, from: data)
        
        XCTAssertNil(config.tools[0].command)
        XCTAssertNil(config.tools[0].script)
    }
    
    func testSpecialCharactersInToolName() throws {
        let json = """
        {
            "tools": [
                {
                    "name": "my-tool_v2.0",
                    "description": "Tool with special chars",
                    "command": "echo",
                    "parameters": {"type": "object", "properties": {}}
                }
            ]
        }
        """
        
        let data = json.data(using: .utf8)!
        let config = try JSONDecoder().decode(LocalToolsConfig.self, from: data)
        
        XCTAssertEqual(config.tools[0].name, "my-tool_v2.0")
        
        let tools = config.tools.map { definition in
            LocalTool(
                name: definition.name,
                description: definition.description,
                command: definition.command,
                script: definition.script,
                parameters: definition.parameters.toJSONSchema(),
                workingDirectory: definition.workingDirectory
            )
        }
        
        XCTAssertEqual(tools[0].name, "local__my-tool_v2.0")
    }
    
    // MARK: - JSONSchemaType Extension Tests
    
    func testJSONSchemaTypeFromString() {
        XCTAssertEqual(JSONSchemaType.fromString("string"), .string)
        XCTAssertEqual(JSONSchemaType.fromString("STRING"), .string)
        XCTAssertEqual(JSONSchemaType.fromString("number"), .number)
        XCTAssertEqual(JSONSchemaType.fromString("integer"), .integer)
        XCTAssertEqual(JSONSchemaType.fromString("boolean"), .boolean)
        XCTAssertEqual(JSONSchemaType.fromString("array"), .array)
        XCTAssertEqual(JSONSchemaType.fromString("object"), .object)
        XCTAssertEqual(JSONSchemaType.fromString("null"), .null)
        XCTAssertEqual(JSONSchemaType.fromString("unknown"), .string) // Default
    }
}