import ArgumentParser
import Foundation
import SwiftOpenAI
import Rainbow

struct ChatCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "chat",
        abstract: "Chat with OpenAI models"
    )
    
    @Argument(help: "The message to send to the AI")
    var message: String?
    
    @Option(name: [.short, .long], help: "The model to use")
    var model: String = "gpt-4o"
    
    @Flag(name: [.short, .long], help: "Interactive chat mode")
    var interactive = false
    
    @Flag(name: .long, help: "Disable streaming response")
    var noStream = false
    
    @Option(name: .long, help: "System prompt")
    var system: String?
    
    @Option(name: .long, help: "Temperature (0.0-2.0)")
    var temperature: Double = 1.0
    
    @Option(name: .long, help: "Maximum tokens to generate")
    var maxTokens: Int?
    
    @Option(name: .long, help: "Output format (plain, json, markdown)")
    var format: OutputFormat = .plain
    
    mutating func run() async throws {
        if interactive {
            try await runInteractiveMode()
        } else if let message = message {
            try await OpenAIService.shared.chat(
                message: message,
                model: model,
                system: system,
                temperature: temperature,
                maxTokens: maxTokens,
                stream: !noStream
            )
        } else {
            print("Please provide a message or use --interactive flag".red)
            throw ExitCode.failure
        }
    }
    
    private func runInteractiveMode() async throws {
        print("🤖 OpenAI Chat (\(model))".cyan)
        print("Type 'exit' to quit, 'clear' to clear history".lightBlack)
        print("")
        
        while true {
            print("You: ".green, terminator: "")
            guard let input = readLine(), !input.isEmpty else { continue }
            
            if input.lowercased() == "exit" {
                print("Goodbye!".yellow)
                break
            }
            
            if input.lowercased() == "clear" {
                print("Conversation cleared.".yellow)
                continue
            }
            
            do {
                try await OpenAIService.shared.chat(
                    message: input,
                    model: model,
                    system: system,
                    temperature: temperature,
                    maxTokens: maxTokens,
                    stream: !noStream
                )
                print() // Add spacing
            } catch {
                print("Error: \(error.localizedDescription)".red)
            }
        }
    }
}

enum OutputFormat: String, ExpressibleByArgument, Codable {
    case plain
    case json
    case markdown
}