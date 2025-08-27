import Foundation

/// Defines preset configurations for known AI providers
public struct ProviderPresets {
  
  public struct Provider {
    let id: String
    let name: String
    let baseURL: String?
    let defaultModel: String
    let availableModels: [String]
    let envVarName: String?
    let description: String
  }
  
  public static let providers: [Provider] = [
    Provider(
      id: "openai",
      name: "OpenAI",
      baseURL: nil, // Uses default
      defaultModel: "gpt-4o",
      availableModels: ["gpt-4o", "gpt-4o-mini", "gpt-5-mini", "gpt-5", "o1-preview", "o1-mini"],
      envVarName: "OPENAI_API_KEY",
      description: "OpenAI's GPT models including GPT-4, GPT-5, and reasoning models"
    ),
    Provider(
      id: "xai",
      name: "xAI (Grok)",
      baseURL: "https://api.x.ai/v1",
      defaultModel: "grok-code-fast-1",
      availableModels: ["grok-4-latest", "grok-code-fast-1", "grok-2-latest"],
      envVarName: "XAI_API_KEY",
      description: "xAI's Grok models with function calling support"
    ),
    Provider(
      id: "groq",
      name: "Groq",
      baseURL: "https://api.groq.com/openai/v1",
      defaultModel: "llama-3.3-70b-versatile",
      availableModels: ["llama-3.3-70b-versatile", "llama-3.2-90b-vision-preview", "mixtral-8x7b-32768"],
      envVarName: "GROQ_API_KEY",
      description: "Fast inference with open-source models like Llama and Mixtral"
    ),
    Provider(
      id: "deepseek",
      name: "DeepSeek",
      baseURL: "https://api.deepseek.com",
      defaultModel: "deepseek-chat",
      availableModels: ["deepseek-chat", "deepseek-coder"],
      envVarName: "DEEPSEEK_API_KEY",
      description: "DeepSeek's models optimized for coding and general tasks"
    ),
    Provider(
      id: "openrouter",
      name: "OpenRouter",
      baseURL: "https://openrouter.ai/api/v1",
      defaultModel: "anthropic/claude-3.5-sonnet",
      availableModels: ["anthropic/claude-3.5-sonnet", "google/gemini-pro-1.5", "meta-llama/llama-3.1-405b"],
      envVarName: "OPENROUTER_API_KEY",
      description: "Access multiple AI models through a single API"
    ),
    Provider(
      id: "anthropic",
      name: "Anthropic (via OpenRouter)",
      baseURL: "https://openrouter.ai/api/v1",
      defaultModel: "anthropic/claude-3.5-sonnet",
      availableModels: ["anthropic/claude-3.5-sonnet", "anthropic/claude-3.5-haiku"],
      envVarName: "ANTHROPIC_API_KEY",
      description: "Anthropic's Claude models (requires OpenRouter for OpenAI-compatible API)"
    ),
    Provider(
      id: "custom",
      name: "Custom Provider",
      baseURL: nil,
      defaultModel: "",
      availableModels: [],
      envVarName: nil,
      description: "Configure your own OpenAI-compatible API endpoint"
    )
  ]
  
  /// Get a provider by ID
  public static func provider(for id: String) -> Provider? {
    return providers.first { $0.id.lowercased() == id.lowercased() }
  }
  
  /// Get suggested models for a provider
  public static func suggestedModels(for providerId: String) -> [String] {
    return provider(for: providerId)?.availableModels ?? []
  }
  
  /// Get the base URL for a provider
  public static func baseURL(for providerId: String) -> String? {
    return provider(for: providerId)?.baseURL
  }
  
  /// Get the environment variable name for a provider
  public static func envVarName(for providerId: String) -> String? {
    return provider(for: providerId)?.envVarName
  }
  
  /// Format provider list for display
  public static func formatProviderList() -> String {
    var output = ""
    for (index, provider) in providers.enumerated() {
      output += "\(index + 1). \(provider.name)\n"
      output += "   \(provider.description)\n"
      if index < providers.count - 1 {
        output += "\n"
      }
    }
    return output
  }
}