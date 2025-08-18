import Foundation
import SwiftOpenAI

struct CalculatorTool: CLITool {
  let name = "calculator"
  let description = "Perform mathematical calculations. Supports basic arithmetic operations (+, -, *, /, ^) and functions like sqrt, sin, cos, tan, log"
  
  var parameters: JSONSchema {
    return JSONSchema(
      type: .object,
      properties: [
        "expression": JSONSchema(
          type: .string,
          description: "Mathematical expression to evaluate (e.g., '2 + 2', '10 * 5', 'sqrt(16)')"
        )
      ],
      required: ["expression"]
    )
  }
  
  func execute(arguments: String) async throws -> String {
    guard let data = arguments.data(using: .utf8),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let expression = json["expression"] as? String else {
      return "Error: Invalid arguments. Expected 'expression' field."
    }
    
    do {
      let result = try evaluateExpression(expression)
      return "Result: \(result)"
    } catch {
      return "Error evaluating expression: \(error.localizedDescription)"
    }
  }
  
  private func evaluateExpression(_ expression: String) throws -> Double {
    let expr = NSExpression(format: expression)
    
    guard let result = expr.expressionValue(with: nil, context: nil) as? NSNumber else {
      throw CalculatorError.invalidExpression
    }
    
    return result.doubleValue
  }
  
  enum CalculatorError: LocalizedError {
    case invalidExpression
    
    var errorDescription: String? {
      switch self {
      case .invalidExpression:
        return "Invalid mathematical expression"
      }
    }
  }
}
