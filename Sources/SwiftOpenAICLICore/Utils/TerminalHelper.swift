import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// Helper for terminal operations including raw mode and ESC detection
public class TerminalHelper {
  private var oldTermios: termios?
  private var isRawMode = false
  
  public init() {}
  
  /// Enable raw mode for single character input
  public func enableRawMode() {
    #if os(macOS) || os(Linux)
    var raw = termios()
    
    // Get current terminal settings
    guard tcgetattr(STDIN_FILENO, &raw) >= 0 else { return }
    
    // Save original settings
    oldTermios = raw
    
    // Modify for raw mode
    raw.c_lflag &= ~(UInt(ECHO | ICANON))  // Disable echo and canonical mode
    // c_cc is a tuple on macOS, we need to use withUnsafeMutableBytes
    withUnsafeMutableBytes(of: &raw.c_cc) { ptr in
      ptr[Int(VMIN)] = 0  // Non-blocking read
      ptr[Int(VTIME)] = 1 // 100ms timeout
    }
    
    // Apply new settings
    tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw)
    isRawMode = true
    #endif
  }
  
  /// Restore normal terminal mode
  public func disableRawMode() {
    #if os(macOS) || os(Linux)
    guard isRawMode, var original = oldTermios else { return }
    tcsetattr(STDIN_FILENO, TCSAFLUSH, &original)
    isRawMode = false
    #endif
  }
  
  /// Check if ESC key is pressed (non-blocking)
  public func checkForESC() -> Bool {
    #if os(macOS) || os(Linux)
    var c: Int32 = 0
    
    // Set stdin to non-blocking
    let oldFlags = fcntl(STDIN_FILENO, F_GETFL, 0)
    _ = fcntl(STDIN_FILENO, F_SETFL, oldFlags | O_NONBLOCK)
    
    // Try to read a character
    let result = read(STDIN_FILENO, &c, 1)
    
    // Check if we got ESC character (27 or 0x1B)
    if result > 0 && c == 27 {
      // Consume any following escape sequence characters (like '[')
      // This prevents ^[ from appearing in the terminal
      var dummy: Int32 = 0
      // Keep reading while there are more characters available
      while read(STDIN_FILENO, &dummy, 1) > 0 {
        // Just consume and discard
      }
      
      // Restore blocking mode
      _ = fcntl(STDIN_FILENO, F_SETFL, oldFlags)
      return true
    }
    
    // Restore blocking mode
    _ = fcntl(STDIN_FILENO, F_SETFL, oldFlags)
    #endif
    
    return false
  }
  
  /// Monitor for ESC key press during an async operation
  public func monitorForESC() async -> Bool {
    enableRawMode()
    defer { disableRawMode() }
    
    // Check for ESC every 100ms
    for _ in 0..<600 { // Max 60 seconds
      if checkForESC() {
        return true
      }
      
      // Small delay to avoid busy waiting
      try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
    }
    
    return false
  }
  
  deinit {
    // Ensure we restore terminal on cleanup
    disableRawMode()
  }
}

/// Global ESC key monitor
public class ESCMonitor {
  public static let shared = ESCMonitor()
  private var isMonitoring = false
  private var shouldCancel = false
  private let terminal = TerminalHelper()
  
  private init() {}
  
  /// Start monitoring for ESC key
  public func startMonitoring() {
    guard !isMonitoring else { return }
    isMonitoring = true
    shouldCancel = false

    // Enter raw mode synchronously to avoid race with canonical input buffering
    terminal.enableRawMode()

    // Flush any pending input so ESC applies to the current operation only
    #if canImport(Darwin)
    tcflush(STDIN_FILENO, TCIFLUSH)
    #elseif canImport(Glibc)
    tcflush(STDIN_FILENO, Int32(TCIFLUSH))
    #endif

    Task {
      defer {
        // Ensure we always restore terminal mode and state
        terminal.disableRawMode()
        
        // Clear any remaining input after stopping
        #if canImport(Darwin)
        tcflush(STDIN_FILENO, TCIFLUSH)
        #elseif canImport(Glibc)
        tcflush(STDIN_FILENO, Int32(TCIFLUSH))
        #endif
        
        isMonitoring = false
      }

      while isMonitoring {
        if terminal.checkForESC() {
          shouldCancel = true
          break
        }
        try? await Task.sleep(nanoseconds: 25_000_000) // 25ms - check more frequently
      }
    }
  }
  
  /// Stop monitoring
  public func stopMonitoring() {
    isMonitoring = false
    shouldCancel = false
    
    // Give time for terminal to restore and flush
    #if os(macOS) || os(Linux)
    // Small delay to ensure terminal mode is fully restored
    usleep(10000) // 10ms
    
    // Final flush to ensure no leftover bytes
    tcflush(STDIN_FILENO, TCIFLUSH)
    #endif
  }
  
  /// Check if cancellation was requested
  public func wasCancelled() -> Bool {
    return shouldCancel
  }
  
  /// Reset cancellation flag
  public func reset() {
    shouldCancel = false
  }
}
