import XCTest
import SwiftOpenAI
@testable import SwiftOpenAICLICore

final class OpenAIServiceTests: XCTestCase {
  
  // MARK: - Test Streaming After Tool Execution
  
  func testStreamingAfterToolExecution() async throws {
    // Given: A mock OpenAI service that returns tool calls then streams a response
    let mockService = MockOpenAIService()
    let toolExecutor = MockToolExecutor()
    
    // Configure mock to return tool call first, then streaming response
    mockService.mockResponses = [
      // First response with tool call
      ChatCompletionObject(
        choices: [
          ChatCompletionObject.Choices(
            message: ChatCompletionObject.Choices.Message(
              toolCalls: [
                ChatCompletionObject.Choices.Message.ToolCall(
                  id: "tool_1",
                  function: ChatCompletionObject.Choices.Message.ToolCall.Function(
                    name: "test_tool",
                    arguments: "{\"arg\": \"value\"}"
                  )
                )
              ]
            )
          )
        ]
      )
    ]
    
    // Configure streaming response after tool
    mockService.mockStreamDeltas = [
      StreamDelta(content: "After"),
      StreamDelta(content: " tool"),
      StreamDelta(content: " execution")
    ]
    
    // When: Processing a message that triggers tools then streaming
    let output = CaptureOutput()
    let service = OpenAIService.shared
    service.setMockService(mockService) // Inject mock
    
    await service.agentChatWithExecutor(
      message: "test message",
      model: "gpt-4",
      toolExecutor: toolExecutor,
      outputFormat: "interactive-stream"
    )
    
    // Then: Verify the output shows both tool execution and streamed response
    XCTAssertTrue(output.contains("🔧 Executing tool: test_tool"))
    XCTAssertTrue(output.contains("Assistant: After tool execution"))
    XCTAssertEqual(mockService.startChatCallCount, 1)
    XCTAssertEqual(mockService.startStreamedChatCallCount, 1)
  }
  
  // MARK: - Test Empty Stream Response
  
  func testEmptyStreamResponse() async throws {
    // Given: A mock that returns empty stream
    let mockService = MockOpenAIService()
    mockService.mockStreamDeltas = [] // Empty stream
    
    // When: Processing with empty stream
    let output = CaptureOutput()
    let service = OpenAIService.shared
    service.setMockService(mockService)
    
    await service.agentChatWithExecutor(
      message: "test",
      model: "gpt-4",
      toolExecutor: MockToolExecutor(),
      outputFormat: "interactive-stream"
    )
    
    // Then: Should show error message gracefully
    XCTAssertTrue(output.contains("[No response received - please try again]"))
  }
  
  // MARK: - Test Indicator Lifecycle
  
  func testIndicatorLifecycle() async throws {
    // Given: Mock service with delayed response
    let mockService = MockOpenAIService()
    mockService.responseDelay = 2.0 // 2 second delay
    
    mockService.mockStreamDeltas = [
      StreamDelta(content: "Hello"),
      StreamDelta(content: " world")
    ]
    
    // When: Processing with loading indicator
    let indicatorStates = IndicatorStateTracker()
    let service = OpenAIService.shared
    service.setMockService(mockService)
    service.setIndicatorTracker(indicatorStates)
    
    await service.agentChatWithExecutor(
      message: "test",
      model: "gpt-4",
      toolExecutor: MockToolExecutor(),
      outputFormat: "interactive-stream"
    )
    
    // Then: Verify indicator lifecycle
    XCTAssertTrue(indicatorStates.wasStarted, "Indicator should start")
    XCTAssertTrue(indicatorStates.wasStopped, "Indicator should stop")
    XCTAssertTrue(indicatorStates.stoppedAfterFirstToken, "Should stop on first token")
    XCTAssertFalse(indicatorStates.hasLingering, "No lingering indicator")
  }
  
  // MARK: - Test Multiple Tool Calls
  
  func testMultipleToolCallsWithFinalResponse() async throws {
    // Given: Multiple tool calls followed by final response
    let mockService = MockOpenAIService()
    let toolExecutor = MockToolExecutor()
    
    // First response: tool calls
    // Second response: more tool calls  
    // Third response: final streamed answer
    mockService.mockResponses = [
      createToolCallResponse("tool1", "args1"),
      createToolCallResponse("tool2", "args2")
    ]
    mockService.mockStreamDeltas = [
      StreamDelta(content: "Final"),
      StreamDelta(content: " answer")
    ]
    
    // When: Processing
    let output = CaptureOutput()
    let service = OpenAIService.shared
    service.setMockService(mockService)
    
    await service.agentChatWithExecutor(
      message: "complex task",
      model: "gpt-4",
      toolExecutor: toolExecutor,
      outputFormat: "interactive-stream",
      maxToolCalls: 5
    )
    
    // Then: All tools executed and final response shown
    XCTAssertTrue(output.contains("tool1"))
    XCTAssertTrue(output.contains("tool2"))
    XCTAssertTrue(output.contains("Assistant: Final answer"))
  }
  
  // MARK: - Test Error Recovery
  
  func testStreamErrorRecovery() async throws {
    // Given: Stream that throws error mid-stream
    let mockService = MockOpenAIService()
    mockService.mockStreamDeltas = [
      StreamDelta(content: "Part"),
      StreamDelta(error: StreamError.connectionLost)
    ]
    
    // When: Stream encounters error
    let output = CaptureOutput()
    let service = OpenAIService.shared
    service.setMockService(mockService)
    
    do {
      await service.agentChatWithExecutor(
        message: "test",
        model: "gpt-4", 
        toolExecutor: MockToolExecutor(),
        outputFormat: "interactive-stream"
      )
    } catch {
      // Expected error
    }
    
    // Then: Partial content should be saved
    XCTAssertTrue(output.contains("Assistant: Part"))
    XCTAssertTrue(output.indicatorWasStopped)
  }
}

// MARK: - Mock Helpers

class MockOpenAIService: OpenAIServiceProtocol {
  var mockResponses: [ChatCompletionObject] = []
  var mockStreamDeltas: [StreamDelta] = []
  var responseDelay: TimeInterval = 0
  var startChatCallCount = 0
  var startStreamedChatCallCount = 0
  
  func startChat(parameters: ChatCompletionParameters) async throws -> ChatCompletionObject {
    startChatCallCount += 1
    if responseDelay > 0 {
      try await Task.sleep(nanoseconds: UInt64(responseDelay * 1_000_000_000))
    }
    guard !mockResponses.isEmpty else {
      return ChatCompletionObject(choices: [])
    }
    return mockResponses.removeFirst()
  }
  
  func startStreamedChat(parameters: ChatCompletionParameters) async throws -> AsyncThrowingStream<ChatCompletionStreamResult, Error> {
    startStreamedChatCallCount += 1
    return AsyncThrowingStream { continuation in
      Task {
        if responseDelay > 0 {
          try await Task.sleep(nanoseconds: UInt64(responseDelay * 1_000_000_000))
        }
        
        for delta in mockStreamDeltas {
          if let error = delta.error {
            continuation.finish(throwing: error)
            return
          }
          let result = ChatCompletionStreamResult(
            choices: [
              ChatCompletionStreamResult.Choices(
                delta: ChatCompletionStreamResult.Choices.Delta(
                  content: delta.content
                )
              )
            ]
          )
          continuation.yield(result)
          try await Task.sleep(nanoseconds: 10_000_000) // 10ms between tokens
        }
        continuation.finish()
      }
    }
  }
}

struct StreamDelta {
  var content: String? = nil
  var error: Error? = nil
}

enum StreamError: Error {
  case connectionLost
}

class MockToolExecutor: ToolExecutorProtocol {
  func executeTool(name: String, arguments: String) async throws -> String {
    return "Mock result for \(name)"
  }
}

class CaptureOutput {
  private var output = ""
  
  func write(_ string: String) {
    output += string
  }
  
  func contains(_ substring: String) -> Bool {
    output.contains(substring)
  }
}

class IndicatorStateTracker {
  var wasStarted = false
  var wasStopped = false
  var stoppedAfterFirstToken = false
  var hasLingering = false
}

// Helper to create tool call responses
func createToolCallResponse(_ toolName: String, _ args: String) -> ChatCompletionObject {
  ChatCompletionObject(
    choices: [
      ChatCompletionObject.Choices(
        message: ChatCompletionObject.Choices.Message(
          toolCalls: [
            ChatCompletionObject.Choices.Message.ToolCall(
              id: "tool_\(toolName)",
              function: ChatCompletionObject.Choices.Message.ToolCall.Function(
                name: toolName,
                arguments: args
              )
            )
          ]
        )
      )
    ]
  )
}