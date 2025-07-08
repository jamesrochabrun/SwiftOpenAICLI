import ArgumentParser
import Foundation
import SwiftOpenAI
import Rainbow

struct CompleteCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "complete",
        abstract: "Generate text completions (uses chat API)"
    )
    
    @Argument(help: "The prompt for completion")
    var prompt: String
    
    @Option(name: [.short, .long], help: "The model to use")
    var model: String = "gpt-3.5-turbo"
    
    @Option(name: .long, help: "Maximum tokens to generate")
    var maxTokens: Int = 100
    
    @Option(name: .long, help: "Temperature (0.0-2.0)")
    var temperature: Double = 1.0
    
    @Option(name: .long, help: "Number of completions to generate")
    var number: Int = 1
    
    @Flag(name: .long, help: "Show token usage")
    var showTokens = false
    
    mutating func run() async throws {
        print("Generating completion...".cyan)
        
        do {
            for i in 0..<number {
                if number > 1 {
                    print("\nCompletion \(i + 1):".yellow)
                }
                
                try await OpenAIService.shared.chat(
                    message: prompt,
                    model: model,
                    temperature: temperature,
                    maxTokens: maxTokens,
                    stream: false
                )
            }
        } catch {
            print("Error generating completion: \(error.localizedDescription)".red)
            throw ExitCode.failure
        }
    }
}