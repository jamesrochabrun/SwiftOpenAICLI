import Foundation
import Rainbow

/// Animated loading indicator that displays a word with cycling dots
public class LoadingIndicator {
  private var animationTask: Task<Void, Never>?
  private let word: String
  private let color: (String) -> String
  private var isActive = false
  
  public init(word: String, color: @escaping (String) -> String = { $0.cyan }) {
    self.word = word
    self.color = color
  }
  
  /// Start the loading animation
  public func start() {
    guard !isActive else { return }
    isActive = true
    
    animationTask = Task.detached { [weak self] in
      guard let self = self else { return }
      var dots = 0
      let maxDots = 3
      
      while !Task.isCancelled {
        // Build the display string with proper spacing
        let dotsString = String(repeating: ".", count: dots)
        let spaces = String(repeating: " ", count: maxDots - dots)
        let display = "\r" + self.color(self.word + dotsString) + spaces + "  "
        
        // Use FileHandle for direct output to avoid MainActor
        if let data = display.data(using: .utf8) {
          FileHandle.standardOutput.write(data)
        }
        fflush(stdout)
        
        dots = (dots + 1) % (maxDots + 1)
        
        // Sleep for animation frame
        try? await Task.sleep(nanoseconds: 400_000_000) // 0.4 seconds
      }
    }
  }
  
  /// Stop the loading animation and clear the line
  public func stop() {
    guard isActive else { return }
    isActive = false
    
    animationTask?.cancel()
    animationTask = nil
    
    // Clear the loading line
    print("\r" + String(repeating: " ", count: word.count + 10) + "\r", terminator: "")
    fflush(stdout)
  }
  
  /// Stop the loading animation without clearing (line was already overwritten)
  public func stopWithoutClearing() {
    guard isActive else { return }
    isActive = false
    
    animationTask?.cancel()
    animationTask = nil
    // Don't print anything - line was already overwritten
  }
  
  /// Stop animation but keep the final text visible
  public func stopWithMessage(_ message: String? = nil) {
    guard isActive else { return }
    isActive = false
    
    animationTask?.cancel()
    animationTask = nil
    
    if let message = message {
      print("\r" + message)
    } else {
      print() // Just move to next line
    }
    fflush(stdout)
  }
}

/// Static loading indicator for simpler use cases
public class StaticLoadingIndicator {
  private let message: String
  private var displayed = false
  
  public init(message: String) {
    self.message = message
  }
  
  public func show() {
    guard !displayed else { return }
    displayed = true
    print(message.lightBlack, terminator: "")
    fflush(stdout)
  }
  
  public func clear() {
    guard displayed else { return }
    displayed = false
    print("\r" + String(repeating: " ", count: message.count) + "\r", terminator: "")
    fflush(stdout)
  }
}