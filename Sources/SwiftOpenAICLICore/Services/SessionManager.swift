import Foundation
import SwiftOpenAI

public class SessionManager {
  public static let shared = SessionManager()
  
  struct SessionData {
    var messages: [ChatCompletionParameters.Message]
    var compactionCount: Int = 0
    var lastTokenCount: Int = 0
  }
  
  private var sessions: [String: SessionData] = [:]
  private let queue = DispatchQueue(label: "com.swiftopenai.sessionmanager", attributes: .concurrent)
  
  private init() {}
  
  func addMessage(_ message: ChatCompletionParameters.Message, to sessionId: String) {
    queue.async(flags: .barrier) {
      if self.sessions[sessionId] == nil {
        self.sessions[sessionId] = SessionData(messages: [])
      }
      self.sessions[sessionId]?.messages.append(message)
      self.updateTokenCount(for: sessionId)
    }
  }
  
  func addMessages(_ messages: [ChatCompletionParameters.Message], to sessionId: String) {
    queue.async(flags: .barrier) {
      if self.sessions[sessionId] == nil {
        self.sessions[sessionId] = SessionData(messages: [])
      }
      self.sessions[sessionId]?.messages.append(contentsOf: messages)
      self.updateTokenCount(for: sessionId)
    }
  }
  
  func getMessages(for sessionId: String) -> [ChatCompletionParameters.Message] {
    queue.sync {
      return sessions[sessionId]?.messages ?? []
    }
  }
  
  public func clearSession(_ sessionId: String) {
    queue.async(flags: .barrier) {
      self.sessions[sessionId] = SessionData(messages: [])
    }
  }
  
  func sessionExists(_ sessionId: String) -> Bool {
    queue.sync {
      return sessions[sessionId] != nil
    }
  }
  
  func updateMessages(_ messages: [ChatCompletionParameters.Message], for sessionId: String) {
    queue.async(flags: .barrier) {
      if self.sessions[sessionId] == nil {
        self.sessions[sessionId] = SessionData(messages: messages)
      } else {
        self.sessions[sessionId]?.messages = messages
      }
      self.updateTokenCount(for: sessionId)
    }
  }
  
  func compactSession(_ sessionId: String, with compactedMessage: ChatCompletionParameters.Message) {
    queue.async(flags: .barrier) {
      if self.sessions[sessionId] == nil {
        self.sessions[sessionId] = SessionData(messages: [compactedMessage])
      } else {
        // Keep only the compacted message and increment compaction count
        self.sessions[sessionId]?.messages = [compactedMessage]
        self.sessions[sessionId]?.compactionCount += 1
      }
      self.updateTokenCount(for: sessionId)
    }
  }
  
  func getSessionData(for sessionId: String) -> SessionData? {
    queue.sync {
      return sessions[sessionId]
    }
  }
  
  func getCompactionCount(for sessionId: String) -> Int {
    queue.sync {
      return sessions[sessionId]?.compactionCount ?? 0
    }
  }
  
  func getTokenCount(for sessionId: String) -> Int {
    queue.sync {
      return sessions[sessionId]?.lastTokenCount ?? 0
    }
  }
  
  private func updateTokenCount(for sessionId: String) {
    guard let messages = sessions[sessionId]?.messages else { return }
    sessions[sessionId]?.lastTokenCount = TokenCalculator.estimateTokens(for: messages)
  }
}
