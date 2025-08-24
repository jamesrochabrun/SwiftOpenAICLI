import Foundation

public enum TodoStatus: String, Codable {
  case pending
  case inProgress = "in_progress"
  case completed
}

public struct Todo: Codable {
  public let id: String
  public var content: String
  public var activeForm: String
  public var status: TodoStatus
  
  public init(content: String, activeForm: String, status: TodoStatus = .pending) {
    self.id = UUID().uuidString
    self.content = content
    self.activeForm = activeForm
    self.status = status
  }
}

public class TodoList {
  public private(set) var todos: [Todo] = []
  
  public func add(_ todo: Todo) {
    todos.append(todo)
  }
  
  public func update(_ todos: [Todo]) {
    self.todos = todos
  }
  
  public func markInProgress(_ id: String) {
    if let index = todos.firstIndex(where: { $0.id == id }) {
      todos[index].status = .inProgress
    }
  }
  
  public func markCompleted(_ id: String) {
    if let index = todos.firstIndex(where: { $0.id == id }) {
      todos[index].status = .completed
    }
  }
  
  public func remove(_ id: String) {
    todos.removeAll { $0.id == id }
  }
  
  public func clear() {
    todos.removeAll()
  }
  
  public var pending: [Todo] {
    todos.filter { $0.status == .pending }
  }
  
  public var inProgress: [Todo] {
    todos.filter { $0.status == .inProgress }
  }
  
  public var completed: [Todo] {
    todos.filter { $0.status == .completed }
  }
}