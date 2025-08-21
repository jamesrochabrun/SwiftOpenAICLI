import XCTest
import ArgumentParser
@testable import SwiftOpenAICLI

final class AgentCommandTests: XCTestCase {
    
    // MARK: - Timeout Tests
    
    func testCustomTimeoutOverride() throws {
        var command = try AgentCommand.parse(["test message", "--timeout", "300"])
        XCTAssertEqual(command.timeout, 300, "Custom timeout should be 300 seconds")
    }
    
    func testDefaultTimeoutIsNil() throws {
        let command = try AgentCommand.parse(["test message"])
        XCTAssertNil(command.timeout, "Default timeout should be nil (determined by model)")
    }
    
    // MARK: - Tool Events Tests
    
    func testShowToolEventsVerboseFlag() throws {
        var command = try AgentCommand.parse(["test", "--show-tool-events-verbose"])
        XCTAssertTrue(command.showToolEventsVerbose, "Verbose flag should be set")
    }
    
    func testShowToolEventsFlagDefault() throws {
        let command = try AgentCommand.parse(["test"])
        XCTAssertFalse(command.showToolEvents, "Show tool events should be false by default")
        XCTAssertFalse(command.showToolEventsVerbose, "Verbose should be false by default")
    }
    
    // MARK: - Allowed Tools Tests
    
    func testAllowedToolsParsing() throws {
        var command = try AgentCommand.parse([
            "test",
            "--allowed-tools", "mcp__github__*,mcp__postgres__*"
        ])
        XCTAssertEqual(command.allowedTools, "mcp__github__*,mcp__postgres__*")
    }
    
    // Private methods can't be tested directly, only through public API
    
    // MARK: - MCP Server Tests
    
    func testMCPServersParsing() throws {
        var command = try AgentCommand.parse([
            "test",
            "--mcp-servers", "github,postgres"
        ])
        XCTAssertEqual(command.mcpServers, "github,postgres")
    }
    
    func testShowMCPStatusFlag() throws {
        var command = try AgentCommand.parse(["test", "--show-mcp-status"])
        XCTAssertTrue(command.showMCPStatus, "MCP status flag should be set")
    }
    
    // MARK: - Session Management Tests
    
    func testSessionIdParsing() throws {
        let sessionId = "test-session-123"
        var command = try AgentCommand.parse([
            "test",
            "--session-id", sessionId
        ])
        XCTAssertEqual(command.sessionId, sessionId)
    }
    
    // MARK: - Model and Verbosity Tests
    
    func testDefaultModel() throws {
        let command = try AgentCommand.parse(["test"])
        XCTAssertEqual(command.model, "gpt-5", "Default model should be gpt-5")
    }
    
    func testCustomModel() throws {
        var command = try AgentCommand.parse(["test", "--model", "gpt-4o"])
        XCTAssertEqual(command.model, "gpt-4o")
    }
    
    func testVerbosityLevels() throws {
        var command = try AgentCommand.parse(["test", "--model-verbosity", "high"])
        XCTAssertEqual(command.modelVerbosity, .high)
    }
    
    func testReasoningEffort() throws {
        var command = try AgentCommand.parse(["test", "--reasoning", "minimal"])
        XCTAssertEqual(command.reasoning, .minimal)
    }
    
    // MARK: - Output Format Tests
    
    func testOutputFormatDefault() throws {
        let command = try AgentCommand.parse(["test"])
        XCTAssertEqual(command.outputFormat, "plain")
    }
    
    func testOutputFormatJSON() throws {
        var command = try AgentCommand.parse(["test", "--output-format", "json"])
        XCTAssertEqual(command.outputFormat, "json")
    }
    
    func testOutputFormatStreamJSON() throws {
        var command = try AgentCommand.parse(["test", "--output-format", "stream-json"])
        XCTAssertEqual(command.outputFormat, "stream-json")
    }
    
    // MARK: - Interactive Mode Tests
    
    func testInteractiveFlag() throws {
        var command = try AgentCommand.parse(["--interactive"])
        XCTAssertTrue(command.interactive)
        XCTAssertNil(command.message, "Message should be nil in interactive mode")
    }
    
    func testNonInteractiveWithMessage() throws {
        let message = "Test message"
        var command = try AgentCommand.parse([message])
        XCTAssertFalse(command.interactive)
        XCTAssertEqual(command.message, message)
    }
    
    // MARK: - Tools Parameter Tests
    
    func testToolsParameterDefault() throws {
        let command = try AgentCommand.parse(["test"])
        XCTAssertEqual(command.tools, "", "Tools should be empty by default")
    }
    
    // Private parseTools method can't be tested directly
    
    // MARK: - Temperature and Max Tokens Tests
    
    func testDefaultTemperature() throws {
        let command = try AgentCommand.parse(["test"])
        XCTAssertEqual(command.temperature, 1.0)
    }
    
    func testCustomTemperature() throws {
        var command = try AgentCommand.parse(["test", "--temperature", "0.7"])
        XCTAssertEqual(command.temperature, 0.7)
    }
    
    func testMaxTokens() throws {
        var command = try AgentCommand.parse(["test", "--max-tokens", "500"])
        XCTAssertEqual(command.maxTokens, 500)
    }
    
    func testMaxTokensNil() throws {
        let command = try AgentCommand.parse(["test"])
        XCTAssertNil(command.maxTokens)
    }
    
    // MARK: - System Prompt Tests
    
    func testSystemPrompt() throws {
        let systemPrompt = "You are a helpful assistant"
        var command = try AgentCommand.parse(["test", "--system", systemPrompt])
        XCTAssertEqual(command.system, systemPrompt)
    }
    
    func testSystemPromptNil() throws {
        let command = try AgentCommand.parse(["test"])
        XCTAssertNil(command.system)
    }
}