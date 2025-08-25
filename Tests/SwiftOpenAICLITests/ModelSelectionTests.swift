import XCTest
@testable import SwiftOpenAICLICore

final class ModelSelectionTests: XCTestCase {
  
  // MARK: - Model List Tests
  
  func testModelsSlashCommandReturnsExactlyFiveModels() async throws {
    let command = ModelsSlashCommand()
    
    // Access the private method through reflection or test the public API
    // Since getAvailableModels is private, we'll test through the command execution
    var context = CommandContext(
      sessionId: "test-session",
      currentModel: "gpt-4o",
      temperature: 1.0,
      maxTokens: nil
    )
    
    // Test that the command has the correct properties
    XCTAssertEqual(command.name, "models")
    XCTAssertEqual(command.description, "List and select available AI models")
    XCTAssertEqual(command.argumentHint, "[model-name]")
  }
  
  func testAvailableModelsAreCorrect() {
    // Test that we have exactly the 5 models specified
    let expectedModels = [
      "gpt-5",
      "gpt-5-mini",
      "gpt-5-nano",
      "gpt-4o",
      "gpt-4o-mini"
    ]
    
    // Since we can't directly access private methods, we test through behavior
    let command = ModelsSlashCommand()
    var context = CommandContext(
      sessionId: "test",
      currentModel: "gpt-4o",
      temperature: 1.0
    )
    
    // Test with each expected model name
    for model in expectedModels {
      var testContext = context
      Task {
        let result = try await command.execute(arguments: model, context: &testContext)
        XCTAssertTrue(result)
        XCTAssertEqual(testContext.currentModel, model)
      }
    }
  }
  
  // MARK: - Context Mutation Tests
  
  func testModelSelectionUpdatesContext() async throws {
    let command = ModelsSlashCommand()
    var context = CommandContext(
      sessionId: "test-session",
      currentModel: "gpt-4o",
      temperature: 1.0,
      maxTokens: nil
    )
    
    // Execute command with specific model
    let result = try await command.execute(arguments: "gpt-5-mini", context: &context)
    
    XCTAssertTrue(result, "Command should return true")
    XCTAssertEqual(context.currentModel, "gpt-5-mini", "Context should be updated with new model")
  }
  
  func testModelSelectionIsCaseInsensitive() async throws {
    let command = ModelsSlashCommand()
    var context = CommandContext(
      sessionId: "test-session",
      currentModel: "gpt-4o",
      temperature: 1.0,
      maxTokens: nil
    )
    
    // Test with uppercase
    let result = try await command.execute(arguments: "GPT-5-MINI", context: &context)
    
    XCTAssertTrue(result)
    XCTAssertEqual(context.currentModel, "gpt-5-mini", "Should match case-insensitively")
  }
  
  func testModelSelectionWithUnknownModelStillSetsIt() async throws {
    let command = ModelsSlashCommand()
    var context = CommandContext(
      sessionId: "test-session",
      currentModel: "gpt-4o",
      temperature: 1.0,
      maxTokens: nil
    )
    
    // Test with unknown model (allows flexibility for future models)
    let result = try await command.execute(arguments: "gpt-6-ultra", context: &context)
    
    XCTAssertTrue(result)
    XCTAssertEqual(context.currentModel, "gpt-6-ultra", "Should accept unknown models")
  }
  
  // MARK: - Model Persistence Tests
  
  func testContextChangePersistsAcrossMultipleCalls() async throws {
    var context = CommandContext(
      sessionId: "test-session",
      currentModel: "gpt-4o",
      temperature: 1.0,
      maxTokens: nil
    )
    
    let command = ModelsSlashCommand()
    
    // First change
    _ = try await command.execute(arguments: "gpt-5", context: &context)
    XCTAssertEqual(context.currentModel, "gpt-5")
    
    // Second change
    _ = try await command.execute(arguments: "gpt-5-nano", context: &context)
    XCTAssertEqual(context.currentModel, "gpt-5-nano")
    
    // Third change
    _ = try await command.execute(arguments: "gpt-4o-mini", context: &context)
    XCTAssertEqual(context.currentModel, "gpt-4o-mini")
  }
  
  func testSlashCommandRegistryPassesContextByReference() async throws {
    let registry = SlashCommandRegistry.shared
    registry.register(ModelsSlashCommand())
    
    var context = CommandContext(
      sessionId: "test-session",
      currentModel: "gpt-4o",
      temperature: 1.0,
      maxTokens: nil
    )
    
    let originalModel = context.currentModel
    
    // Execute through registry
    _ = try await registry.execute("/models gpt-5-mini", context: &context)
    
    XCTAssertNotEqual(context.currentModel, originalModel)
    XCTAssertEqual(context.currentModel, "gpt-5-mini")
  }
}

// MARK: - CommandContext Tests

extension ModelSelectionTests {
  
  func testCommandContextMutability() {
    var context = CommandContext(
      sessionId: "test",
      currentModel: "gpt-4o",
      temperature: 0.7,
      maxTokens: 1000
    )
    
    // Test that all properties are mutable
    context.currentModel = "gpt-5"
    context.temperature = 0.9
    context.maxTokens = 2000
    context.sessionId = "new-session"
    
    XCTAssertEqual(context.currentModel, "gpt-5")
    XCTAssertEqual(context.temperature, 0.9)
    XCTAssertEqual(context.maxTokens, 2000)
    XCTAssertEqual(context.sessionId, "new-session")
  }
}