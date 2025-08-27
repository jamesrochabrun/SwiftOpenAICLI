import ArgumentParser
import Foundation
import SwiftOpenAI
import Rainbow

public struct CompleteCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "complete",
        abstract: "Generate text completions (uses chat API)"
    )

    public init() {}

    
    @Argument(help: "The prompt for completion")
    var prompt: String
    
    @Option(name: [.short, .long], help: "The model to use")
    var model: String = "gpt-3.5-turbo"
    
    @Option(name: .long, help: "Maximum tokens to generate")
    var maxTokens: Int = 100
    
    @Option(name: .long, help: "Temperature (0.0-2.0)")
    var temperature: Double?
    
    @Option(name: .long, help: "Number of completions to generate")
    var number: Int = 1
    
    @Flag(name: .long, help: "Show token usage")
    var showTokens = false
    
    @Option(name: .long, help: "Verbosity level for GPT-5 models (low, medium, high)")
    var verbose: VerbosityLevel = .medium
    
    @Option(name: .long, help: "Reasoning effort for GPT-5 models (minimal, low, medium, high)")
    var reasoning: ReasoningEffort = .medium
    
    public mutating func run() async throws {
        print("Generating completion...".cyan)
        
        // Use configured temperature if not specified
        let effectiveTemperature = temperature ?? ConfigurationManager.shared.getConfiguration().temperature
        
        do {
            for i in 0..<number {
                if number > 1 {
                    print("\nCompletion \(i + 1):".yellow)
                }
                
                try await OpenAIService.shared.chat(
                    message: prompt,
                    model: model,
                    temperature: effectiveTemperature,
                    maxTokens: maxTokens,
                    stream: false,
                    plain: false,
                    verbose: verbose.rawValue,
                    reasoning: reasoning.rawValue
                )
            }
        } catch {
            print("Error generating completion: \(error.localizedDescription)".red)
            throw ExitCode.failure
        }
    }
}
