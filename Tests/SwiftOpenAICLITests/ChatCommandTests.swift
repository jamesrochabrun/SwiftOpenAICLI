import XCTest
@testable import SwiftOpenAICLI
import ArgumentParser

final class ChatCommandTests: XCTestCase {
    
    func testDefaultVerbosityLevel() throws {
        let command = try ChatCommand.parse([])
        XCTAssertEqual(command.verbose, .medium)
    }
    
    func testDefaultReasoningEffort() throws {
        let command = try ChatCommand.parse([])
        XCTAssertEqual(command.reasoning, .medium)
    }
    
    func testParseVerbosityLevels() throws {
        // Test low
        var command = try ChatCommand.parse(["test message", "--verbose", "low"])
        XCTAssertEqual(command.verbose, .low)
        
        // Test medium
        command = try ChatCommand.parse(["test message", "--verbose", "medium"])
        XCTAssertEqual(command.verbose, .medium)
        
        // Test high
        command = try ChatCommand.parse(["test message", "--verbose", "high"])
        XCTAssertEqual(command.verbose, .high)
    }
    
    func testParseReasoningEfforts() throws {
        // Test minimal
        var command = try ChatCommand.parse(["test message", "--reasoning", "minimal"])
        XCTAssertEqual(command.reasoning, .minimal)
        
        // Test low
        command = try ChatCommand.parse(["test message", "--reasoning", "low"])
        XCTAssertEqual(command.reasoning, .low)
        
        // Test medium
        command = try ChatCommand.parse(["test message", "--reasoning", "medium"])
        XCTAssertEqual(command.reasoning, .medium)
        
        // Test high
        command = try ChatCommand.parse(["test message", "--reasoning", "high"])
        XCTAssertEqual(command.reasoning, .high)
    }
    
    func testInvalidVerbosityLevel() throws {
        XCTAssertThrowsError(try ChatCommand.parse(["test", "--verbose", "invalid"])) { error in
            // ArgumentParser throws a different error type for invalid enum values
            let errorDescription = String(describing: error)
            XCTAssertTrue(errorDescription.contains("verbose") || errorDescription.contains("invalid"))
        }
    }
    
    func testInvalidReasoningEffort() throws {
        XCTAssertThrowsError(try ChatCommand.parse(["test", "--reasoning", "invalid"])) { error in
            // ArgumentParser throws a different error type for invalid enum values
            let errorDescription = String(describing: error)
            XCTAssertTrue(errorDescription.contains("reasoning") || errorDescription.contains("invalid"))
        }
    }
    
    func testCombinedParameters() throws {
        let command = try ChatCommand.parse([
            "test message",
            "--model", "gpt5",
            "--verbose", "low",
            "--reasoning", "minimal",
            "--temperature", "0.5"
        ])
        
        XCTAssertEqual(command.message, "test message")
        XCTAssertEqual(command.model, "gpt5")
        XCTAssertEqual(command.verbose, .low)
        XCTAssertEqual(command.reasoning, .minimal)
        XCTAssertEqual(command.temperature, 0.5)
    }
    
    func testInteractiveModeFlag() throws {
        let command = try ChatCommand.parse(["--interactive"])
        XCTAssertTrue(command.interactive)
        XCTAssertNil(command.message)
    }
    
    func testPlainOutputFlag() throws {
        let command = try ChatCommand.parse(["test", "--plain"])
        XCTAssertTrue(command.plain)
    }
    
    func testNoStreamFlag() throws {
        let command = try ChatCommand.parse(["test", "--no-stream"])
        XCTAssertTrue(command.noStream)
    }
    
    func testSystemPrompt() throws {
        let command = try ChatCommand.parse(["test", "--system", "You are a helpful assistant"])
        XCTAssertEqual(command.system, "You are a helpful assistant")
    }
    
    func testMaxTokens() throws {
        let command = try ChatCommand.parse(["test", "--max-tokens", "500"])
        XCTAssertEqual(command.maxTokens, 500)
    }
}