import ArgumentParser
import Foundation
import SwiftOpenAI
import Rainbow

public struct ChatCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "chat",
        abstract: "Chat with OpenAI models"
    )

    public init() {}

    
    @Argument(help: "The message to send to the AI")
    var message: String?
    
    @Option(name: [.short, .long], help: "The model to use")
    var model: String = "gpt-4o"
    
    @Flag(name: [.short, .long], help: "Interactive chat mode")
    var interactive = false
    
    @Flag(name: .long, help: "Disable streaming response")
    var noStream = false
    
    @Flag(name: [.customShort("p"), .long], help: "Plain output without formatting")
    var plain = false
    
    @Option(name: .long, help: "System prompt")
    var system: String?
    
    @Option(name: .long, help: "Temperature (0.0-2.0)")
    var temperature: Double = 1.0
    
    @Option(name: .long, help: "Maximum tokens to generate")
    var maxTokens: Int?
    
    @Option(name: .long, help: "Output format (plain, json, markdown)")
    var format: OutputFormat = .plain
    
    @Option(name: .long, help: "Verbosity level for GPT-5 models (low, medium, high)")
    var verbose: VerbosityLevel = .medium
    
    @Option(name: .long, help: "Reasoning effort for GPT-5 models (minimal, low, medium, high)")
    var reasoning: ReasoningEffort = .medium
    
    public mutating func run() async throws {
        if interactive {
            try await runInteractiveMode()
        } else if let message = message {
            try await OpenAIService.shared.chat(
                message: message,
                model: model,
                system: system,
                temperature: temperature,
                maxTokens: maxTokens,
                stream: !noStream,
                plain: plain,
                verbose: verbose.rawValue,
                reasoning: reasoning.rawValue
            )
        } else {
            print("Please provide a message or use --interactive flag".red)
            throw ExitCode.failure
        }
    }
    
    private func runInteractiveMode() async throws {
        // Initialize input processor and command registry
        let inputProcessor = InputProcessor()
        let registry = SlashCommandRegistry.shared
        
        // Create local mutable copies
        var currentModel = model
        var currentTemperature = temperature
        var currentMaxTokens = maxTokens
        
        // Create session ID and command context
        var currentSessionId = UUID().uuidString
        var commandContext = CommandContext(
            sessionId: currentSessionId,
            currentModel: currentModel,
            temperature: currentTemperature,
            maxTokens: currentMaxTokens,
            isAgentMode: false
        )
        if !plain {
            print("🤖 OpenAI Chat (\(model))".cyan)
            print("Type 'exit' to quit, 'clear' to clear history".lightBlack)
            print("")
        }
        
        while true {
            // Use input processor for reading
            guard let input = inputProcessor.readInput() else {
                // EOF detected (Ctrl+D)
                if !plain {
                    print("\nGoodbye!".yellow)
                }
                break
            }
            
            // Process input through the input processor
            let action = inputProcessor.processInput(input)
            
            switch action {
            case .empty:
                continue
                
            case .exit:
                if !plain {
                    print("Goodbye!".yellow)
                }
                break
                
            case .clearScreen:
                if !plain {
                    print("Conversation cleared.".yellow)
                }
                SessionManager.shared.clearSession(currentSessionId)
                currentSessionId = UUID().uuidString
                commandContext.sessionId = currentSessionId
                continue
                
            case .continueMultiline:
                continue
                
            case .cancelMultiline:
                if !plain {
                    print("Multiline input cancelled".yellow)
                }
                continue
                
            case .slashCommand(let command):
                do {
                    // Execute slash command
                    let shouldContinue = try await registry.execute(command, context: &commandContext)
                    if !shouldContinue {
                        if !plain {
                            print("Goodbye!".yellow)
                        }
                        break
                    }
                    // Update local variables if model changed
                    currentModel = commandContext.currentModel
                    currentTemperature = commandContext.temperature
                    currentMaxTokens = commandContext.maxTokens
                } catch {
                    print("\(error.localizedDescription)".red)
                }
                continue
                
            case .message(let trimmedInput):
            
                do {
                    try await OpenAIService.shared.chat(
                        message: trimmedInput,
                    model: currentModel,
                    system: system,
                    temperature: currentTemperature,
                    maxTokens: currentMaxTokens,
                    stream: !noStream,
                    plain: plain,
                    verbose: verbose.rawValue,
                    reasoning: reasoning.rawValue
                    )
                    print() // Add spacing
                } catch {
                    // Clear any pending input after interruption
                    inputProcessor.clearPendingInput()
                    
                    if error is CancellationError {
                        // Suppress extra error line; OpenAIService already printed interruption
                        // Don't show any error message
                    } else {
                        print("Error: \(error.localizedDescription)".red)
                    }
                }
            } // end switch
        }
    }
}

public enum OutputFormat: String, ExpressibleByArgument, Codable {
    case plain
    case json
    case markdown
}
