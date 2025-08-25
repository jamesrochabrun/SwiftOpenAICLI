import Foundation
import Rainbow

/// Slash command for selecting AI models
public class ModelsSlashCommand: SlashCommand {
  public let name = "models"
  public let description = "List and select available AI models"
  public let argumentHint: String? = "[model-name]"
  
  public init() {}
  
  public func execute(arguments: String?, context: CommandContext) async throws -> Bool {
    // If model name provided directly, try to set it
    if let modelName = arguments?.trimmingCharacters(in: .whitespaces), !modelName.isEmpty {
      return try await setModel(modelName, context: context)
    }
    
    // Otherwise show interactive selection
    return try await showModelSelection(context: context)
  }
  
  private func showModelSelection(context: CommandContext) async throws -> Bool {
    print("Fetching available models...".cyan)
    
    do {
      // Fetch available models
      let models = try await OpenAIService.shared.listModels()
      
      // Filter and sort models for display
      let chatModels = models
        .filter { model in
          // Filter for relevant chat models
          model.id.contains("gpt") || 
          model.id.contains("o1") ||
          model.id.contains("claude") ||
          model.id.contains("gemini")
        }
        .sorted { $0.id < $1.id }
      
      if chatModels.isEmpty {
        print("No chat models available".yellow)
        return true
      }
      
      // Create options for selection UI
      let options = chatModels.map { model in
        let isSelected = model.id == context.currentModel
        let description = getModelDescription(model.id)
        return SelectionUI.Option(
          value: model.id,
          label: model.id,
          description: description,
          isSelected: isSelected
        )
      }
      
      // Show selection UI
      if let selected = SelectionUI.select(
        title: "Select Model",
        options: options,
        currentValue: context.currentModel,
        allowCancel: true
      ) {
        // Update the context with new model
        var updatedContext = context
        updatedContext.currentModel = selected
        
        print("✅ Model changed to: \(selected)".green)
        
        // Save to configuration if available
        try? ConfigurationManager.shared.set("default-model", value: selected)
        
        return true
      } else {
        print("Model selection cancelled".yellow)
        return true
      }
      
    } catch {
      print("Error fetching models: \(error.localizedDescription)".red)
      
      // Fallback: show common models
      print("\n" + "Common Models:".cyan.bold)
      print("• gpt-4o-mini       - Fast, efficient model")
      print("• gpt-4o            - Advanced reasoning")
      print("• gpt-3.5-turbo     - Legacy fast model")
      print("• o1-preview        - Deep reasoning model")
      print("• o1-mini           - Efficient reasoning")
      print("\nUse: /models <model-name> to set directly".lightBlack)
      
      return true
    }
  }
  
  private func setModel(_ modelName: String, context: CommandContext) async throws -> Bool {
    // Validate model exists or is known
    let knownModels = [
      "gpt-4o-mini", "gpt-4o", "gpt-3.5-turbo", 
      "gpt-4-turbo-preview", "gpt-4-turbo",
      "o1-preview", "o1-mini", "o1",
      "gpt-5-turbo", "gpt-5-mini", "gpt-5", "gpt-5o"
    ]
    
    // Normalize model name
    let normalized = modelName.lowercased()
    
    // Find matching model
    let matchedModel = knownModels.first { $0.lowercased() == normalized } ?? modelName
    
    // Update context
    var updatedContext = context
    updatedContext.currentModel = matchedModel
    
    print("✅ Model changed to: \(matchedModel)".green)
    
    // Save to configuration
    try? ConfigurationManager.shared.set("default-model", value: matchedModel)
    
    // Show model info
    if let description = getModelDescription(matchedModel) {
      print("   \(description)".lightBlack)
    }
    
    return true
  }
  
  private func getModelDescription(_ model: String) -> String? {
    switch model.lowercased() {
    case let m where m.contains("gpt-4o-mini"):
      return "128k context • Fast & efficient"
    case let m where m.contains("gpt-4o"):
      return "128k context • Advanced capabilities"
    case let m where m.contains("gpt-3.5"):
      return "16k context • Legacy fast model"
    case let m where m.contains("o1-preview"):
      return "Deep reasoning • Slower response"
    case let m where m.contains("o1-mini"):
      return "Efficient reasoning • Balanced"
    case let m where m.contains("gpt-5"):
      return "Latest model • Advanced capabilities"
    default:
      return nil
    }
  }
}