import Foundation
import Markdown

/// Helper for rendering markdown content in terminal
public struct MarkdownHelper {
  
  /// Renders markdown content to terminal-formatted text if markdown rendering is enabled
  /// - Parameters:
  ///   - content: The text content to render
  ///   - renderMarkdown: Whether to render markdown (default: true)
  /// - Returns: Rendered terminal text or original content
  public static func renderIfNeeded(_ content: String, renderMarkdown: Bool = true) -> String {
    guard renderMarkdown else {
      return content
    }
    
    // Parse markdown and render to terminal
    let document = Document(parsing: content)
    return document.renderToTerminal()
  }
  
  /// Checks if content contains markdown elements worth rendering
  public static func containsMarkdown(_ content: String) -> Bool {
    // Quick checks for common markdown patterns
    let patterns = [
      "```",           // Code blocks
      "**",            // Bold
      "*",             // Italic (but not just multiplication)
      "##",            // Headers
      "- ",            // Lists
      "1. ",           // Ordered lists
      "> ",            // Blockquotes
      "`",             // Inline code
      "[",             // Links
      "![",            // Images
    ]
    
    for pattern in patterns {
      if content.contains(pattern) {
        return true
      }
    }
    
    return false
  }
  
  /// Renders markdown for streaming output
  /// This is more complex as we need to handle partial markdown
  public static func renderStreaming(_ buffer: String) -> String {
    // For now, we'll just return the buffer as-is
    // In the future, we could implement smarter partial rendering
    return buffer
  }
}