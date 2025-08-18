import Foundation
import SwiftOpenAI

struct DateTimeTool: CLITool {
  let name = "datetime"
  let description = "Get current date and time information or perform date calculations"
  
  var parameters: JSONSchema {
    return JSONSchema(
      type: .object,
      properties: [
        "operation": JSONSchema(
          type: .string,
          description: "Operation to perform: 'current' for current date/time, 'add_days' to add days to current date, 'format' to format current date",
          enum: ["current", "add_days", "format"]
        ),
        "days": JSONSchema(
          type: .optional(.integer),
          description: "Number of days to add (only used with add_days operation)"
        ),
        "format": JSONSchema(
          type: .optional(.string),
          description: "Date format string (only used with format operation). e.g., 'yyyy-MM-dd', 'MMM d, yyyy'"
        )
      ],
      required: ["operation", "days", "format"]
    )
  }
  
  func execute(arguments: String) async throws -> String {
    // Parse JSON arguments with better error handling
    guard let data = arguments.data(using: .utf8) else {
      return "Error: Invalid arguments encoding"
    }
    
    let json: [String: Any]
    do {
      guard let parsedJson = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        return "Error: Arguments must be a JSON object"
      }
      json = parsedJson
    } catch {
      return "Error: Invalid JSON arguments - \(error.localizedDescription)"
    }
    
    guard let operation = json["operation"] as? String else {
      return "Error: Missing required 'operation' field. Must be one of: current, add_days, format"
    }
    
    let now = Date()
    let formatter = DateFormatter()
    formatter.dateStyle = .full
    formatter.timeStyle = .medium
    formatter.locale = Locale.current
    formatter.timeZone = TimeZone.current
    
    switch operation {
    case "current":
      return "Current date and time: \(formatter.string(from: now)) (Timezone: \(TimeZone.current.identifier))"
      
    case "add_days":
      // Try to get days from various possible types
      let days: Int
      if let intDays = json["days"] as? Int {
        days = intDays
      } else if let doubleDays = json["days"] as? Double {
        days = Int(doubleDays)
      } else if let stringDays = json["days"] as? String, let intDays = Int(stringDays) {
        days = intDays
      } else {
        return "Error: 'add_days' operation requires 'days' parameter as a number"
      }
      
      let calendar = Calendar.current
      if let futureDate = calendar.date(byAdding: .day, value: days, to: now) {
        return "Date after adding \(days) days: \(formatter.string(from: futureDate))"
      } else {
        return "Error: Could not calculate date"
      }
      
    case "format":
      guard let formatString = json["format"] as? String else {
        // Provide default format if not specified
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return "Formatted date (default format): \(formatter.string(from: now))"
      }
      
      // Validate format string
      guard !formatString.isEmpty else {
        return "Error: 'format' parameter cannot be empty"
      }
      
      formatter.dateFormat = formatString
      return "Formatted date: \(formatter.string(from: now))"
      
    default:
      return "Error: Unknown operation '\(operation)'. Valid operations are: current, add_days, format"
    }
  }
}
