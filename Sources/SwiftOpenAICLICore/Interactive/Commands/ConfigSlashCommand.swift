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
      // Show specific config value
      showConfigValue(args[0])
    } else if args.count == 2 {
      // Set configuration value
      setConfigValue(args[0], value: args[1])
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
  
  private func setConfigValue(_ key: String, value: String) {
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
}