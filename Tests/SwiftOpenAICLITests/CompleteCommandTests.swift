import XCTest
@testable import SwiftOpenAICLI
import ArgumentParser

final class CompleteCommandTests: XCTestCase {
    
    func testDefaultVerbosityLevel() throws {
        let command = try CompleteCommand.parse(["test prompt"])
        XCTAssertEqual(command.verbose, .medium)
    }
    
    func testDefaultReasoningEffort() throws {
        let command = try CompleteCommand.parse(["test prompt"])
        XCTAssertEqual(command.reasoning, .medium)
    }
    
    func testParseVerbosityLevels() throws {
        // Test low
        var command = try CompleteCommand.parse(["test prompt", "--verbose", "low"])
        XCTAssertEqual(command.verbose, .low)
        
        // Test medium
        command = try CompleteCommand.parse(["test prompt", "--verbose", "medium"])
        XCTAssertEqual(command.verbose, .medium)
        
        // Test high
        command = try CompleteCommand.parse(["test prompt", "--verbose", "high"])
        XCTAssertEqual(command.verbose, .high)
    }
    
    func testParseReasoningEfforts() throws {
        // Test minimal
        var command = try CompleteCommand.parse(["test prompt", "--reasoning", "minimal"])
        XCTAssertEqual(command.reasoning, .minimal)
        
        // Test low
        command = try CompleteCommand.parse(["test prompt", "--reasoning", "low"])
        XCTAssertEqual(command.reasoning, .low)
        
        // Test medium
        command = try CompleteCommand.parse(["test prompt", "--reasoning", "medium"])
        XCTAssertEqual(command.reasoning, .medium)
        
        // Test high
        command = try CompleteCommand.parse(["test prompt", "--reasoning", "high"])
        XCTAssertEqual(command.reasoning, .high)
    }
    
    func testInvalidVerbosityLevel() throws {
        XCTAssertThrowsError(try CompleteCommand.parse(["test", "--verbose", "invalid"])) { error in
            // ArgumentParser throws a different error type for invalid enum values
            let errorDescription = String(describing: error)
            XCTAssertTrue(errorDescription.contains("verbose") || errorDescription.contains("invalid"))
        }
    }
    
    func testInvalidReasoningEffort() throws {
        XCTAssertThrowsError(try CompleteCommand.parse(["test", "--reasoning", "invalid"])) { error in
            // ArgumentParser throws a different error type for invalid enum values
            let errorDescription = String(describing: error)
            XCTAssertTrue(errorDescription.contains("reasoning") || errorDescription.contains("invalid"))
        }
    }
    
    func testCombinedParameters() throws {
        let command = try CompleteCommand.parse([
            "test prompt",
            "--model", "gpt5",
            "--verbose", "low",
            "--reasoning", "minimal",
            "--temperature", "0.5",
            "--max-tokens", "200"
        ])
        
        XCTAssertEqual(command.prompt, "test prompt")
        XCTAssertEqual(command.model, "gpt5")
        XCTAssertEqual(command.verbose, .low)
        XCTAssertEqual(command.reasoning, .minimal)
        XCTAssertEqual(command.temperature, 0.5)
        XCTAssertEqual(command.maxTokens, 200)
    }
    
    func testDefaultModel() throws {
        let command = try CompleteCommand.parse(["test prompt"])
        XCTAssertEqual(command.model, "gpt-3.5-turbo")
    }
    
    func testDefaultMaxTokens() throws {
        let command = try CompleteCommand.parse(["test prompt"])
        XCTAssertEqual(command.maxTokens, 100)
    }
    
    func testDefaultTemperature() throws {
        let command = try CompleteCommand.parse(["test prompt"])
        XCTAssertEqual(command.temperature, 1.0)
    }
    
    func testNumberOfCompletions() throws {
        let command = try CompleteCommand.parse(["test prompt", "--number", "3"])
        XCTAssertEqual(command.number, 3)
    }
    
    func testShowTokensFlag() throws {
        let command = try CompleteCommand.parse(["test prompt", "--show-tokens"])
        XCTAssertTrue(command.showTokens)
    }
}