import Foundation
import Rainbow

struct TerminalUI {
  
  static func showInteractiveHelp() {
    print("\nCommands:".cyan.bold)
    print("  exit, quit   - Exit ISA".lightBlack)
    print("  clear        - Clear screen and show banner".lightBlack)
    print("  todos        - Show current todo list".lightBlack)
    print("  help         - Show this help message".lightBlack)
    print("\nTips:".cyan.bold)
    print("  • Be specific for best results".lightBlack)
    print("  • Create 'isa.md' for project context".lightBlack)
    print("  • Use --plan mode for complex tasks\n".lightBlack)
  }
  
  static func showPrompt() {
    print("> ".cyan.bold, terminator: "")
    fflush(stdout)
  }
  
  static func showThinking() {
    print("🤔 Thinking...".yellow)
  }
  
  static func showWorking(on task: String) {
    print("⚡ \(task)".cyan)
  }
  
  static func showSuccess(_ message: String) {
    print("✅ \(message)".green)
  }
  
  static func showError(_ message: String) {
    print("❌ \(message)".red)
  }
  
  static func showWarning(_ message: String) {
    print("⚠️  \(message)".yellow)
  }
  
  static func showGoodbye() {
    print("\nGoodbye! Thanks for using ISA 👋".yellow)
  }
  
  static func showCancelled() {
    print("Plan cancelled.".red)
  }
  
  static func clearScreen() {
    print("\u{001B}[2J\u{001B}[H", terminator: "")
  }
  
  // MARK: - Plan Mode
  
  static func showPlan(_ plan: String) {
    print("\n📋 ".cyan.bold + "Execution Plan:".cyan.bold)
    print("─────────────────────────────".lightBlack)
    print(plan)
    print("─────────────────────────────".lightBlack)
  }
  
  static func confirmPlan() -> Bool {
    print("\nProceed with this plan? ".yellow.bold + "(y/n): ".yellow, terminator: "")
    fflush(stdout)
    
    guard let response = readLine()?.lowercased() else {
      return false
    }
    
    return response == "y" || response == "yes"
  }
  
  // MARK: - Todo List Display
  
  static func showTodo(_ todo: Todo) {
    let icon: String
    let color: (String) -> String
    
    switch todo.status {
    case .completed:
      icon = "✓"
      color = { $0.green }
    case .inProgress:
      icon = "•"
      color = { $0.yellow }
    case .pending:
      icon = "○"
      color = { $0.lightBlack }
    }
    
    print(color("\(icon) \(todo.content)"))
  }
  
  static func showTodoList(_ todoList: TodoList) {
    guard !todoList.todos.isEmpty else {
      print("\nNo todos yet.".lightBlack)
      return
    }
    
    print("\n📋 ".cyan.bold + "Todo List:".cyan.bold)
    print("─────────────────────────────".lightBlack)
    
    // Group by status
    let inProgress = todoList.inProgress
    let pending = todoList.pending
    let completed = todoList.completed
    
    if !inProgress.isEmpty {
      print("\nIn Progress:".yellow.bold)
      for todo in inProgress {
        showTodo(todo)
      }
    }
    
    if !pending.isEmpty {
      print("\nPending:".lightBlack.bold)
      for todo in pending {
        showTodo(todo)
      }
    }
    
    if !completed.isEmpty {
      print("\nCompleted:".green.bold)
      for todo in completed {
        showTodo(todo)
      }
    }
    
    print("─────────────────────────────".lightBlack)
    let summary = "\(pending.count) pending, \(inProgress.count) in progress, \(completed.count) completed"
    print(summary.lightBlack)
  }
  
  static func showTodoSummary(_ todoList: TodoList) {
    let pending = todoList.pending.count
    let inProgress = todoList.inProgress.count
    let completed = todoList.completed.count
    
    if pending > 0 || inProgress > 0 {
      print("\n📊 Progress: ".cyan.bold, terminator: "")
      
      if completed > 0 {
        print("\(completed) completed".green, terminator: "")
      }
      
      if inProgress > 0 {
        if completed > 0 { print(", ", terminator: "") }
        print("\(inProgress) in progress".yellow, terminator: "")
      }
      
      if pending > 0 {
        if completed > 0 || inProgress > 0 { print(", ", terminator: "") }
        print("\(pending) pending".lightBlack, terminator: "")
      }
      
      print()
    }
  }
  
  // MARK: - Progress Indicators
  
  static func showProgress(_ message: String, current: Int, total: Int) {
    let percentage = Int((Double(current) / Double(total)) * 100)
    let barLength = 20
    let filled = Int((Double(current) / Double(total)) * Double(barLength))
    
    var bar = "["
    for i in 0..<barLength {
      if i < filled {
        bar += "█"
      } else {
        bar += "░"
      }
    }
    bar += "]"
    
    print("\r\(message): \(bar) \(percentage)%".cyan, terminator: "")
    fflush(stdout)
    
    if current >= total {
      print() // New line when complete
    }
  }
}


import Foundation
import Rainbow

extension TerminalUI {
  /// Shows Grok banner when using xAI provider - monochrome
  static func showGrokBanner(
    title: String = "", 
    subtitle: String = "",
    useTrueColor: Bool? = nil
  ) {
    clearScreen()
    
    // Clean GROK text in block letters
    let art = """
    
     ██████╗ ██████╗  ██████╗ ██╗  ██╗
    ██╔════╝ ██╔══██╗██╔═══██╗██║ ██╔╝
    ██║  ███╗██████╔╝██║   ██║█████╔╝ 
    ██║   ██║██╔══██╗██║   ██║██╔═██╗ 
    ╚██████╔╝██║  ██║╚██████╔╝██║  ██╗
     ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝
    """
    
    // Print all letters in medium gray
    let lines = art.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    
    for line in lines {
      var colored = ""
      for ch in line {
        let s = String(ch)
        if s == " " { 
          colored += s
        } else {
          colored += s.lightBlack  // Medium gray for all characters
        }
      }
      print(colored)
    }
    
    // Don't print title or subtitle if empty
    if !title.isEmpty {
      print(title.lightBlack)
    }
    if !subtitle.isEmpty {
      print(subtitle.lightBlack)
    }
    print() // spacing
  }
  
  /// Ultra rainbow banner with per-character HSL sweep
  static func showISABanner(
    title: String = "Intelligent Software Assistant",
    subtitle: String = "Powered by SwiftOpenAI CLI",
    useTrueColor: Bool? = nil
  ) {
    clearScreen()
    
    // Big block art for ISA (11 lines tall)
    let art = """
    
    ██╗███████╗ █████╗     ██████╗ ██╗     ██╗                                
    ██║██╔════╝██╔══██╗   ██╔════╝ ██║     ██║                                
    ██║███████╗███████║   ██║      ██║     ██║                                
    ██║╚════██║██╔══██║   ██║      ██║     ██║                                
    ██║███████║██║  ██║   ╚██████╗ ███████╗██║                                
    ╚═╝╚══════╝╚═╝  ╚═╝    ╚═════╝ ╚══════╝╚═╝ 
    """
    
    let target: HexColorTarget = {
      if let explicit = useTrueColor { return explicit ? .bit24 : .bit8Approximated }
      let env = ProcessInfo.processInfo.environment
      let colorterm = (env["COLORTERM"] ?? "").lowercased()
      let term = (env["TERM"] ?? "").lowercased()
      let truecolor = colorterm.contains("truecolor") || colorterm.contains("24bit") || term.contains("truecolor")
      return truecolor ? .bit24 : .bit8Approximated
    }()
    
    // Use a color scheme that works in both light and dark modes
    // Slightly darker colors with high saturation
    printRainbowArt(
      art,
      bold: false,
      shadowOffset: nil,
      saturation: 90.0,
      lightness: 50.0,  // Medium lightness works in both modes
      lineHueShift: 10,
      target: target,
      isLightMode: false
    )
    
    // Title and subtitle - use terminal's default color (no formatting)
    // This will be black in light terminals and white in dark terminals
    print(title)
    print(subtitle)
    print() // spacing
  }
  
  // MARK: - Rendering helpers
  
  /// Renders multi-line ASCII art with a per-character HSL hue sweep.
  /// - Parameters:
  ///   - art: The ASCII art block.
  ///   - shadowOffset: Optional (x,y) offset for a subtle drop shadow.
  ///   - lineHueShift: Additional hue shift per line for diagonal gradients.
  private static func printRainbowArt(
    _ art: String,
    bold: Bool = true,
    shadowOffset: (x: Int, y: Int)? = nil,
    saturation: Double = 95,
    lightness: Double = 60,
    lineHueShift: Double = 8,
    target: HexColorTarget = .bit8Approximated,
    isLightMode: Bool = false
  ) {
    let lines = art.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    let width = max(1, lines.map { $0.count }.max() ?? 1)
    
    // Optional drop shadow (light gray block mask)
    if let off = shadowOffset {
      for _ in 0..<off.y { print("") }
      for raw in lines {
        // Replace visible chars with a heavy block for a nice soft shadow
        let shadowMask = raw.replacingOccurrences(
          of: #"[^ \t]"#,
          with: "█",
          options: .regularExpression
        )
        print(String(repeating: " ", count: off.x) + shadowMask.lightBlack)
      }
    }
    
    // Colorized art
    for (row, raw) in lines.enumerated() {
      var colored = ""
      let chars = Array(raw)
      for (col, ch) in chars.enumerated() {
        let s = String(ch)
        if s == " " { colored += s; continue }
        
        // Hue sweeps across columns, with a small per-line shift for a diagonal gradient
        let baseHue = (Double(col) / Double(width)) * 360.0
        let hue = fmod(baseHue + Double(row) * lineHueShift, 360.0)
        
        var piece = s.hsl(hue, saturation, lightness, to: target)
        if bold { piece = piece.bold }
        colored += piece
      }
      print(colored)
    }
  }
  /// Single-line rainbow gradient text (for titles/subtitles).
  private static func printGradientText(
    _ text: String,
    target: HexColorTarget = .bit8Approximated,
    bold: Bool = false,
    saturation: Double = 92,
    lightness: Double = 70
  ) {
    let chars = Array(text)
    let count = max(1, chars.count)
    var out = ""
    for (i, c) in chars.enumerated() {
      let hue = (Double(i) / Double(count)) * 360.0
      var piece = String(c).hsl(hue, saturation, lightness, to: target)
      if bold { piece = piece.bold }
      out += piece
    }
    print(out)
  }
}

