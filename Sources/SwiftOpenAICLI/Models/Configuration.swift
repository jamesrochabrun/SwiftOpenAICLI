import Foundation

struct Configuration: Codable {
    var apiKey: String?
    var defaultModel: String = "gpt-4o"
    var outputFormat: OutputFormat = .plain
    var temperature: Double = 1.0
    var maxTokens: Int?
    
    static let defaultConfigPath = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent(".openai")
        .appendingPathComponent("config.json")
}