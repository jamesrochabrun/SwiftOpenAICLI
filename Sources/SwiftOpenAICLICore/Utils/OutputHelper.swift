import Foundation
import Rainbow
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// Helper for managing output in different formats
public struct OutputHelper {
  
  /// Whether to use stderr for diagnostic messages
  private let useStderr: Bool
  
  /// Initialize with output format
  public init(outputFormat: String) {
    // Use stderr for JSON formats to keep stdout pure
    self.useStderr = (outputFormat == "json" || outputFormat == "stream-json")
  }
  
  /// Print a diagnostic message (goes to stderr in JSON modes)
  public func printDiagnostic(_ message: String) {
    if useStderr {
      fputs(message + "\n", stderr)
    } else {
      print(message)
    }
  }
  
  /// Print a colored diagnostic message
  public func printDiagnostic(_ message: String, color: (String) -> String) {
    let colored = useStderr ? message : color(message)
    printDiagnostic(colored)
  }
}