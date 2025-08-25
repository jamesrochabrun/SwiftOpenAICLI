import Foundation
import Rainbow

/// Slash command for selecting AI models
public class ModelsSlashCommand: SlashCommand {
  public let name = "models"
  public let description = "List and select available AI models"
  public let argumentHint: String? = "[model-name]"
  
  public init() {}
  
  public func execute(arguments: String?, context: inout CommandContext) async throws -> Bool {
    // If model name provided directly, try to set it
    if let modelName = arguments?.trimmingCharacters(in: .whitespaces), !modelName.isEmpty {
      return try await setModel(modelName, context: &context)
    }
    
    // Otherwise show interactive selection
    return try await showModelSelection(context: &context)
  }
  
  private func showModelSelection(context: inout CommandContext) async throws -> Bool {
    // Use curated list of models instead of API fetch
    let models = getAvailableModels()
    
    // Create options for selection UI
    let options = models.map { model in
      let isSelected = model.id == context.currentModel
      return SelectionUI.Option(
        value: model.id,
        label: model.id,
        description: model.description,
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
        context.currentModel = selected
        
        print("✅ Model changed to: \(selected)".green)
        print("   This will be used for all subsequent messages".lightBlack)
        
        // Save to configuration if available
        try? ConfigurationManager.shared.set("default-model", value: selected)
        
        return true
      } else {
        print("Model selection cancelled".yellow)
        return true
      }
      
  }
  
  private func setModel(_ modelName: String, context: inout CommandContext) async throws -> Bool {
    // Get all known models
    let knownModels = getAvailableModels().map { $0.id }
    
    // Find matching model (case-insensitive)
    let matchedModel = knownModels.first { $0.lowercased() == modelName.lowercased() } ?? modelName
    
    // Update context
    context.currentModel = matchedModel
    
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
    return getAvailableModels().first { $0.id == model }?.description
  }
  
  private struct ModelInfo {
    let id: String
    let description: String
  }
  
  private func getAvailableModels() -> [ModelInfo] {
    return [
      ModelInfo(id: "gpt-5", description: "Latest model • Advanced reasoning"),
      ModelInfo(id: "gpt-5-mini", description: "Efficient GPT-5 • Cost-effective"),
      ModelInfo(id: "gpt-5-nano", description: "Smallest GPT-5 • Ultra-fast"),
      ModelInfo(id: "gpt-4o", description: "128k context • Advanced capabilities"),
      ModelInfo(id: "gpt-4o-mini", description: "128k context • Fast & efficient")
    ]
  }
}