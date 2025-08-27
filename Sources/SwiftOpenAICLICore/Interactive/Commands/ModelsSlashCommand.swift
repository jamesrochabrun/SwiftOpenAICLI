import Foundation
import Rainbow

/// Slash command for selecting AI models
public class ModelsSlashCommand: SlashCommand {
  public let name = "models"
  public let description = "List and select available AI models"
  public let argumentHint: String? = "[model-name]"
  
  private let customModelOption = "__custom__"
  
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
    // Get models based on current provider
    let models = getAvailableModels()
    
    // Create options for selection UI
    var options = models.map { model in
      let isSelected = model.id == context.currentModel
      return SelectionUI.Option(
        value: model.id,
        label: model.id,
        description: model.description,
        isSelected: isSelected
      )
    }
    
    // Add custom model option at the end
    options.append(SelectionUI.Option(
      value: customModelOption,
      label: "Custom model...",
      description: "Enter a custom model name",
      isSelected: false
    ))
      
    // Show selection UI
    if let selected = SelectionUI.select(
      title: "Select Model",
      options: options,
      currentValue: context.currentModel,
      allowCancel: true
    ) {
      // Handle custom model input
      if selected == customModelOption {
        print("\nEnter custom model name: ".cyan, terminator: "")
        guard let customModel = readLine()?.trimmingCharacters(in: .whitespaces),
              !customModel.isEmpty else {
          print("Model selection cancelled".yellow)
          return true
        }
        
        // Update the context with custom model
        context.currentModel = customModel
        print("✅ Model changed to: \(customModel)".green)
        print("   Using custom model".lightBlack)
        
        // Save to configuration
        try? ConfigurationManager.shared.set("default-model", value: customModel)
      } else {
        // Update the context with selected preset model
        context.currentModel = selected
        
        print("✅ Model changed to: \(selected)".green)
        
        // Show model description
        if let description = getModelDescription(selected) {
          print("   \(description)".lightBlack)
        } else {
          print("   This will be used for all subsequent messages".lightBlack)
        }
        
        // Save to configuration
        try? ConfigurationManager.shared.set("default-model", value: selected)
      }
      
      return true
    } else {
      print("Model selection cancelled".yellow)
      return true
    }
  }
  
  private func setModel(_ modelName: String, context: inout CommandContext) async throws -> Bool {
    // Update context directly - allow any model name
    context.currentModel = modelName
    
    print("✅ Model changed to: \(modelName)".green)
    
    // Save to configuration
    try? ConfigurationManager.shared.set("default-model", value: modelName)
    
    // Show model info if it's a known model
    if let description = getModelDescription(modelName) {
      print("   \(description)".lightBlack)
    } else {
      print("   Using custom model".lightBlack)
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
    // Get the current provider from configuration
    let provider = ConfigurationManager.shared.provider?.lowercased() ?? "openai"
    
    // Get provider-specific models from ProviderPresets
    if let providerInfo = ProviderPresets.provider(for: provider) {
      let models = providerInfo.availableModels
      
      // Create ModelInfo based on provider
      switch provider {
      case "openai":
        return models.map { model in
          let description: String
          switch model {
          case "gpt-5":
            description = "Latest model • Advanced reasoning"
          case "gpt-5-mini":
            description = "Efficient GPT-5 • Cost-effective"
          case "gpt-4o":
            description = "128k context • Advanced capabilities"
          case "gpt-4o-mini":
            description = "128k context • Fast & efficient"
          case "o1-preview":
            description = "Reasoning model • Preview"
          case "o1-mini":
            description = "Reasoning model • Efficient"
          default:
            description = "OpenAI model"
          }
          return ModelInfo(id: model, description: description)
        }
        
      case "xai":
        return models.map { model in
          let description: String
          switch model {
          case "grok-4-0709":
            description = "Grok-4 • Language model"
          case "grok-3":
            description = "Grok-3 • General purpose"
          case "grok-3-mini":
            description = "Grok-3 Mini • Efficient"
          case "grok-code-fast-1":
            description = "Fast code generation • Optimized"
          case "grok-2-image-1212":
            description = "Grok-2 • Image generation"
          default:
            description = "xAI Grok model"
          }
          return ModelInfo(id: model, description: description)
        }
        
      case "groq":
        return models.map { model in
          let description: String
          switch model {
          case "llama-3.3-70b-versatile":
            description = "Llama 3.3 70B • Versatile"
          case "llama-3.2-90b-vision-preview":
            description = "Llama 3.2 90B • Vision capable"
          case "mixtral-8x7b-32768":
            description = "Mixtral MoE • 32k context"
          default:
            description = "Groq accelerated model"
          }
          return ModelInfo(id: model, description: description)
        }
        
      case "deepseek":
        return models.map { model in
          let description: String
          switch model {
          case "deepseek-chat":
            description = "General purpose chat"
          case "deepseek-coder":
            description = "Optimized for coding"
          default:
            description = "DeepSeek model"
          }
          return ModelInfo(id: model, description: description)
        }
        
      case "openrouter":
        return models.map { model in
          let description: String
          if model.contains("claude") {
            description = "Anthropic Claude via OpenRouter"
          } else if model.contains("gemini") {
            description = "Google Gemini via OpenRouter"
          } else if model.contains("llama") {
            description = "Meta Llama via OpenRouter"
          } else {
            description = "Model via OpenRouter"
          }
          return ModelInfo(id: model, description: description)
        }
        
      case "anthropic":
        return models.map { model in
          let description: String
          if model.contains("sonnet") {
            description = "Claude 3.5 Sonnet • Balanced"
          } else if model.contains("haiku") {
            description = "Claude 3.5 Haiku • Fast"
          } else {
            description = "Anthropic Claude model"
          }
          return ModelInfo(id: model, description: description)
        }
        
      default:
        // Custom provider or unknown - return empty list (only custom option will show)
        return []
      }
    }
    
    // Fallback to OpenAI models if provider not found
    return [
      ModelInfo(id: "gpt-5", description: "Latest model • Advanced reasoning"),
      ModelInfo(id: "gpt-5-mini", description: "Efficient GPT-5 • Cost-effective"),
      ModelInfo(id: "gpt-4o", description: "128k context • Advanced capabilities"),
      ModelInfo(id: "gpt-4o-mini", description: "128k context • Fast & efficient")
    ]
  }
}