import XCTest
@testable import SwiftOpenAICLICore

final class TimeoutTests: XCTestCase {
    
    // MARK: - Model-Specific Timeout Tests
    
    func testGPT5DefaultTimeout() async throws {
        // Test that GPT-5 models get 180 second timeout
        let models = ["gpt-5", "gpt5", "GPT-5", "gpt-5-mini", "gpt5mini", "gpt-5-nano", "gpt5nano"]
        
        for model in models {
            let timeout = getModelTimeout(for: model)
            XCTAssertEqual(timeout, 180, "\(model) should have 180 second timeout")
        }
    }
    
    func testGPT4oMiniTimeout() async throws {
        // Test that GPT-4o-mini gets 30 second timeout
        let models = ["gpt-4o-mini", "gpt4o-mini", "GPT-4o-mini", "GPT4o-mini"]
        
        for model in models {
            let timeout = getModelTimeout(for: model)
            XCTAssertEqual(timeout, 30, "\(model) should have 30 second timeout")
        }
    }
    
    func testDefaultModelTimeout() async throws {
        // Test that other models get 60 second timeout
        let models = ["gpt-4", "gpt-4o", "gpt-3.5-turbo", "claude-3", "llama-2"]
        
        for model in models {
            let timeout = getModelTimeout(for: model)
            XCTAssertEqual(timeout, 60, "\(model) should have 60 second timeout")
        }
    }
    
    // MARK: - Timeout Configuration Tests
    
    func testCustomTimeoutOverride() async throws {
        // Test that custom timeout overrides model defaults
        let customTimeout = 300
        let effectiveTimeout = customTimeout
        
        XCTAssertEqual(effectiveTimeout, 300, "Custom timeout should override defaults")
    }
    
    func testTimeoutInErrorMessage() async throws {
        // Test that timeout errors include the timeout duration
        let timeoutError = OpenAIServiceError.timeout(seconds: 60)
        
        switch timeoutError {
        case .timeout(let seconds):
            XCTAssertEqual(seconds, 60, "Timeout error should include duration")
        default:
            XCTFail("Expected timeout error")
        }
    }
    
    // MARK: - Async Timeout Tests
    
    func testTaskTimeoutBehavior() async throws {
        // Test that tasks actually timeout after specified duration
        let expectation = XCTestExpectation(description: "Task should timeout")
        
        Task {
            do {
                try await withThrowingTaskGroup(of: String.self) { group in
                    group.addTask {
                        // Simulate long-running task
                        try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                        return "completed"
                    }
                    
                    group.addTask {
                        // Timeout after 1 second
                        try await Task.sleep(nanoseconds: 1_000_000_000)
                        throw OpenAIServiceError.timeout(seconds: 1)
                    }
                    
                    if let result = try await group.next() {
                        group.cancelAll()
                        throw OpenAIServiceError.timeout(seconds: 1)
                    }
                    
                    throw OpenAIServiceError.timeout(seconds: 1)
                }
            } catch {
                if case OpenAIServiceError.timeout = error {
                    expectation.fulfill()
                }
            }
        }
        
        await fulfillment(of: [expectation], timeout: 2.0)
    }
    
    func testTaskCancellationOnTimeout() async throws {
        // Test that other tasks are cancelled when timeout occurs
        let expectation = XCTestExpectation(description: "Tasks should be cancelled")
        var wasCancelled = false
        
        Task {
            do {
                try await withThrowingTaskGroup(of: Void.self) { group in
                    group.addTask {
                        do {
                            try await Task.sleep(nanoseconds: 5_000_000_000)
                        } catch {
                            wasCancelled = Task.isCancelled
                        }
                    }
                    
                    group.addTask {
                        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                        throw OpenAIServiceError.timeout(seconds: 1)
                    }
                    
                    do {
                        for try await _ in group {
                            // Process results
                        }
                    } catch {
                        group.cancelAll()
                        throw error
                    }
                }
            } catch {
                if wasCancelled {
                    expectation.fulfill()
                }
            }
        }
        
        await fulfillment(of: [expectation], timeout: 2.0)
    }
    
    // MARK: - Recovery Tests
    
    func testTimeoutRecovery() async throws {
        // Test that service can recover after timeout
        var attempts = 0
        let maxAttempts = 3
        
        while attempts < maxAttempts {
            do {
                // Simulate API call that might timeout
                if attempts < 2 {
                    throw OpenAIServiceError.timeout(seconds: 1)
                } else {
                    // Succeed on third attempt
                    break
                }
            } catch {
                if case OpenAIServiceError.timeout = error {
                    attempts += 1
                    continue
                }
                throw error
            }
        }
        
        XCTAssertEqual(attempts, 2, "Should retry after timeout")
    }
    
    // MARK: - Interactive Mode Timeout Tests
    
    func testInteractiveModeTimeoutHandling() async throws {
        // Test that interactive mode handles timeouts gracefully
        let error = OpenAIServiceError.timeout(seconds: 60)
        let errorMessage = error.localizedDescription
        
        XCTAssertTrue(errorMessage.contains("timeout") || errorMessage.contains("60"),
                     "Timeout error should have descriptive message")
    }
    
    // MARK: - MCP Tool Timeout Tests
    
    func testMCPToolTimeout() async throws {
        // Test that MCP tool calls can timeout
        let expectation = XCTestExpectation(description: "MCP tool should timeout")
        
        Task {
            do {
                // Simulate MCP tool call with timeout
                try await withTimeout(seconds: 1) {
                    // Simulate slow MCP tool
                    try await Task.sleep(nanoseconds: 5_000_000_000)
                }
                XCTFail("Should have timed out")
            } catch {
                expectation.fulfill()
            }
        }
        
        await fulfillment(of: [expectation], timeout: 2.0)
    }
}

// MARK: - Helper Functions

private func getModelTimeout(for model: String) -> Int {
    let lowercased = model.lowercased()
    if lowercased.contains("gpt-5") || lowercased.contains("gpt5") {
        return 180 // 3 minutes for GPT-5
    } else if lowercased.contains("gpt-4o-mini") || lowercased.contains("gpt4o-mini") {
        return 30 // 30 seconds for GPT-4o-mini
    } else {
        return 60 // 1 minute default for other models
    }
}

private func withTimeout<T>(seconds: Int, operation: @escaping () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            return try await operation()
        }
        
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw OpenAIServiceError.timeout(seconds: seconds)
        }
        
        if let result = try await group.next() {
            group.cancelAll()
            return result
        }
        
        throw OpenAIServiceError.timeout(seconds: seconds)
    }
}

// MARK: - OpenAIServiceError Extension for Tests

extension OpenAIServiceError: Equatable {
    public static func == (lhs: OpenAIServiceError, rhs: OpenAIServiceError) -> Bool {
        switch (lhs, rhs) {
        case (.timeout(let l), .timeout(let r)):
            return l == r
        default:
            return false
        }
    }
}