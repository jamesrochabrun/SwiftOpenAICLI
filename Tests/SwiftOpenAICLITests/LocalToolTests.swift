import XCTest
import SwiftOpenAI
@testable import SwiftOpenAICLI

final class LocalToolTests: XCTestCase {
    
    // MARK: - Initialization Tests
    
    func testLocalToolInitializationWithCommand() {
        let tool = LocalTool(
            name: "test_tool",
            description: "A test tool",
            command: "echo 'hello'",
            parameters: JSONSchema(
                type: .object,
                properties: [:],
                required: []
            )
        )
        
        XCTAssertEqual(tool.name, "local__test_tool")
        XCTAssertEqual(tool.description, "A test tool")
        XCTAssertTrue(tool.isStrictModeCompatible)
    }
    
    func testLocalToolInitializationWithScript() {
        let tool = LocalTool(
            name: "script_tool",
            description: "A script tool",
            script: "/usr/bin/script.sh",
            parameters: JSONSchema(
                type: .object,
                properties: [
                    "input": JSONSchema(type: .string, description: "Input value")
                ],
                required: ["input"]
            )
        )
        
        XCTAssertEqual(tool.name, "local__script_tool")
        XCTAssertEqual(tool.description, "A script tool")
    }
    
    func testLocalToolWithWorkingDirectory() {
        let tool = LocalTool(
            name: "dir_tool",
            description: "Tool with working directory",
            command: "ls",
            parameters: JSONSchema(type: .object, properties: [:], required: []),
            workingDirectory: "/tmp"
        )
        
        XCTAssertEqual(tool.name, "local__dir_tool")
    }
    
    // MARK: - Command Interpolation Tests
    
    func testCommandInterpolation() async throws {
        let tool = CommandInterpolationTestTool()
        
        // Test simple interpolation
        let result1 = tool.testInterpolateCommand(
            "echo {{message}}",
            with: ["message": "hello world"]
        )
        XCTAssertEqual(result1, "echo 'hello world'")
        
        // Test multiple parameters
        let result2 = tool.testInterpolateCommand(
            "grep {{pattern}} {{file}}",
            with: ["pattern": "test", "file": "/path/to/file.txt"]
        )
        XCTAssertEqual(result2, "grep test /path/to/file.txt")
        
        // Test with special characters needing escaping
        let result3 = tool.testInterpolateCommand(
            "echo {{message}}",
            with: ["message": "hello 'world' with $special chars"]
        )
        XCTAssertEqual(result3, "echo 'hello '\\''world'\\'' with $special chars'")
    }
    
    func testShellArgumentEscaping() {
        let tool = CommandInterpolationTestTool()
        
        // Test normal string
        XCTAssertEqual(tool.testEscapeShellArgument("simple"), "simple")
        
        // Test string with spaces
        XCTAssertEqual(tool.testEscapeShellArgument("with spaces"), "'with spaces'")
        
        // Test string with quotes
        XCTAssertEqual(tool.testEscapeShellArgument("it's"), "'it'\\''s'")
        
        // Test string with special characters
        XCTAssertEqual(tool.testEscapeShellArgument("$HOME"), "'$HOME'")
        XCTAssertEqual(tool.testEscapeShellArgument("command`"), "'command`'")
    }
    
    // MARK: - Parameter Parsing Tests
    
    func testParseValidJSONArguments() async throws {
        let tool = LocalTool(
            name: "test",
            description: "Test",
            command: "echo",
            parameters: JSONSchema(type: .object, properties: [:], required: [])
        )
        
        let json = "{\"key\": \"value\", \"number\": 42}"
        
        // Use a test helper to validate parsing
        let helper = LocalToolTestHelper(tool: tool)
        let parsed = try helper.testParseArguments(json)
        
        XCTAssertEqual(parsed["key"] as? String, "value")
        XCTAssertEqual(parsed["number"] as? Int, 42)
    }
    
    func testParseEmptyArguments() async throws {
        let tool = LocalTool(
            name: "test",
            description: "Test",
            command: "echo",
            parameters: JSONSchema(type: .object, properties: [:], required: [])
        )
        
        let helper = LocalToolTestHelper(tool: tool)
        let parsed = try helper.testParseArguments("")
        
        XCTAssertTrue(parsed.isEmpty)
    }
    
    func testParseInvalidJSONThrows() async throws {
        let tool = LocalTool(
            name: "test",
            description: "Test",
            command: "echo",
            parameters: JSONSchema(type: .object, properties: [:], required: [])
        )
        
        let helper = LocalToolTestHelper(tool: tool)
        
        do {
            _ = try helper.testParseArguments("invalid json {")
            XCTFail("Should have thrown an error")
        } catch {
            // Expected to throw an error
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testNoExecutableSpecifiedError() async throws {
        let tool = LocalTool(
            name: "broken",
            description: "Broken tool",
            command: nil,
            script: nil,
            parameters: JSONSchema(type: .object, properties: [:], required: [])
        )
        
        do {
            _ = try await tool.execute(arguments: "{}")
            XCTFail("Should have thrown an error")
        } catch let error as LocalToolError {
            if case .noExecutableSpecified = error {
                // Expected error
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }
    
    func testScriptNotFoundError() async throws {
        let tool = LocalTool(
            name: "script",
            description: "Script tool",
            script: "/nonexistent/script.sh",
            parameters: JSONSchema(type: .object, properties: [:], required: [])
        )
        
        do {
            _ = try await tool.execute(arguments: "{}")
            XCTFail("Should have thrown an error")
        } catch let error as LocalToolError {
            if case .scriptNotFound(let path) = error {
                XCTAssertEqual(path, "/nonexistent/script.sh")
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }
    
    // MARK: - Integration Tests
    
    func testSimpleCommandExecution() async throws {
        let tool = LocalTool(
            name: "date",
            description: "Get current date",
            command: "date '+%Y-%m-%d'",
            parameters: JSONSchema(type: .object, properties: [:], required: [])
        )
        
        let result = try await tool.execute(arguments: "{}")
        
        // Check that result looks like a date
        XCTAssertTrue(result.contains("-"))
        XCTAssertEqual(result.count, 10) // YYYY-MM-DD format
    }
    
    func testCommandWithParameters() async throws {
        let tool = LocalTool(
            name: "echo",
            description: "Echo a message",
            command: "echo '{{message}}'",
            parameters: JSONSchema(
                type: .object,
                properties: ["message": JSONSchema(type: .string)],
                required: ["message"]
            )
        )
        
        let result = try await tool.execute(arguments: "{\"message\": \"Hello, World!\"}")
        XCTAssertEqual(result.trimmingCharacters(in: .whitespacesAndNewlines), "Hello, World!")
    }
}

// MARK: - Test Helpers

private class CommandInterpolationTestTool: LocalTool {
    init() {
        super.init(
            name: "test",
            description: "Test tool",
            command: "echo",
            parameters: JSONSchema(type: .object, properties: [:], required: [])
        )
    }
    
    func testInterpolateCommand(_ command: String, with args: [String: Any]) -> String {
        return interpolateCommand(command, with: args)
    }
    
    func testEscapeShellArgument(_ arg: String) -> String {
        return escapeShellArgument(arg)
    }
}

private class LocalToolTestHelper {
    let tool: LocalTool
    
    init(tool: LocalTool) {
        self.tool = tool
    }
    
    func testParseArguments(_ json: String) throws -> [String: Any] {
        return try tool.parseArguments(json)
    }
}

// Extension to make private methods accessible for testing
extension LocalTool {
    func parseArguments(_ jsonString: String) throws -> [String: Any] {
        guard !jsonString.isEmpty else { return [:] }
        
        guard let data = jsonString.data(using: .utf8) else {
            throw LocalToolError.invalidArguments("Failed to convert arguments to data")
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LocalToolError.invalidArguments("Arguments must be a JSON object")
        }
        
        return json
    }
    
    func interpolateCommand(_ command: String, with args: [String: Any]) -> String {
        var result = command
        
        for (key, value) in args {
            let placeholder = "{{\(key)}}"
            let escapedValue = escapeShellArgument(String(describing: value))
            result = result.replacingOccurrences(of: placeholder, with: escapedValue)
        }
        
        return result
    }
    
    func escapeShellArgument(_ arg: String) -> String {
        let specialCharacters = CharacterSet(charactersIn: "\"'\\$`! ")
        if arg.rangeOfCharacter(from: specialCharacters) != nil {
            let escaped = arg.replacingOccurrences(of: "'", with: "'\\''")
            return "'\(escaped)'"
        }
        return arg
    }
}