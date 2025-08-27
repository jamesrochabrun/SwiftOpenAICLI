import ArgumentParser
import Foundation
import Rainbow

public struct ConfigCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "config",
        abstract: "Manage OpenAI CLI configuration",
        subcommands: [
            SetCommand.self,
            GetCommand.self,
            ListCommand.self,
            SetupCommand.self,
            MCPConfigCommand.self
        ]
    )

    public init() {}

}

extension ConfigCommand {
    struct SetCommand: ParsableCommand {
        public static let configuration = CommandConfiguration(
            commandName: "set",
            abstract: "Set a configuration value"
        )

    public init() {}
        
        @Argument(help: "Configuration key (e.g., api-key, default-model)")
        var key: String
        
        @Argument(help: "Configuration value")
        var value: String
        
        public mutating func run() throws {
            do {
                try ConfigurationManager.shared.set(key, value: value)
                print("✓ Set \(key) = \(value)".green)
            } catch {
                print("✗ Error: \(error.localizedDescription)".red)
                throw ExitCode.failure
            }
        }
    }
    
    struct GetCommand: ParsableCommand {
        public static let configuration = CommandConfiguration(
            commandName: "get",
            abstract: "Get a configuration value"
        )

    public init() {}
        
        @Argument(help: "Configuration key")
        var key: String
        
        public mutating func run() throws {
            if let value = ConfigurationManager.shared.get(key) {
                print("\(key): \(value)".green)
            } else {
                print("✗ Key '\(key)' not found".red)
                throw ExitCode.failure
            }
        }
    }
    
    struct ListCommand: ParsableCommand {
        public static let configuration = CommandConfiguration(
            commandName: "list",
            abstract: "List all configuration values"
        )

    public init() {}
        
        public mutating func run() throws {
            print("Current configuration:".cyan)
            for (key, value) in ConfigurationManager.shared.listAll() {
                print("• \(key): \(value)")
            }
        }
    }
    
    struct SetupCommand: ParsableCommand {
        public static let configuration = CommandConfiguration(
            commandName: "setup",
            abstract: "Interactive configuration setup for AI providers"
        )
        
        public init() {}
        
        public mutating func run() throws {
            print("\n🚀 " + "SwiftOpenAI CLI Configuration Setup".cyan.bold)
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━".lightBlack)
            
            // Show available providers
            print("\nAvailable providers:".yellow)
            print(ProviderPresets.formatProviderList())
            
            // Get provider selection
            print("\nSelect a provider (1-\(ProviderPresets.providers.count)): ".cyan, terminator: "")
            guard let selection = readLine(),
                  let index = Int(selection),
                  index >= 1 && index <= ProviderPresets.providers.count else {
                print("✗ Invalid selection".red)
                throw ExitCode.failure
            }
            
            let selectedProvider = ProviderPresets.providers[index - 1]
            print("✓ Selected: \(selectedProvider.name)".green)
            
            // Get API key
            print("\nEnter your API key for \(selectedProvider.name): ".cyan, terminator: "")
            guard let apiKey = readLine(), !apiKey.isEmpty else {
                print("✗ API key is required".red)
                throw ExitCode.failure
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
                print("• API Key: ****")
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
                
                print("\nYou're ready to use SwiftOpenAI CLI! Try:".green)
                print("  swiftopenai chat \"Hello!\"")
                print("  swiftopenai agent \"Help me with coding\" --tools all")
                
            } catch {
                print("\n✗ Configuration failed: \(error.localizedDescription)".red)
                throw ExitCode.failure
            }
        }
    }
}
