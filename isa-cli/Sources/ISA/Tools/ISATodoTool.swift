import Foundation
import SwiftOpenAICLICore
import SwiftOpenAI

public class ISATodoTool: CLITool {
  public let name = "isa__todo_write"
  
  public let description = "Manage the todo list for tracking tasks"
  
  // Using SwiftOpenAI's JSONSchema
  public var parameters: JSONSchema {
    return JSONSchema(
      type: .object,
      properties: [
        "todos": JSONSchema(
          type: .array,
          description: "The updated todo list",
          items: JSONSchema(
            type: .object,
            properties: [
              "content": JSONSchema(
                type: .string,
                description: "The task description"
              ),
              "activeForm": JSONSchema(
                type: .string,
                description: "The active form of the task"
              ),
              "status": JSONSchema(
                type: .string,
                description: "The status of the task",
                enum: ["pending", "in_progress", "completed"]
              )
            ],
            required: ["content", "activeForm", "status"]
          )
        )
      ],
      required: ["todos"]
    )
  }
  
  public let isStrictModeCompatible = false
  
  private weak var todoList: TodoList?
  
  public init(todoList: TodoList) {
    self.todoList = todoList
  }
  
  public func execute(arguments: String) async throws -> String {
    guard let data = arguments.data(using: .utf8) else {
      throw ISAToolError.invalidArguments("Could not parse arguments")
    }
    
    let decoder = JSONDecoder()
    let args = try decoder.decode(Arguments.self, from: data)
    
    guard let todoList = todoList else {
      throw ISAToolError.executionFailed("Todo list not available")
    }
    
    // Clear and update todos
    var newTodos: [Todo] = []
    
    for todoInput in args.todos {
      guard let status = TodoStatus(rawValue: todoInput.status) else {
        throw ISAToolError.invalidArguments("Invalid status: \(todoInput.status)")
      }
      
      let todo = Todo(
        content: todoInput.content,
        activeForm: todoInput.activeForm,
        status: status
      )
      newTodos.append(todo)
    }
    
    todoList.update(newTodos)
    
    // Generate summary
    let pending = newTodos.filter { $0.status == .pending }.count
    let inProgress = newTodos.filter { $0.status == .inProgress }.count
    let completed = newTodos.filter { $0.status == .completed }.count
    
    // Show visual update if in interactive mode
    if ProcessInfo.processInfo.environment["ISA_INTERACTIVE"] == "true" {
      TerminalUI.showTodoSummary(todoList)
    }
    
    return "Todo list updated: \(pending) pending, \(inProgress) in progress, \(completed) completed"
  }
  
  private struct Arguments: Codable {
    let todos: [TodoInput]
  }
  
  private struct TodoInput: Codable {
    let content: String
    let activeForm: String
    let status: String
  }
}