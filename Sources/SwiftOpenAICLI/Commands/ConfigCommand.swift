import ArgumentParser
import Foundation
import Rainbow

struct ConfigCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "config",
        abstract: "Manage OpenAI CLI configuration",
        subcommands: [
            SetCommand.self,
            GetCommand.self,
            ListCommand.self
        ]
    )
}

extension ConfigCommand {
    struct SetCommand: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "set",
            abstract: "Set a configuration value"
        )
        
        @Argument(help: "Configuration key (e.g., api-key, default-model)")
        var key: String
        
        @Argument(help: "Configuration value")
        var value: String
        
        mutating func run() throws {
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
        static let configuration = CommandConfiguration(
            commandName: "get",
            abstract: "Get a configuration value"
        )
        
        @Argument(help: "Configuration key")
        var key: String
        
        mutating func run() throws {
            if let value = ConfigurationManager.shared.get(key) {
                print("\(key): \(value)".green)
            } else {
                print("✗ Key '\(key)' not found".red)
                throw ExitCode.failure
            }
        }
    }
    
    struct ListCommand: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "list",
            abstract: "List all configuration values"
        )
        
        mutating func run() throws {
            print("Current configuration:".cyan)
            for (key, value) in ConfigurationManager.shared.listAll() {
                print("• \(key): \(value)")
            }
        }
    }
}