import Foundation
import Rainbow
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// Interactive selection UI component
public class SelectionUI {
  
  public struct Option {
    public let value: String
    public let label: String
    public let description: String?
    public let isSelected: Bool
    
    public init(value: String, label: String, description: String? = nil, isSelected: Bool = false) {
      self.value = value
      self.label = label
      self.description = description
      self.isSelected = isSelected
    }
  }
  
  /// Show a selection UI and return the selected option
  public static func select(
    title: String,
    options: [Option],
    currentValue: String? = nil,
    allowCancel: Bool = true
  ) -> String? {
    
    guard !options.isEmpty else {
      print("No options available".red)
      return nil
    }
    
    var selectedIndex = options.firstIndex { $0.value == currentValue } ?? 0
    
    // Disable terminal echo for arrow key handling
    disableEcho()
    defer { enableEcho() }
    
    // Clear screen and show UI
    print("\u{001B}[2J\u{001B}[H")  // Clear screen and move to top
    
    while true {
      // Move cursor to top
      print("\u{001B}[H")
      
      // Print title
      print("\n " + title.cyan.bold)
      print(" " + String(repeating: "─", count: title.count + 10).lightBlack)
      print("")
      
      // Print options
      for (index, option) in options.enumerated() {
        let prefix = index == selectedIndex ? " ▶ " : "   "
        let label = option.label
        let description = option.description.map { " - \($0)" } ?? ""
        let selected = option.isSelected ? " ✓" : ""
        
        if index == selectedIndex {
          print("\(prefix)\(label)\(description)\(selected)".cyan.bold)
        } else {
          print("\(prefix)\(label)\(description)\(selected)".lightBlack)
        }
      }
      
      // Print instructions
      print("")
      print(" " + "↑/↓: Navigate  •  Enter: Select".lightBlack, terminator: "")
      if allowCancel {
        print("  •  Esc/q: Cancel".lightBlack, terminator: "")
      }
      print("")
      
      // Read key press
      guard let key = readKey() else { continue }
      
      switch key {
      case .up:
        selectedIndex = selectedIndex > 0 ? selectedIndex - 1 : options.count - 1
      case .down:
        selectedIndex = selectedIndex < options.count - 1 ? selectedIndex + 1 : 0
      case .enter:
        clearSelectionUI(lineCount: options.count + 7)
        return options[selectedIndex].value
      case .escape, .char("q"):
        if allowCancel {
          clearSelectionUI(lineCount: options.count + 7)
          return nil
        }
      default:
        break
      }
    }
  }
  
  /// Clear the selection UI
  private static func clearSelectionUI(lineCount: Int) {
    // Move cursor up and clear lines
    for _ in 0..<lineCount {
      print("\u{001B}[1A\u{001B}[2K", terminator: "")
    }
  }
  
  /// Key press types
  private enum Key {
    case up, down, left, right, enter, escape, char(Character), unknown
  }
  
  /// Read a single key press
  private static func readKey() -> Key? {
    var buffer = [UInt8](repeating: 0, count: 3)
    let bytesRead = read(STDIN_FILENO, &buffer, 3)
    
    guard bytesRead > 0 else { return nil }
    
    // Check for escape sequences
    if buffer[0] == 27 {  // ESC
      if bytesRead == 1 {
        return .escape
      }
      if buffer[1] == 91 {  // [
        switch buffer[2] {
        case 65: return .up     // Up arrow
        case 66: return .down   // Down arrow
        case 67: return .right  // Right arrow
        case 68: return .left   // Left arrow
        default: return .unknown
        }
      }
    }
    
    // Check for enter/return
    if buffer[0] == 10 || buffer[0] == 13 {
      return .enter
    }
    
    // Check for regular characters
    let scalar = UnicodeScalar(buffer[0])
    return .char(Character(scalar))
  }
  
  /// Disable terminal echo for raw input
  private static func disableEcho() {
    #if canImport(Darwin) || canImport(Glibc)
    var term = termios()
    tcgetattr(STDIN_FILENO, &term)
    term.c_lflag &= ~(UInt(ICANON) | UInt(ECHO))
    tcsetattr(STDIN_FILENO, TCSANOW, &term)
    #endif
  }
  
  /// Re-enable terminal echo
  private static func enableEcho() {
    #if canImport(Darwin) || canImport(Glibc)
    var term = termios()
    tcgetattr(STDIN_FILENO, &term)
    term.c_lflag |= (UInt(ICANON) | UInt(ECHO))
    tcsetattr(STDIN_FILENO, TCSANOW, &term)
    #endif
  }
}