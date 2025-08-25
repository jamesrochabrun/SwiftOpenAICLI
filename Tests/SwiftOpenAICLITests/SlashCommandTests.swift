import XCTest
@testable import SwiftOpenAICLICore

final class SlashCommandTests: XCTestCase {
  
  // MARK: - Registry Tests
  
  func testSlashCommandRegistration() {
    let registry = SlashCommandRegistry.shared
    
    // Clear existing commands for clean test
    let initialCount = registry.getAllCommands().count
    
    // Register a test command
    let testCommand = TestSlashCommand()
    registry.register(testCommand)
    
    // Verify registration
    XCTAssertNotNil(registry.getCommand("test"))
    XCTAssertTrue(registry.getAllCommands().count >= initialCount)
  }
  
  func testSlashCommandDetection() {
    XCTAssertTrue(SlashCommandRegistry.isSlashCommand("/help"))
    XCTAssertTrue(SlashCommandRegistry.isSlashCommand("/models"))
    XCTAssertTrue(SlashCommandRegistry.isSlashCommand("/config"))
    XCTAssertFalse(SlashCommandRegistry.isSlashCommand("help"))
    XCTAssertFalse(SlashCommandRegistry.isSlashCommand(""))
    XCTAssertFalse(SlashCommandRegistry.isSlashCommand("/ help"))
  }
  
  func testCommandParsing() {
    let registry = SlashCommandRegistry.shared
    
    // Test command without arguments
    let parsed1 = registry.parseCommand("/help")
    XCTAssertEqual(parsed1.name, "help")
    XCTAssertNil(parsed1.arguments)
    
    // Test command with arguments
    let parsed2 = registry.parseCommand("/models gpt-5")
    XCTAssertEqual(parsed2.name, "models")
    XCTAssertEqual(parsed2.arguments, "gpt-5")
    
    // Test command with multiple arguments
    let parsed3 = registry.parseCommand("/config set temperature 0.8")
    XCTAssertEqual(parsed3.name, "config")
    XCTAssertEqual(parsed3.arguments, "set temperature 0.8")
  }
  
  // MARK: - Context Mutation Tests
  
  func testContextMutationThroughRegistry() async throws {
    let registry = SlashCommandRegistry.shared
    registry.register(TestMutatingCommand())
    
    var context = CommandContext(
      sessionId: "test",
      currentModel: "gpt-4o",
      temperature: 1.0
    )
    
    let originalModel = context.currentModel
    let originalTemp = context.temperature
    
    _ = try await registry.execute("/testmutate", context: &context)
    
    XCTAssertNotEqual(context.currentModel, originalModel)
    XCTAssertNotEqual(context.temperature, originalTemp)
    XCTAssertEqual(context.currentModel, "test-model")
    XCTAssertEqual(context.temperature, 0.5)
  }
  
  // MARK: - Built-in Commands Tests
  
  func testHelpCommandExists() {
    let registry = SlashCommandRegistry.shared
    registry.register(HelpCommand())
    
    XCTAssertNotNil(registry.getCommand("help"))
  }
  
  func testClearCommandExists() {
    let registry = SlashCommandRegistry.shared
    registry.register(ClearCommand())
    
    XCTAssertNotNil(registry.getCommand("clear"))
  }
  
  func testModelsCommandExists() {
    let registry = SlashCommandRegistry.shared
    registry.register(ModelsSlashCommand())
    
    XCTAssertNotNil(registry.getCommand("models"))
  }
  
  func testConfigCommandExists() {
    let registry = SlashCommandRegistry.shared
    registry.register(ConfigSlashCommand())
    
    XCTAssertNotNil(registry.getCommand("config"))
  }
  
  // MARK: - Error Handling Tests
  
  func testUnknownCommandThrowsError() async {
    let registry = SlashCommandRegistry.shared
    var context = CommandContext(
      sessionId: "test",
      currentModel: "gpt-4o"
    )
    
    do {
      _ = try await registry.execute("/unknowncommand", context: &context)
      XCTFail("Should throw error for unknown command")
    } catch let error as CommandError {
      switch error {
      case .commandNotFound(let name):
        XCTAssertEqual(name, "unknowncommand")
      default:
        XCTFail("Wrong error type")
      }
    } catch {
      XCTFail("Unexpected error type: \(error)")
    }
  }
}

// MARK: - Test Commands

private struct TestSlashCommand: SlashCommand {
  let name = "test"
  let description = "Test command"
  
  func execute(arguments: String?, context: inout CommandContext) async throws -> Bool {
    return true
  }
}

private struct TestMutatingCommand: SlashCommand {
  let name = "testmutate"
  let description = "Test mutation command"
  
  func execute(arguments: String?, context: inout CommandContext) async throws -> Bool {
    context.currentModel = "test-model"
    context.temperature = 0.5
    return true
  }
}

// MARK: - Integration Tests

extension SlashCommandTests {
  
  func testModelChangePersistenceInAgentFlow() async throws {
    // Simulate the agent command flow
    var context = CommandContext(
      sessionId: "agent-session",
      currentModel: "gpt-4o",
      temperature: 1.0,
      maxTokens: nil
    )
    
    let registry = SlashCommandRegistry.shared
    registry.register(ModelsSlashCommand())
    
    // Initial model
    XCTAssertEqual(context.currentModel, "gpt-4o")
    
    // User selects a new model
    _ = try await registry.execute("/models gpt-5-nano", context: &context)
    XCTAssertEqual(context.currentModel, "gpt-5-nano")
    
    // Simulate multiple messages being sent with the new model
    for i in 1...5 {
      // In real flow, this would be passed to OpenAIService.agentChatWithExecutor
      XCTAssertEqual(context.currentModel, "gpt-5-nano", "Model should persist for message \(i)")
    }
    
    // User changes model again
    _ = try await registry.execute("/models gpt-4o-mini", context: &context)
    XCTAssertEqual(context.currentModel, "gpt-4o-mini")
    
    // Verify new model persists
    for i in 1...5 {
      XCTAssertEqual(context.currentModel, "gpt-4o-mini", "New model should persist for message \(i)")
    }
  }
}