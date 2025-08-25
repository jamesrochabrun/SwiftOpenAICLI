import XCTest
import SwiftOpenAI
@testable import SwiftOpenAICLICore

final class ToolExecutorTests: XCTestCase {
    
    // MARK: - Initialization Tests
    
    func testToolExecutorInitialization() async throws {
        let executor = ToolExecutor(
            mcpServers: [],
            verbose: false,
            useStderr: false,
            showToolEventsVerbose: false
        )
        
        XCTAssertNotNil(executor)
    }
    
    func testToolExecutorWithVerboseMode() async throws {
        let executor = ToolExecutor(
            mcpServers: [],
            verbose: true,
            useStderr: false,
            showToolEventsVerbose: true
        )
        
        XCTAssertNotNil(executor)
    }
    
    func testToolExecutorWithStderrOutput() async throws {
        let executor = ToolExecutor(
            mcpServers: [],
            verbose: false,
            useStderr: true,
            showToolEventsVerbose: false
        )
        
        XCTAssertNotNil(executor)
    }
    
    // MARK: - Tool Pattern Matching Tests
    
    func testExactToolNameMatch() {
        let toolName = "test_tool"
        let enabledTools = Set(["test_tool", "other_tool"])
        
        XCTAssertTrue(isToolAllowed(toolName, enabledTools: enabledTools))
    }
    
    func testWildcardToolNameMatch() {
        let toolName = "mcp__github__create_issue"
        let enabledTools = Set(["mcp__*"])
        
        XCTAssertTrue(isToolAllowed(toolName, enabledTools: enabledTools))
    }
    
    func testPrefixWildcardMatch() {
        let toolName = "mcp__github__create_issue"
        let enabledTools = Set(["mcp__github__*"])
        
        XCTAssertTrue(isToolAllowed(toolName, enabledTools: enabledTools))
    }
    
    func testNonMatchingTool() {
        let toolName = "other_tool"
        let enabledTools = Set(["test_tool"])
        
        XCTAssertFalse(isToolAllowed(toolName, enabledTools: enabledTools))
    }
    
    func testNilEnabledToolsAllowsAll() {
        let toolName = "any_tool"
        let enabledTools: Set<String>? = nil
        
        XCTAssertTrue(isToolAllowed(toolName, enabledTools: enabledTools))
    }
    
    // MARK: - Result Truncation Tests
    
    func testCompactModeTruncation() {
        let longText = String(repeating: "a", count: 1000)
        let truncated = truncateForDisplay(longText, verbose: false)
        
        XCTAssertTrue(truncated.count < longText.count)
        XCTAssertTrue(truncated.contains("..."))
        XCTAssertTrue(truncated.contains("more chars"))
    }
    
    func testVerboseModeNoTruncation() {
        let longText = String(repeating: "a", count: 1000)
        let result = truncateForDisplay(longText, verbose: true)
        
        XCTAssertEqual(result, longText)
    }
    
    func testShortTextNoTruncation() {
        let shortText = "This is a short text"
        let result = truncateForDisplay(shortText, verbose: false)
        
        XCTAssertEqual(result, shortText)
    }
    
    func testSearchResultsTruncation() {
        let searchJSON = """
        {
            "searchResults": [
                {"title": "Result 1", "url": "http://example.com/1"},
                {"title": "Result 2", "url": "http://example.com/2"},
                {"title": "Result 3", "url": "http://example.com/3"},
                {"title": "Result 4", "url": "http://example.com/4"},
                {"title": "Result 5", "url": "http://example.com/5"}
            ]
        }
        """
        
        let truncated = truncateForDisplay(searchJSON, verbose: false)
        
        XCTAssertTrue(truncated.contains("Found 5 results"))
        XCTAssertTrue(truncated.contains("showing 3"))
        XCTAssertTrue(truncated.contains("2 more results"))
    }
    
    // MARK: - MCP Configuration Tests
    
    func testMCPServerConfiguration() {
        let mcpConfig = MCPServerConfig(
            name: "test-server",
            transport: "stdio",
            command: "echo",
            url: nil,
            args: ["test"],
            environment: nil
        )
        
        XCTAssertEqual(mcpConfig.name, "test-server")
        XCTAssertEqual(mcpConfig.command, "echo")
        XCTAssertEqual(mcpConfig.args, ["test"])
        XCTAssertNil(mcpConfig.environment)
    }
    
    func testMCPServerWithEnvironment() {
        let mcpConfig = MCPServerConfig(
            name: "test-server",
            transport: "stdio",
            command: "node",
            url: nil,
            args: ["server.js"],
            environment: ["NODE_ENV": "test"]
        )
        
        XCTAssertEqual(mcpConfig.environment?["NODE_ENV"], "test")
    }
    
    // MARK: - Tool Arguments Tests
    
    func testValidJSONArguments() throws {
        let arguments = "{\"input\": \"test value\"}"
        let argsData = arguments.data(using: .utf8)!
        let args = try JSONSerialization.jsonObject(with: argsData) as! [String: Any]
        XCTAssertEqual(args["input"] as? String, "test value")
    }
    
    func testInvalidJSONArguments() {
        let arguments = "invalid json {"
        let argsData = arguments.data(using: .utf8)!
        let args = try? JSONSerialization.jsonObject(with: argsData)
        XCTAssertNil(args)
    }
    
    // MARK: - Local Tool Registration Tests
    
    func testRegisterLocalTool() async throws {
        let executor = ToolExecutor(
            mcpServers: [],
            localToolsConfigPath: nil,
            verbose: false,
            useStderr: false,
            showToolEventsVerbose: false
        )
        
        let tool = LocalTool(
            name: "test_tool",
            description: "A test tool",
            command: "echo 'test'",
            parameters: JSONSchema(type: .object, properties: [:], required: [])
        )
        
        executor.registerLocalTool(tool)
        
        let allTools = executor.getAllAvailableToolNames()
        XCTAssertTrue(allTools.contains("local__test_tool"))
    }
    
    func testLoadLocalToolsFromConfig() async throws {
        // Create a temporary config file
        let tempDir = FileManager.default.temporaryDirectory
        let configPath = tempDir.appendingPathComponent("test-tools.json").path
        
        let config = """
        {
            "tools": [
                {
                    "name": "test_tool",
                    "description": "Test tool",
                    "command": "echo {{message}}",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "message": {
                                "type": "string",
                                "description": "Message to echo"
                            }
                        }
                    }
                }
            ]
        }
        """
        
        try config.write(toFile: configPath, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: configPath) }
        
        let executor = ToolExecutor(
            mcpServers: [],
            localToolsConfigPath: configPath,
            verbose: false,
            useStderr: false,
            showToolEventsVerbose: false
        )
        
        await executor.initialize()
        
        let allTools = executor.getAllAvailableToolNames()
        XCTAssertTrue(allTools.contains("local__test_tool"))
    }
    
    func testMixedToolResolution() async throws {
        let executor = ToolExecutor(
            mcpServers: [],
            localToolsConfigPath: nil,
            verbose: false,
            useStderr: false,
            showToolEventsVerbose: false
        )
        
        // Register a local tool
        let localTool = LocalTool(
            name: "local_tool",
            description: "Local tool",
            command: "echo",
            parameters: JSONSchema(type: .object, properties: [:], required: [])
        )
        executor.registerLocalTool(localTool)
        
        // Test that we can get tools by simple name (without prefix)
        let tools1 = executor.getToolDefinitions(for: Set(["local_tool"]))
        XCTAssertEqual(tools1.count, 1)
        XCTAssertEqual(tools1.first?.function.name, "local__local_tool")
        
        // Test with prefix
        let tools2 = executor.getToolDefinitions(for: Set(["local__local_tool"]))
        XCTAssertEqual(tools2.count, 1)
        
        // Test glob pattern for all local tools
        let tools3 = executor.getToolDefinitions(for: Set(["local__*"]))
        XCTAssertEqual(tools3.count, 1)
    }
    
    func testLocalToolGlobPatterns() async throws {
        let executor = ToolExecutor(
            mcpServers: [],
            localToolsConfigPath: nil,
            verbose: false,
            useStderr: false,
            showToolEventsVerbose: false
        )
        
        // Register multiple local tools
        for i in 1...3 {
            let tool = LocalTool(
                name: "tool_\(i)",
                description: "Tool \(i)",
                command: "echo \(i)",
                parameters: JSONSchema(type: .object, properties: [:], required: [])
            )
            executor.registerLocalTool(tool)
        }
        
        // Test wildcard pattern
        let tools = executor.getToolDefinitions(for: Set(["local__*"]))
        XCTAssertEqual(tools.count, 3)
        
        // Test specific pattern
        let tools2 = executor.getToolDefinitions(for: Set(["local__tool_1", "local__tool_2"]))
        XCTAssertEqual(tools2.count, 2)
    }
    
    func testToolExecutorCleanup() async throws {
        let executor = ToolExecutor(
            mcpServers: [],
            localToolsConfigPath: nil,
            verbose: false,
            useStderr: false,
            showToolEventsVerbose: false
        )
        
        // Register a tool
        let tool = LocalTool(
            name: "test",
            description: "Test",
            command: "echo",
            parameters: JSONSchema(type: .object, properties: [:], required: [])
        )
        executor.registerLocalTool(tool)
        
        XCTAssertFalse(executor.getAllAvailableToolNames().isEmpty)
        
        // Cleanup should remove all tools
        await executor.cleanup()
        XCTAssertTrue(executor.getAllAvailableToolNames().isEmpty)
    }
}

// MARK: - Helper Functions

private func isToolAllowed(_ toolName: String, enabledTools: Set<String>?) -> Bool {
    guard let enabledTools = enabledTools else {
        return true // All tools allowed if nil
    }
    
    // Check exact match
    if enabledTools.contains(toolName) {
        return true
    }
    
    // Check wildcard patterns
    for pattern in enabledTools {
        if pattern.hasSuffix("*") {
            let prefix = String(pattern.dropLast())
            if toolName.hasPrefix(prefix) {
                return true
            }
        }
    }
    
    return false
}

private func truncateForDisplay(_ text: String, verbose: Bool) -> String {
    if verbose {
        return text
    }
    
    let maxLength = 500
    
    // Try to parse as JSON for smart truncation
    if let data = text.data(using: .utf8),
       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
       let searchResults = json["searchResults"] as? [[String: Any]] {
        let count = searchResults.count
        let preview = searchResults.prefix(3).compactMap { result -> String? in
            guard let title = result["title"] as? String else { return nil }
            return "• \(title)"
        }.joined(separator: "\n  ")
        
        return "Found \(count) results (showing 3):\n  \(preview)\n  ... [\(count - 3) more results]"
    }
    
    // Simple truncation for other content
    if text.count > maxLength {
        return String(text.prefix(maxLength)) + "... [\(text.count - maxLength) more chars]"
    }
    
    return text
}