import Foundation
import Markdown
import Rainbow

/// A visitor that renders Markdown to terminal-formatted text with ANSI colors
public struct TerminalMarkdownRenderer: MarkupWalker {
  private var output = ""
  private var indentLevel = 0
  private var listCounter = 0
  private var isInCodeBlock = false
  private var codeLanguage: String?
  
  public init() {}
  
  public mutating func render(_ document: Document) -> String {
    output = ""
    visit(document)
    return output
  }
  
  // MARK: - Block Elements
  
  public mutating func visitHeading(_ heading: Heading) -> () {
    let level = heading.level
    let text = heading.plainText
    
    switch level {
    case 1:
      output += "\n\(text.bold.cyan)\n" + String(repeating: "═", count: text.count).cyan + "\n"
    case 2:
      output += "\n\(text.bold.green)\n" + String(repeating: "─", count: text.count).green + "\n"
    case 3:
      output += "\n\(text.bold.yellow)\n"
    default:
      output += "\n\(text.bold)\n"
    }
  }
  
  public mutating func visitParagraph(_ paragraph: Paragraph) -> () {
    descendInto(paragraph)
    output += "\n"
  }
  
  public mutating func visitCodeBlock(_ codeBlock: CodeBlock) -> () {
    isInCodeBlock = true
    codeLanguage = codeBlock.language
    
    let lines = codeBlock.code.split(separator: "\n", omittingEmptySubsequences: false)
    let maxLineNumWidth = String(lines.count).count
    
    // Code block header
    if let lang = codeLanguage, !lang.isEmpty {
      output += "\n┌─ \(lang) ".lightBlack
      output += String(repeating: "─", count: max(0, 60 - lang.count - 4)).lightBlack + "┐\n".lightBlack
    } else {
      output += "\n┌".lightBlack + String(repeating: "─", count: 60).lightBlack + "┐\n".lightBlack
    }
    
    // Code lines with syntax highlighting
    for (index, line) in lines.enumerated() {
      let lineNum = String(format: "%\(maxLineNumWidth)d", index + 1)
      output += "│ ".lightBlack
      output += lineNum.lightBlack + " │ ".lightBlack
      output += applySyntaxHighlighting(String(line), language: codeLanguage)
      output += "\n"
    }
    
    // Code block footer
    output += "└".lightBlack + String(repeating: "─", count: 60).lightBlack + "┘\n".lightBlack
    
    isInCodeBlock = false
    codeLanguage = nil
  }
  
  public mutating func visitInlineCode(_ inlineCode: InlineCode) -> () {
    output += " `\(inlineCode.code)` ".lightCyan.onBlack
  }
  
  public mutating func visitBlockQuote(_ quote: BlockQuote) -> () {
    let oldOutput = output
    output = ""
    descendInto(quote)
    let quotedText = output
    output = oldOutput
    
    for line in quotedText.split(separator: "\n", omittingEmptySubsequences: false) {
      output += "│ ".lightBlack + String(line).italic + "\n"
    }
  }
  
  public mutating func visitUnorderedList(_ list: UnorderedList) -> () {
    indentLevel += 1
    descendInto(list)
    indentLevel -= 1
    if indentLevel == 0 {
      output += "\n"
    }
  }
  
  public mutating func visitOrderedList(_ list: OrderedList) -> () {
    indentLevel += 1
    listCounter = Int(list.startIndex)
    descendInto(list)
    indentLevel -= 1
    listCounter = 0
    if indentLevel == 0 {
      output += "\n"
    }
  }
  
  public mutating func visitListItem(_ listItem: ListItem) -> () {
    let indent = String(repeating: "  ", count: max(0, indentLevel - 1))
    
    if listCounter > 0 {
      output += "\(indent)\(listCounter). ".cyan
      listCounter += 1
    } else {
      let bullet = indentLevel == 1 ? "•" : "◦"
      output += "\(indent)\(bullet) ".cyan
    }
    
    let oldOutput = output
    output = ""
    descendInto(listItem)
    let itemText = output.trimmingCharacters(in: .whitespacesAndNewlines)
    output = oldOutput + itemText + "\n"
  }
  
  // MARK: - Inline Elements
  
  public mutating func visitText(_ text: Text) -> () {
    if !isInCodeBlock {
      output += text.string
    }
  }
  
  public mutating func visitEmphasis(_ emphasis: Emphasis) -> () {
    let oldOutput = output
    output = ""
    descendInto(emphasis)
    let emphText = output
    output = oldOutput + emphText.italic
  }
  
  public mutating func visitStrong(_ strong: Strong) -> () {
    let oldOutput = output
    output = ""
    descendInto(strong)
    let strongText = output
    output = oldOutput + strongText.bold
  }
  
  public mutating func visitLink(_ link: Link) -> () {
    let linkText = link.plainText
    let destination = link.destination ?? ""
    output += "\(linkText)".blue.underline + " (\(destination))".lightBlack
  }
  
  public mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) -> () {
    output += "\n" + String(repeating: "─", count: 60).lightBlack + "\n"
  }
  
  // MARK: - Syntax Highlighting
  
  private func applySyntaxHighlighting(_ code: String, language: String?) -> String {
    guard let lang = language?.lowercased() else {
      return code
    }
    
    // Try to use bat first if available
    if let batHighlighted = tryBatHighlighting(code, language: lang) {
      return batHighlighted
    }
    
    // Fall back to basic syntax highlighting
    switch lang {
    case "swift", "swift-diff":
      return highlightSwift(code, isDiff: lang.contains("diff"))
    case "python", "py":
      return highlightPython(code)
    case "javascript", "js", "jsx", "typescript", "ts", "tsx":
      return highlightJavaScript(code)
    case "bash", "sh", "shell":
      return highlightBash(code)
    case "json":
      return highlightJSON(code)
    case "diff":
      return highlightDiff(code)
    default:
      return code
    }
  }
  
  private func tryBatHighlighting(_ code: String, language: String) -> String? {
    // Check if bat is available
    let checkProcess = Process()
    checkProcess.executableURL = URL(fileURLWithPath: "/usr/bin/which")
    checkProcess.arguments = ["bat"]
    checkProcess.standardOutput = Pipe()
    checkProcess.standardError = Pipe()
    
    do {
      try checkProcess.run()
      checkProcess.waitUntilExit()
      
      guard checkProcess.terminationStatus == 0 else { return nil }
      
      // Run bat for syntax highlighting
      let batProcess = Process()
      batProcess.executableURL = URL(fileURLWithPath: "/usr/bin/env")
      batProcess.arguments = [
        "bat",
        "--color=always",
        "--style=plain",
        "--language", mapLanguageToBat(language),
        "--theme=TwoDark",
        "--paging=never"
      ]
      
      let inputPipe = Pipe()
      let outputPipe = Pipe()
      batProcess.standardInput = inputPipe
      batProcess.standardOutput = outputPipe
      batProcess.standardError = Pipe()
      
      try batProcess.run()
      
      // Write code to bat's stdin
      let inputData = code.data(using: .utf8) ?? Data()
      inputPipe.fileHandleForWriting.write(inputData)
      inputPipe.fileHandleForWriting.closeFile()
      
      batProcess.waitUntilExit()
      
      guard batProcess.terminationStatus == 0 else { return nil }
      
      // Read the highlighted output
      let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
      guard let highlightedCode = String(data: outputData, encoding: .utf8) else { return nil }
      
      // Remove any trailing newlines that bat might have added
      return highlightedCode.trimmingCharacters(in: .newlines)
      
    } catch {
      // If bat fails, return nil to use fallback
      return nil
    }
  }
  
  private func mapLanguageToBat(_ language: String) -> String {
    // Map language aliases to bat language names
    switch language {
    case "py": return "python"
    case "js": return "javascript"
    case "ts": return "typescript"
    case "jsx": return "jsx"
    case "tsx": return "tsx"
    case "sh": return "bash"
    case "shell": return "bash"
    case "swift-diff": return "swift"
    default: return language
    }
  }
  
  private func highlightSwift(_ code: String, isDiff: Bool = false) -> String {
    // Create a structure to track replacements with priority
    struct Replacement {
      let range: NSRange
      let replacement: String
      let priority: Int // Higher priority wins when ranges overlap
    }
    
    var replacements: [Replacement] = []
    let nsCode = code as NSString
    
    // Comments - single line (highest priority to prevent highlighting inside comments)
    if let regex = try? NSRegularExpression(pattern: "//.*$", options: [.anchorsMatchLines]) {
      let matches = regex.matches(in: code, options: [], range: NSRange(location: 0, length: nsCode.length))
      for match in matches {
        let matchedString = nsCode.substring(with: match.range)
        replacements.append(Replacement(range: match.range, replacement: matchedString.lightBlack.italic, priority: 100))
      }
    }
    
    // Strings - double quotes (high priority)
    if let regex = try? NSRegularExpression(pattern: "\"([^\"\\\\]|\\\\.)*\"", options: []) {
      let matches = regex.matches(in: code, options: [], range: NSRange(location: 0, length: nsCode.length))
      for match in matches {
        let matchedString = nsCode.substring(with: match.range)
        replacements.append(Replacement(range: match.range, replacement: matchedString.green, priority: 90))
      }
    }
    
    // Keywords
    let keywords = ["func", "var", "let", "class", "struct", "enum", "protocol", 
                   "import", "return", "if", "else", "guard", "switch", "case",
                   "for", "while", "do", "try", "catch", "throw", "async", "await",
                   "public", "private", "internal", "static", "final", "override",
                   "init", "deinit", "self", "Self", "nil", "true", "false"]
    
    for keyword in keywords {
      let pattern = "\\b\(keyword)\\b"
      if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
        let matches = regex.matches(in: code, options: [], range: NSRange(location: 0, length: nsCode.length))
        for match in matches {
          let matchedString = nsCode.substring(with: match.range)
          replacements.append(Replacement(range: match.range, replacement: matchedString.magenta.bold, priority: 50))
        }
      }
    }
    
    // Types (capitalized words)
    if let regex = try? NSRegularExpression(pattern: "\\b[A-Z][A-Za-z0-9]*\\b", options: []) {
      let matches = regex.matches(in: code, options: [], range: NSRange(location: 0, length: nsCode.length))
      for match in matches {
        let matchedString = nsCode.substring(with: match.range)
        // Check if it's not already a highlighted keyword
        let isKeyword = keywords.contains { $0 == matchedString }
        if !isKeyword {
          replacements.append(Replacement(range: match.range, replacement: matchedString.cyan, priority: 40))
        }
      }
    }
    
    // Numbers
    if let regex = try? NSRegularExpression(pattern: "\\b[0-9]+\\.?[0-9]*\\b", options: []) {
      let matches = regex.matches(in: code, options: [], range: NSRange(location: 0, length: nsCode.length))
      for match in matches {
        let matchedString = nsCode.substring(with: match.range)
        replacements.append(Replacement(range: match.range, replacement: matchedString.yellow, priority: 30))
      }
    }
    
    // Remove overlapping replacements (keep highest priority)
    var finalReplacements: [Replacement] = []
    let sortedReplacements = replacements.sorted { $0.range.location < $1.range.location }
    
    for replacement in sortedReplacements {
      var shouldAdd = true
      for existing in finalReplacements {
        let existingRange = existing.range
        let newRange = replacement.range
        
        // Check if ranges overlap
        if NSLocationInRange(newRange.location, existingRange) ||
           NSLocationInRange(existingRange.location, newRange) ||
           NSLocationInRange(NSMaxRange(newRange) - 1, existingRange) ||
           NSLocationInRange(NSMaxRange(existingRange) - 1, newRange) {
          // Keep the one with higher priority
          if replacement.priority <= existing.priority {
            shouldAdd = false
            break
          }
        }
      }
      
      if shouldAdd {
        // Remove any lower priority overlapping replacements
        finalReplacements.removeAll { existing in
          let existingRange = existing.range
          let newRange = replacement.range
          return (NSLocationInRange(newRange.location, existingRange) ||
                  NSLocationInRange(existingRange.location, newRange) ||
                  NSLocationInRange(NSMaxRange(newRange) - 1, existingRange) ||
                  NSLocationInRange(NSMaxRange(existingRange) - 1, newRange)) &&
                 existing.priority < replacement.priority
        }
        finalReplacements.append(replacement)
      }
    }
    
    // Sort replacements by location in reverse to avoid offset issues
    finalReplacements.sort { $0.range.location > $1.range.location }
    
    // Apply replacements
    var highlighted = code
    for replacement in finalReplacements {
      if let swiftRange = Range(replacement.range, in: highlighted) {
        highlighted.replaceSubrange(swiftRange, with: replacement.replacement)
      }
    }
    
    if isDiff {
      highlighted = applyDiffHighlighting(highlighted)
    }
    
    return highlighted
  }
  
  private func highlightPython(_ code: String) -> String {
    var highlighted = code
    
    let keywords = ["def", "class", "import", "from", "return", "if", "elif", "else",
                   "for", "while", "break", "continue", "try", "except", "finally",
                   "with", "as", "lambda", "yield", "global", "nonlocal", "pass",
                   "True", "False", "None", "and", "or", "not", "in", "is"]
    
    for keyword in keywords {
      highlighted = highlighted.replacingOccurrences(
        of: "\\b\(keyword)\\b",
        with: keyword.magenta.bold,
        options: .regularExpression
      )
    }
    
    highlighted = highlightStrings(highlighted)
    highlighted = highlightComments(highlighted, commentPrefix: "#")
    highlighted = highlightNumbers(highlighted)
    
    return highlighted
  }
  
  private func highlightJavaScript(_ code: String) -> String {
    var highlighted = code
    
    let keywords = ["function", "const", "let", "var", "class", "extends", "import",
                   "export", "default", "return", "if", "else", "switch", "case",
                   "for", "while", "do", "try", "catch", "finally", "throw",
                   "async", "await", "new", "this", "super", "null", "undefined",
                   "true", "false", "typeof", "instanceof", "delete", "void"]
    
    for keyword in keywords {
      highlighted = highlighted.replacingOccurrences(
        of: "\\b\(keyword)\\b",
        with: keyword.magenta.bold,
        options: .regularExpression
      )
    }
    
    highlighted = highlightStrings(highlighted)
    highlighted = highlightComments(highlighted)
    highlighted = highlightNumbers(highlighted)
    
    return highlighted
  }
  
  private func highlightBash(_ code: String) -> String {
    var highlighted = code
    
    // Commands (first word of line or after pipe/semicolon)
    highlighted = highlighted.replacingOccurrences(
      of: "(^|\\||;|&&|\\|\\|)\\s*([a-zA-Z][a-zA-Z0-9_-]*)",
      with: "$1 $2".green,
      options: .regularExpression
    )
    
    // Variables
    highlighted = highlighted.replacingOccurrences(
      of: "\\$[a-zA-Z_][a-zA-Z0-9_]*",
      with: "$0".cyan,
      options: .regularExpression
    )
    
    // Flags
    highlighted = highlighted.replacingOccurrences(
      of: "\\s(-{1,2}[a-zA-Z][a-zA-Z0-9-]*)",
      with: " $1".yellow,
      options: .regularExpression
    )
    
    highlighted = highlightStrings(highlighted)
    highlighted = highlightComments(highlighted, commentPrefix: "#")
    
    return highlighted
  }
  
  private func highlightJSON(_ code: String) -> String {
    var highlighted = code
    
    // Keys (quoted strings followed by colon)
    highlighted = highlighted.replacingOccurrences(
      of: "\"([^\"]+)\"\\s*:",
      with: "\"$1\"".cyan + ":",
      options: .regularExpression
    )
    
    // String values
    highlighted = highlighted.replacingOccurrences(
      of: ":\\s*\"([^\"]+)\"",
      with: ": \"$1\"".green,
      options: .regularExpression
    )
    
    // Numbers
    highlighted = highlightNumbers(highlighted)
    
    // Booleans and null
    highlighted = highlighted.replacingOccurrences(
      of: "\\b(true|false|null)\\b",
      with: "$0".magenta,
      options: .regularExpression
    )
    
    return highlighted
  }
  
  private func highlightDiff(_ code: String) -> String {
    return applyDiffHighlighting(code)
  }
  
  private func applyDiffHighlighting(_ code: String) -> String {
    let lines = code.split(separator: "\n", omittingEmptySubsequences: false)
    var result: [String] = []
    
    for line in lines {
      let lineStr = String(line)
      if lineStr.hasPrefix("+") {
        result.append(lineStr.green)
      } else if lineStr.hasPrefix("-") {
        result.append(lineStr.red)
      } else if lineStr.hasPrefix("@@ ") {
        result.append(lineStr.cyan.bold)
      } else {
        result.append(lineStr)
      }
    }
    
    return result.joined(separator: "\n")
  }
  
  private func highlightStrings(_ code: String) -> String {
    var highlighted = code
    
    // Double-quoted strings
    highlighted = highlighted.replacingOccurrences(
      of: "\"([^\"\\\\]|\\\\.)*\"",
      with: "$0".green,
      options: .regularExpression
    )
    
    // Single-quoted strings
    highlighted = highlighted.replacingOccurrences(
      of: "'([^'\\\\]|\\\\.)*'",
      with: "$0".green,
      options: .regularExpression
    )
    
    return highlighted
  }
  
  private func highlightComments(_ code: String, commentPrefix: String = "//") -> String {
    var highlighted = code
    
    // Single-line comments
    let pattern = "\(NSRegularExpression.escapedPattern(for: commentPrefix)).*$"
    highlighted = highlighted.replacingOccurrences(
      of: pattern,
      with: "$0".lightBlack.italic,
      options: [.regularExpression, .anchored]
    )
    
    return highlighted
  }
  
  private func highlightNumbers(_ code: String) -> String {
    return code.replacingOccurrences(
      of: "\\b[0-9]+\\.?[0-9]*\\b",
      with: "$0".yellow,
      options: .regularExpression
    )
  }
}

// MARK: - Convenience Extension

extension Document {
  /// Renders the markdown document to terminal-formatted text
  public func renderToTerminal() -> String {
    var renderer = TerminalMarkdownRenderer()
    return renderer.render(self)
  }
}