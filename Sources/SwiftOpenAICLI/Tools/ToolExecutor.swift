import Foundation
import SwiftOpenAI
import Rainbow

class ToolExecutor {
  private var availableTools: [String: CLITool] = [:]
  
  init() {
    registerBuiltInTools()
  }
  
  private func registerBuiltInTools() {
    let calculator = CalculatorTool()
    let dateTime = DateTimeTool()
    let fileReader = FileReaderTool()
    
    availableTools[calculator.name] = calculator
    availableTools[dateTime.name] = dateTime
    availableTools[fileReader.name] = fileReader
  }
  
  func getToolDefinitions(for toolNames: Set<String>) -> [ChatCompletionParameters.Tool] {
    return toolNames.compactMap { name in
      guard let tool = availableTools[name] else { return nil }
      return ChatCompletionParameters.Tool(
        type: "function",
        function: tool.toChatFunction()
      )
    }
  }
  
  func executeTool(name: String, arguments: String, outputFormat: String = "plain") async throws -> String {
    guard let tool = availableTools[name] else {
      return "Error: Unknown tool '\(name)'"
    }
    
    // Only show detailed tool execution in plain format (silent mode shows nothing)
    if outputFormat == "plain" {
      print("\n🔧 Executing tool: \(name)".lightBlack)
      print("   Arguments: \(arguments)".lightBlack)
    }
    
    let result = try await tool.execute(arguments: arguments)
    
    if outputFormat == "plain" {
      print("   Result: \(result)".lightBlack)
    }
    
    return result
  }
  
  func printAvailableTools() {
    print("Available tools:".cyan)
    for (name, tool) in availableTools.sorted(by: { $0.key < $1.key }) {
      print("  • \(name): \(tool.description)".lightBlack)
    }
  }
  
}
