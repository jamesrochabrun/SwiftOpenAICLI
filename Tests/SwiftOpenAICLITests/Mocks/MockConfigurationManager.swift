import Foundation
@testable import SwiftOpenAICLI

class MockConfigurationManager {
    static let shared = MockConfigurationManager()
    
    private var mockConfiguration: Configuration
    private var environmentVariables: [String: String] = [:]
    
    init() {
        self.mockConfiguration = Configuration()
    }
    
    // Allow tests to set environment variables
    func setEnvironmentVariable(_ key: String, value: String?) {
        if let value = value {
            environmentVariables[key] = value
        } else {
            environmentVariables.removeValue(forKey: key)
        }
    }
    
    // Allow tests to set configuration directly
    func setConfiguration(_ config: Configuration) {
        self.mockConfiguration = config
    }
    
    var apiKey: String? {
        // First check mock environment variable
        if let envKey = environmentVariables["OPENAI_API_KEY"] {
            return envKey
        }
        // Then check config
        return mockConfiguration.apiKey
    }
    
    var defaultModel: String {
        return mockConfiguration.defaultModel
    }
    
    var provider: String? {
        return mockConfiguration.provider
    }
    
    var baseURL: String? {
        return mockConfiguration.baseURL
    }
    
    var debugEnabled: Bool? {
        return mockConfiguration.debugEnabled
    }
    
    var configuration: Configuration? {
        return mockConfiguration
    }
    
    func get(_ key: String) -> String? {
        switch key {
        case "api-key":
            return apiKey
        case "default-model":
            return defaultModel
        case "output-format":
            return mockConfiguration.outputFormat.rawValue
        case "temperature":
            return String(mockConfiguration.temperature)
        case "max-tokens":
            return mockConfiguration.maxTokens.map { String($0) }
        case "provider":
            return mockConfiguration.provider
        case "base-url":
            return mockConfiguration.baseURL
        case "debug":
            return mockConfiguration.debugEnabled.map { String($0) }
        default:
            return nil
        }
    }
    
    func set(_ key: String, value: String) throws {
        switch key {
        case "api-key":
            mockConfiguration.apiKey = value
        case "default-model":
            mockConfiguration.defaultModel = value
        case "output-format":
            guard let format = OutputFormat(rawValue: value) else {
                throw ConfigurationError.invalidValue(key: key, value: value)
            }
            mockConfiguration.outputFormat = format
        case "temperature":
            guard let temp = Double(value), temp >= 0, temp <= 2 else {
                throw ConfigurationError.invalidValue(key: key, value: value)
            }
            mockConfiguration.temperature = temp
        case "max-tokens":
            guard let tokens = Int(value), tokens > 0 else {
                throw ConfigurationError.invalidValue(key: key, value: value)
            }
            mockConfiguration.maxTokens = tokens
        case "provider":
            mockConfiguration.provider = value
        case "base-url":
            mockConfiguration.baseURL = value
        case "debug":
            mockConfiguration.debugEnabled = value.lowercased() == "true" || value == "1"
        default:
            throw ConfigurationError.unknownKey(key)
        }
    }
    
    func listAll() -> [(key: String, value: String)] {
        var items: [(String, String)] = []
        
        items.append(("api-key", apiKey.map { _ in "****" } ?? "not set"))
        items.append(("default-model", defaultModel))
        items.append(("output-format", mockConfiguration.outputFormat.rawValue))
        items.append(("temperature", String(mockConfiguration.temperature)))
        if let maxTokens = mockConfiguration.maxTokens {
            items.append(("max-tokens", String(maxTokens)))
        }
        if let provider = mockConfiguration.provider {
            items.append(("provider", provider))
        }
        if let baseURL = mockConfiguration.baseURL {
            items.append(("base-url", baseURL))
        }
        if let debug = mockConfiguration.debugEnabled {
            items.append(("debug", String(debug)))
        }
        
        return items
    }
    
    // Test helper to reset configuration
    func reset() {
        mockConfiguration = Configuration()
        environmentVariables = [:]
    }
}