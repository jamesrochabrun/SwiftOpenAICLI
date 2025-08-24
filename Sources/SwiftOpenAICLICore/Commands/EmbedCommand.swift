import ArgumentParser
import Foundation
import SwiftOpenAI
import Rainbow

struct EmbedCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "embed",
        abstract: "Generate text embeddings"
    )
    
    @Argument(help: "The text to embed")
    var text: String
    
    @Option(name: [.short, .long], help: "The model to use")
    var model: String = "text-embedding-3-small"
    
    @Option(name: .long, help: "Dimensions for the embedding")
    var dimensions: Int?
    
    @Option(name: [.short, .long], help: "Output file for embeddings (JSON format)")
    var output: String?
    
    @Flag(name: .long, help: "Show embedding statistics")
    var stats = false
    
    mutating func run() async throws {
        print("Generating embeddings...".cyan)
        let displayText = text.count > 50 ? "\(text.prefix(50))..." : text
        print("Text: \"\(displayText)\"".green)
        print("Model: \(model)".green)
        
        do {
            let embeddings = try await OpenAIService.shared.generateEmbedding(
                text: text,
                model: model,
                dimensions: dimensions
            )
            
            if let output = output {
                // Save to file
                let jsonData: [String: Any] = [
                    "embedding": embeddings,
                    "model": model,
                    "text": text,
                    "dimensions": embeddings.count
                ]
                let data = try JSONSerialization.data(withJSONObject: jsonData, options: .prettyPrinted)
                let outputURL = URL(fileURLWithPath: output)
                try data.write(to: outputURL)
                print("\nEmbeddings saved to: \(output)".green)
            } else {
                // Print to console
                if stats {
                    print("\nEmbedding Statistics:".cyan)
                    print("• Dimensions: \(embeddings.count)")
                    print("• Min value: \(embeddings.min() ?? 0)")
                    print("• Max value: \(embeddings.max() ?? 0)")
                    print("• Mean value: \(embeddings.reduce(0, +) / Float(embeddings.count))")
                } else {
                    print("\nEmbedding vector (first 10 values):".cyan)
                    print(embeddings.prefix(10).map { String(format: "%.6f", $0) }.joined(separator: ", "))
                    print("... (\(embeddings.count) total dimensions)")
                }
            }
        } catch {
            print("Error generating embeddings: \(error.localizedDescription)".red)
            throw ExitCode.failure
        }
    }
}