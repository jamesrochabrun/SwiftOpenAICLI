import Foundation
import Rainbow

/// Slash command for managing configuration
public struct ConfigSlashCommand: SlashCommand {
  public let name = "config"
  public let description = "View and modify configuration settings"
  public let argumentHint: String? = "[key] [value]"
  
  public init() {}
  
  public func execute(arguments: String?, context: inout CommandContext) async throws -> Bool {
    let args = arguments?.split(separator: " ", maxSplits: 1).map(String.init) ?? []
    
    if args.isEmpty {
      // Show all configuration
      showConfiguration(context: context)
    } else if args.count == 1 {
      // Check if it's the setup command
      if args[0].lowercased() == "setup" {
        try runSetup(context: &context)
      } else {
        // Show specific config value
        showConfigValue(args[0])
      }
    } else if args.count == 2 {
      // Set configuration value
      setConfigValue(args[0], value: args[1], context: &context)
    }
    
    return true
  }
  
  private func showConfiguration(context: CommandContext) {
    print("\n⚙️  " + "Current Configuration".cyan.bold)
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━".lightBlack)
    
    let config = ConfigurationManager.shared
    
    if let apiKey = config.apiKey {
      let masked = maskApiKey(apiKey)
      print("• " + "api-key:".green + "        \(masked)")
    } else {
      print("• " + "api-key:".green + "        (not set)".red)
    }
    
    print("• " + "default-model:".green + "  \(config.defaultModel)")
    
    if let tempStr = config.get("temperature"), let temp = Double(tempStr) {
      print("• " + "temperature:".green + "    \(temp)")
    } else {
      print("• " + "temperature:".green + "    1.0 (default)".lightBlack)
    }
    
    if let maxTokensStr = config.get("max-tokens"), let maxTokens = Int(maxTokensStr) {
      print("• " + "max-tokens:".green + "     \(maxTokens)")
    } else {
      print("• " + "max-tokens:".green + "     (default)".lightBlack)
    }
    
    if let maxToolCallsStr = config.get("max-tool-calls"), let maxToolCalls = Int(maxToolCallsStr) {
      print("• " + "max-tool-calls:".green + " \(maxToolCalls)")
    } else {
      print("• " + "max-tool-calls:".green + " (default)".lightBlack)
    }
    
    // Only show output-format when not in agent/ISA mode
    if !context.isAgentMode {
      print("• " + "output-format:".green + "  \(config.get("output-format") ?? "plain")")
    }
    
    if let animatedLoading = config.get("animated-loading") {
      print("• " + "animated-loading:".green + " \(animatedLoading)")
    }
    
    if let provider = config.provider {
      print("• " + "provider:".green + "       \(provider)")
    }
    
    if let baseURL = config.baseURL {
      print("• " + "base-url:".green + "       \(baseURL)")
    }
    
    // Show debug status
    let debugStatus = config.debugEnabled ?? false
    print("• " + "debug:".green + "          \(debugStatus ? "enabled" : "disabled")")
    
    print("\n💡 Usage: /config <key> <value>".lightBlack)
    print("   Example: /config temperature 0.7".lightBlack)
    print("")
  }
  
  private func showConfigValue(_ key: String) {
    guard let value = ConfigurationManager.shared.get(key) else {
      print("Configuration key '\(key)' not found".red)
      return
    }
    
    if key == "api-key" {
      print("\(key): \(maskApiKey(value))".green)
    } else {
      print("\(key): \(value)".green)
    }
  }
  
  private func setConfigValue(_ key: String, value: String, context: inout CommandContext) {
    do {
      try ConfigurationManager.shared.set(key, value: value)
      
      if key == "api-key" {
        print("✅ Set \(key) = \(maskApiKey(value))".green)
      } else {
        print("✅ Set \(key) = \(value)".green)
      }
      
      // Reinitialize service if API key changed
      if key == "api-key" || key == "provider" || key == "base-url" {
        print("Reinitializing OpenAI service...".lightBlack)
        // The service will auto-reinitialize on next use
      }
      
    } catch {
      print("Error setting configuration: \(error.localizedDescription)".red)
    }
  }
  
  private func maskApiKey(_ apiKey: String) -> String {
    guard apiKey.count > 8 else { return "****" }
    let prefix = apiKey.prefix(4)
    let suffix = apiKey.suffix(4)
    return "\(prefix)...\(suffix)"
  }
  
  private func runSetup(context: inout CommandContext) throws {
    print("\n🚀 " + "Configuration Setup".cyan.bold)
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━".lightBlack)
    
    // Show available providers
    print("\nAvailable providers:".yellow)
    print(ProviderPresets.formatProviderList())
    
    // Get provider selection
    print("\nSelect a provider (1-\(ProviderPresets.providers.count), or 'q' to cancel): ".cyan, terminator: "")
    guard let selection = readLine() else {
      print("Setup cancelled".yellow)
      return
    }
    
    if selection.lowercased() == "q" {
      print("Setup cancelled".yellow)
      return
    }
    
    guard let index = Int(selection),
          index >= 1 && index <= ProviderPresets.providers.count else {
      print("✗ Invalid selection".red)
      return
    }
    
    let selectedProvider = ProviderPresets.providers[index - 1]
    print("✓ Selected: \(selectedProvider.name)".green)
    
    // Get API key
    print("\nEnter your API key for \(selectedProvider.name): ".cyan, terminator: "")
    guard let apiKey = readLine(), !apiKey.isEmpty else {
      print("✗ API key is required".red)
      return
    }
    
    // Configure the provider
    let configManager = ConfigurationManager.shared
    
    do {
      // Set provider
      try configManager.set("provider", value: selectedProvider.id)
      
      // Set API key
      try configManager.set("api-key", value: apiKey)
      
      // Set base URL if needed
      if let baseURL = selectedProvider.baseURL {
        try configManager.set("base-url", value: baseURL)
      } else if selectedProvider.id != "custom" {
        // Clear base URL for OpenAI (uses default)
        try configManager.set("base-url", value: "")
      }
      
      // Ask if user wants to use the default model
      if !selectedProvider.defaultModel.isEmpty {
        print("\nUse default model '\(selectedProvider.defaultModel)'? (Y/n): ".cyan, terminator: "")
        let useDefault = readLine()?.lowercased() ?? "y"
        
        if useDefault == "y" || useDefault == "yes" || useDefault.isEmpty {
          try configManager.set("default-model", value: selectedProvider.defaultModel)
          // Update context model if in interactive mode
          context.currentModel = selectedProvider.defaultModel
        } else {
          // Show available models
          if !selectedProvider.availableModels.isEmpty {
            print("\nAvailable models:".yellow)
            for model in selectedProvider.availableModels {
              print("  • \(model)")
            }
          }
          print("\nEnter model name: ".cyan, terminator: "")
          if let model = readLine(), !model.isEmpty {
            try configManager.set("default-model", value: model)
            // Update context model if in interactive mode
            context.currentModel = model
          }
        }
      }
      
      // For custom provider, ask for base URL
      if selectedProvider.id == "custom" {
        print("\nEnter the API base URL: ".cyan, terminator: "")
        if let baseURL = readLine(), !baseURL.isEmpty {
          try configManager.set("base-url", value: baseURL)
        }
        
        print("Enter the default model name: ".cyan, terminator: "")
        if let model = readLine(), !model.isEmpty {
          try configManager.set("default-model", value: model)
          context.currentModel = model
        }
      }
      
      // Ask about debug mode
      print("\nEnable debug mode? (shows HTTP status codes and headers) (y/N): ".cyan, terminator: "")
      let enableDebug = readLine()?.lowercased() ?? "n"
      
      if enableDebug == "y" || enableDebug == "yes" {
        try configManager.set("debug", value: "true")
      } else {
        try configManager.set("debug", value: "false")
      }
      
      print("\n✅ " + "Configuration complete!".green.bold)
      print("\nYour settings:".cyan)
      print("• Provider: \(selectedProvider.name)")
      print("• API Key: \(maskApiKey(apiKey))")
      if let baseURL = configManager.get("base-url"), !baseURL.isEmpty {
        print("• Base URL: \(baseURL)")
      }
      print("• Default Model: \(configManager.get("default-model") ?? "not set")")
      print("• Debug Mode: \(enableDebug == "y" || enableDebug == "yes" ? "enabled" : "disabled")")
      
      // Show environment variable tip if applicable
      if let envVar = selectedProvider.envVarName {
        print("\n💡 " + "Tip:".yellow + " You can also set your API key as an environment variable:")
        print("   export \(envVar)=your-api-key")
      }
      
      print("\nConfiguration saved! You can now use your selected provider.".green)
      print("Try sending a message to test the connection.".lightBlack)
      
    } catch {
      print("\n✗ Configuration failed: \(error.localizedDescription)".red)
    }
  }
}