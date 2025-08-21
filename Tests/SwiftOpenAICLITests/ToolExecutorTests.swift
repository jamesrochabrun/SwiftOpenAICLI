import XCTest
import SwiftOpenAI
@testable import SwiftOpenAICLI

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
            command: "echo",
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
            command: "node",
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