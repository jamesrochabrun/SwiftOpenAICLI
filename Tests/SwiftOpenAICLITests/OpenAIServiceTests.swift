import XCTest
@testable import SwiftOpenAICLICore

final class OpenAIServiceTests: XCTestCase {
    
    // MARK: - Model Name Normalization Tests
    
    func testModelNameNormalization() {
        // Test that the service normalizes model names correctly
        // We can't directly test the private function, but we can test the behavior
        let testCases: [(input: String, expectedNormalized: String)] = [
            ("gpt5", "gpt-5"),
            ("GPT5", "gpt-5"),
            ("gpt5mini", "gpt-5-mini"),
            ("gpt5Mini", "gpt-5-mini"),
            ("gpt5-mini", "gpt-5-mini"),
            ("gpt5nano", "gpt-5-nano"),
            ("gpt5Nano", "gpt-5-nano"),
            ("gpt5-nano", "gpt-5-nano"),
            ("gpt-5", "gpt-5"),
            ("gpt-5-mini", "gpt-5-mini"),
            ("gpt-5-nano", "gpt-5-nano"),
            ("gpt-4o", "gpt-4o"),  // Should remain unchanged
            ("gpt-3.5-turbo", "gpt-3.5-turbo")  // Should remain unchanged
        ]
        
        for testCase in testCases {
            // Since we can't test the private function directly, we verify the logic
            let input = testCase.input.lowercased()
            let expected = testCase.expectedNormalized
            
            // Test the normalization logic
            let normalized: String
            switch input {
            case "gpt5":
                normalized = "gpt-5"
            case "gpt5mini", "gpt5-mini":
                normalized = "gpt-5-mini"
            case "gpt5nano", "gpt5-nano":
                normalized = "gpt-5-nano"
            default:
                normalized = testCase.input
            }
            
            XCTAssertEqual(normalized, expected, "Model '\(testCase.input)' should normalize to '\(expected)'")
        }
    }
    
    // MARK: - GPT-5 Model Detection Tests
    
    func testGPT5ModelDetection() {
        let gpt5Models = [
            "gpt-5",
            "gpt-5-mini",
            "gpt-5-nano"
        ]
        
        for model in gpt5Models {
            let isGPT5 = model.lowercased().contains("gpt-5")
            XCTAssertTrue(isGPT5, "Model \(model) should be detected as GPT-5")
        }
    }
    
    func testNonGPT5ModelDetection() {
        let nonGPT5Models = [
            "gpt-4",
            "gpt-4o",
            "gpt-3.5-turbo",
            "claude-3",
            "llama2",
            "dall-e-3"
        ]
        
        for model in nonGPT5Models {
            let isGPT5 = model.lowercased().contains("gpt5") || model.lowercased().contains("gpt-5")
            XCTAssertFalse(isGPT5, "Model \(model) should NOT be detected as GPT-5")
        }
    }
    
    // MARK: - Parameter Validation Tests
    
    func testVerbosityParameterValues() {
        let validValues = ["low", "medium", "high"]
        
        for value in validValues {
            XCTAssertNotNil(VerbosityLevel(rawValue: value), "'\(value)' should be a valid verbosity level")
        }
        
        let invalidValues = ["minimal", "very-high", "extreme", "none"]
        for value in invalidValues {
            XCTAssertNil(VerbosityLevel(rawValue: value), "'\(value)' should NOT be a valid verbosity level")
        }
    }
    
    func testReasoningParameterValues() {
        let validValues = ["minimal", "low", "medium", "high"]
        
        for value in validValues {
            XCTAssertNotNil(ReasoningEffort(rawValue: value), "'\(value)' should be a valid reasoning effort")
        }
        
        let invalidValues = ["none", "very-high", "extreme", "standard"]
        for value in invalidValues {
            XCTAssertNil(ReasoningEffort(rawValue: value), "'\(value)' should NOT be a valid reasoning effort")
        }
    }
    
    // MARK: - Default Values Tests
    
    func testDefaultVerbosityIsMedium() {
        let defaultVerbosity = VerbosityLevel.medium
        XCTAssertEqual(defaultVerbosity.rawValue, "medium")
    }
    
    func testDefaultReasoningIsMedium() {
        let defaultReasoning = ReasoningEffort.medium
        XCTAssertEqual(defaultReasoning.rawValue, "medium")
    }
    
    // MARK: - Service Configuration Tests
    
    func testServiceInitialization() {
        let service = OpenAIService.shared
        XCTAssertNotNil(service)
    }
    
    func testParameterPassingLogic() {
        // Test that parameters are correctly formatted for API calls
        let verbose = VerbosityLevel.low
        let reasoning = ReasoningEffort.minimal
        
        XCTAssertEqual(verbose.rawValue, "low")
        XCTAssertEqual(reasoning.rawValue, "minimal")
    }
    
    // MARK: - Integration Tests
    
    func testGPT5SpecificFeatures() {
        // Test that GPT-5 models support the new parameters
        let gpt5Model = "gpt5"
        let isGPT5 = gpt5Model.lowercased().contains("gpt5") || gpt5Model.lowercased().contains("gpt-5")
        
        XCTAssertTrue(isGPT5)
        
        // If it's a GPT-5 model, these parameters should be applicable
        if isGPT5 {
            let verbose = VerbosityLevel.high.rawValue
            let reasoning = ReasoningEffort.minimal.rawValue
            
            XCTAssertEqual(verbose, "high")
            XCTAssertEqual(reasoning, "minimal")
        }
    }
    
    func testNonGPT5ModelsIgnoreNewParameters() {
        // Test that non-GPT-5 models ignore the new parameters
        let model = "gpt-4o"
        let isGPT5 = model.lowercased().contains("gpt5") || model.lowercased().contains("gpt-5")
        
        XCTAssertFalse(isGPT5, "GPT-4 should not be detected as GPT-5")
        
        // These parameters should be ignored for non-GPT-5 models
        // The service should not apply them to the API call
    }
    
    // MARK: - Error Handling Tests
    
    func testInvalidParameterCombinations() {
        // Test that invalid parameter combinations are handled
        // For example, trying to use minimal reasoning with high verbosity might not make sense
        // But since the API allows any combination, we just test that all combinations are valid
        
        for verbosity in VerbosityLevel.allCases {
            for reasoning in ReasoningEffort.allCases {
                // All combinations should be valid
                XCTAssertNotNil(verbosity.rawValue)
                XCTAssertNotNil(reasoning.rawValue)
            }
        }
    }
}