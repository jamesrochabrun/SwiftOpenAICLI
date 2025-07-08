import Foundation
import Rainbow

class ConfigurationManager {
    static let shared = ConfigurationManager()
    
    private let configPath: URL
    private var configuration: Configuration
    
    private init() {
        self.configPath = Configuration.defaultConfigPath
        self.configuration = ConfigurationManager.loadConfiguration(from: configPath) ?? Configuration()
    }
    
    var apiKey: String? {
        // First check environment variable
        if let envKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] {
            return envKey
        }
        // Then check config file
        return configuration.apiKey
    }
    
    var defaultModel: String {
        return configuration.defaultModel
    }
    
    var provider: String? {
        return configuration.provider
    }
    
    var baseURL: String? {
        return configuration.baseURL
    }
    
    var debugEnabled: Bool? {
        return configuration.debugEnabled
    }
    
    func get(_ key: String) -> String? {
        switch key {
        case "api-key":
            return apiKey
        case "default-model":
            return defaultModel
        case "output-format":
            return configuration.outputFormat.rawValue
        case "temperature":
            return String(configuration.temperature)
        case "max-tokens":
            return configuration.maxTokens.map { String($0) }
        case "provider":
            return configuration.provider
        case "base-url":
            return configuration.baseURL
        case "debug":
            return configuration.debugEnabled.map { String($0) }
        default:
            return nil
        }
    }
    
    func set(_ key: String, value: String) throws {
        switch key {
        case "api-key":
            configuration.apiKey = value
        case "default-model":
            configuration.defaultModel = value
        case "output-format":
            guard let format = OutputFormat(rawValue: value) else {
                throw ConfigurationError.invalidValue(key: key, value: value)
            }
            configuration.outputFormat = format
        case "temperature":
            guard let temp = Double(value), temp >= 0, temp <= 2 else {
                throw ConfigurationError.invalidValue(key: key, value: value)
            }
            configuration.temperature = temp
        case "max-tokens":
            guard let tokens = Int(value), tokens > 0 else {
                throw ConfigurationError.invalidValue(key: key, value: value)
            }
            configuration.maxTokens = tokens
        case "provider":
            configuration.provider = value
        case "base-url":
            configuration.baseURL = value
        case "debug":
            configuration.debugEnabled = value.lowercased() == "true" || value == "1"
        default:
            throw ConfigurationError.unknownKey(key)
        }
        
        try saveConfiguration()
    }
    
    func listAll() -> [(key: String, value: String)] {
        var items: [(String, String)] = []
        
        items.append(("api-key", apiKey.map { _ in "****" } ?? "not set"))
        items.append(("default-model", defaultModel))
        items.append(("output-format", configuration.outputFormat.rawValue))
        items.append(("temperature", String(configuration.temperature)))
        if let maxTokens = configuration.maxTokens {
            items.append(("max-tokens", String(maxTokens)))
        }
        if let provider = configuration.provider {
            items.append(("provider", provider))
        }
        if let baseURL = configuration.baseURL {
            items.append(("base-url", baseURL))
        }
        if let debug = configuration.debugEnabled {
            items.append(("debug", String(debug)))
        }
        
        return items
    }
    
    private func saveConfiguration() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(configuration)
        
        // Create directory if it doesn't exist
        let directory = configPath.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        
        try data.write(to: configPath)
        print("Configuration saved to: \(configPath.path)".green)
    }
    
    private static func loadConfiguration(from url: URL) -> Configuration? {
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let config = try? JSONDecoder().decode(Configuration.self, from: data) else {
            return nil
        }
        return config
    }
}

enum ConfigurationError: LocalizedError {
    case unknownKey(String)
    case invalidValue(key: String, value: String)
    
    var errorDescription: String? {
        switch self {
        case .unknownKey(let key):
            return "Unknown configuration key: '\(key)'"
        case .invalidValue(let key, let value):
            return "Invalid value '\(value)' for key '\(key)'"
        }
    }
}