import Foundation
import Rainbow
#if canImport(Darwin)
import Darwin
import Darwin.POSIX.termios
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
    
    // Get terminal width
    let terminalWidth = getTerminalWidth()
    let maxLineWidth = min(terminalWidth - 4, 80)  // Leave margin, cap at 80 chars
    
    // Calculate total lines
    let totalLines = 4 + options.count + 2  // 1 blank + title + sep + blank + options + blank + instructions
    
    // Main loop - redraw everything each time (simpler and more reliable)
    var firstDraw = true
    
    while true {
      // Clear and redraw entire UI
      if firstDraw {
        // First draw - no clearing needed
        firstDraw = false
      } else {
        // Move cursor up to top of UI
        for _ in 0..<totalLines {
          print("\u{001B}[1A", terminator: "")
        }
      }
      
      // Draw UI - clear each line before printing
      print("\r\u{001B}[2K", terminator: "")
      print("")  // Blank line
      print("\r\u{001B}[2K " + title.cyan.bold)
      let underlineLength = min(title.count + 10, maxLineWidth)
      print("\r\u{001B}[2K " + String(repeating: "─", count: underlineLength).lightBlack)
      print("\r\u{001B}[2K")  // Empty line after separator
      
      // Print options
      for (index, option) in options.enumerated() {
        let prefix = index == selectedIndex ? " > " : "   "
        let label = option.label
        let checkmark = option.isSelected ? " [x]" : ""
        
        var line = "\(prefix)\(label)\(checkmark)"
        
        if let desc = option.description {
          let availableSpace = maxLineWidth - line.count - 3
          if availableSpace > 10 {
            let truncatedDesc = desc.count > availableSpace ? 
              String(desc.prefix(availableSpace - 3)) + "..." : desc
            line += " - \(truncatedDesc)"
          }
        }
        
        if line.count > maxLineWidth {
          line = String(line.prefix(maxLineWidth - 3)) + "..."
        }
        
        print("\r\u{001B}[2K", terminator: "")
        if index == selectedIndex {
          print(line.cyan.bold)
        } else {
          print(line.lightBlack)
        }
      }
      
      // Print instructions
      print("\r\u{001B}[2K")  // Empty line before instructions
      let instructions = " ↑/↓: Navigate  •  Enter: Select" + (allowCancel ? "  •  Esc/q: Cancel" : "")
      let truncatedInstructions = instructions.count > maxLineWidth ? 
        String(instructions.prefix(maxLineWidth)) : instructions
      print("\r\u{001B}[2K" + truncatedInstructions.lightBlack)
      
      // Read key press
      guard let key = readKey() else { continue }
      
      switch key {
      case .up:
        selectedIndex = selectedIndex > 0 ? selectedIndex - 1 : options.count - 1
        
      case .down:
        selectedIndex = selectedIndex < options.count - 1 ? selectedIndex + 1 : 0
        
      case .enter:
        // Clear UI before returning
        for _ in 0..<totalLines {
          print("\u{001B}[1A\u{001B}[2K", terminator: "")
        }
        return options[selectedIndex].value
        
      case .escape, .char("q"):
        if allowCancel {
          // Clear UI before returning
          for _ in 0..<totalLines {
            print("\u{001B}[1A\u{001B}[2K", terminator: "")
          }
          return nil
        }
        
      default:
        break
      }
    }
  }
  
  /// Get terminal width
  private static func getTerminalWidth() -> Int {
    #if canImport(Darwin) || canImport(Glibc)
    var winsize = winsize()
    if ioctl(STDOUT_FILENO, UInt(TIOCGWINSZ), &winsize) == 0 {
      return Int(winsize.ws_col)
    }
    #endif
    return 80  // Default fallback
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