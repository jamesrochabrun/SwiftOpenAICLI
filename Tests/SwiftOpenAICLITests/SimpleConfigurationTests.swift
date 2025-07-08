import XCTest
@testable import SwiftOpenAICLI

final class SimpleConfigurationTests: XCTestCase {
    
    func testDefaultConfiguration() {
        let config = Configuration()
        
        XCTAssertNil(config.apiKey)
        XCTAssertEqual(config.defaultModel, "gpt-4o")
        XCTAssertEqual(config.outputFormat, .plain)
        XCTAssertEqual(config.temperature, 1.0)
        XCTAssertNil(config.maxTokens)
        XCTAssertNil(config.provider)
        XCTAssertNil(config.baseURL)
        XCTAssertNil(config.debugEnabled)
    }
    
    func testConfigurationEncoding() throws {
        var config = Configuration()
        config.apiKey = "test-key"
        config.defaultModel = "gpt-4"
        config.outputFormat = .json
        config.temperature = 0.7
        config.maxTokens = 100
        config.provider = "openai"
        config.baseURL = "https://api.openai.com"
        config.debugEnabled = true
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(config)
        
        let decoder = JSONDecoder()
        let decodedConfig = try decoder.decode(Configuration.self, from: data)
        
        XCTAssertEqual(decodedConfig.apiKey, "test-key")
        XCTAssertEqual(decodedConfig.defaultModel, "gpt-4")
        XCTAssertEqual(decodedConfig.outputFormat, .json)
        XCTAssertEqual(decodedConfig.temperature, 0.7)
        XCTAssertEqual(decodedConfig.maxTokens, 100)
        XCTAssertEqual(decodedConfig.provider, "openai")
        XCTAssertEqual(decodedConfig.baseURL, "https://api.openai.com")
        XCTAssertEqual(decodedConfig.debugEnabled, true)
    }
    
    func testOutputFormatValues() {
        XCTAssertEqual(OutputFormat.plain.rawValue, "plain")
        XCTAssertEqual(OutputFormat.json.rawValue, "json")
        XCTAssertEqual(OutputFormat.markdown.rawValue, "markdown")
    }
}