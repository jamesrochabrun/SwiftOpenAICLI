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
}
