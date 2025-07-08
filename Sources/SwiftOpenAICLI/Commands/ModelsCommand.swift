import ArgumentParser
import Foundation
import SwiftOpenAI
import Rainbow
import SwiftyTextTable

struct ModelsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "models",
        abstract: "List available OpenAI models"
    )
    
    @Option(name: .long, help: "Filter models by name")
    var filter: String?
    
    @Flag(name: .long, help: "Show detailed information")
    var detailed = false
    
    mutating func run() async throws {
        print("Fetching available models...".cyan)
        
        do {
            let models = try await OpenAIService.shared.listModels()
            let filteredModels = if let filter = filter {
                models.filter { $0.id.lowercased().contains(filter.lowercased()) }
            } else {
                models
            }
            
            if filteredModels.isEmpty {
                print("No models found matching filter: \(filter ?? "")".yellow)
                return
            }
            
            if detailed {
                var table = TextTable(columns: [
                    TextTableColumn(header: "Model ID"),
                    TextTableColumn(header: "Created"),
                    TextTableColumn(header: "Owned By")
                ])
                
                for model in filteredModels {
                    let date = Date(timeIntervalSince1970: TimeInterval(model.created))
                    let formatter = DateFormatter()
                    formatter.dateStyle = .short
                    table.addRow(values: [
                        model.id,
                        formatter.string(from: date),
                        model.ownedBy
                    ])
                }
                print(table.render())
            } else {
                print("Available models:".green)
                for model in filteredModels {
                    print("• \(model.id)")
                }
            }
        } catch {
            print("Error fetching models: \(error.localizedDescription)".red)
            throw ExitCode.failure
        }
    }
}