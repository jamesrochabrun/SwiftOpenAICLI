import ArgumentParser
import Foundation
import Markdown
import Rainbow

/// Command for testing markdown rendering in terminal
public struct MarkdownCommand: AsyncParsableCommand {
  public static let configuration = CommandConfiguration(
    commandName: "markdown",
    abstract: "Test markdown rendering in terminal"
  )
  
  public init() {}
  
  @Argument(help: "Markdown file to render or inline markdown text")
  var input: String
  
  @Flag(name: .long, help: "Treat input as a file path")
  var file = false
  
  public mutating func run() async throws {
    let markdownContent: String
    
    if file {
      // Read from file
      let url = URL(fileURLWithPath: input)
      guard FileManager.default.fileExists(atPath: url.path) else {
        print("Error: File not found at \(input)".red)
        throw ExitCode.failure
      }
      markdownContent = try String(contentsOf: url)
    } else {
      // Use input as markdown content
      markdownContent = input
    }
    
    // Parse and render
    let document = Document(parsing: markdownContent)
    let rendered = document.renderToTerminal()
    
    print(rendered)
    
    // Also show some debug info if verbose
    print("\n" + "─".repeat(60).lightBlack)
    print("Debug Info:".cyan.bold)
    print("• Characters: \(markdownContent.count)".lightBlack)
    print("• Lines: \(markdownContent.split(separator: "\n").count)".lightBlack)
  }
}

// Helper extension
extension String {
  func `repeat`(_ count: Int) -> String {
    return String(repeating: self, count: max(0, count))
  }
}