import XCTest
@testable import SwiftOpenAICLI
import ArgumentParser

final class VerbosityAndReasoningTests: XCTestCase {
    
    // MARK: - VerbosityLevel Tests
    
    func testVerbosityLevelRawValues() {
        XCTAssertEqual(VerbosityLevel.low.rawValue, "low")
        XCTAssertEqual(VerbosityLevel.medium.rawValue, "medium")
        XCTAssertEqual(VerbosityLevel.high.rawValue, "high")
    }
    
    func testVerbosityLevelAllCases() {
        let allCases = VerbosityLevel.allCases
        XCTAssertEqual(allCases.count, 3)
        XCTAssertTrue(allCases.contains(.low))
        XCTAssertTrue(allCases.contains(.medium))
        XCTAssertTrue(allCases.contains(.high))
    }
    
    func testVerbosityLevelFromString() {
        XCTAssertEqual(VerbosityLevel(rawValue: "low"), .low)
        XCTAssertEqual(VerbosityLevel(rawValue: "medium"), .medium)
        XCTAssertEqual(VerbosityLevel(rawValue: "high"), .high)
        XCTAssertNil(VerbosityLevel(rawValue: "invalid"))
    }
    
    func testVerbosityLevelExpressibleByArgument() {
        XCTAssertEqual(VerbosityLevel(argument: "low"), .low)
        XCTAssertEqual(VerbosityLevel(argument: "medium"), .medium)
        XCTAssertEqual(VerbosityLevel(argument: "high"), .high)
        XCTAssertNil(VerbosityLevel(argument: "invalid"))
    }
    
    func testVerbosityLevelCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        // Test encoding and decoding
        let original = VerbosityLevel.high
        let encoded = try encoder.encode(original)
        let decoded = try decoder.decode(VerbosityLevel.self, from: encoded)
        
        XCTAssertEqual(original, decoded)
        
        // Test JSON string representation
        let jsonString = String(data: encoded, encoding: .utf8)
        XCTAssertEqual(jsonString, "\"high\"")
    }
    
    // MARK: - ReasoningEffort Tests
    
    func testReasoningEffortRawValues() {
        XCTAssertEqual(ReasoningEffort.minimal.rawValue, "minimal")
        XCTAssertEqual(ReasoningEffort.low.rawValue, "low")
        XCTAssertEqual(ReasoningEffort.medium.rawValue, "medium")
        XCTAssertEqual(ReasoningEffort.high.rawValue, "high")
    }
    
    func testReasoningEffortAllCases() {
        let allCases = ReasoningEffort.allCases
        XCTAssertEqual(allCases.count, 4)
        XCTAssertTrue(allCases.contains(.minimal))
        XCTAssertTrue(allCases.contains(.low))
        XCTAssertTrue(allCases.contains(.medium))
        XCTAssertTrue(allCases.contains(.high))
    }
    
    func testReasoningEffortFromString() {
        XCTAssertEqual(ReasoningEffort(rawValue: "minimal"), .minimal)
        XCTAssertEqual(ReasoningEffort(rawValue: "low"), .low)
        XCTAssertEqual(ReasoningEffort(rawValue: "medium"), .medium)
        XCTAssertEqual(ReasoningEffort(rawValue: "high"), .high)
        XCTAssertNil(ReasoningEffort(rawValue: "invalid"))
    }
    
    func testReasoningEffortExpressibleByArgument() {
        XCTAssertEqual(ReasoningEffort(argument: "minimal"), .minimal)
        XCTAssertEqual(ReasoningEffort(argument: "low"), .low)
        XCTAssertEqual(ReasoningEffort(argument: "medium"), .medium)
        XCTAssertEqual(ReasoningEffort(argument: "high"), .high)
        XCTAssertNil(ReasoningEffort(argument: "invalid"))
    }
    
    func testReasoningEffortCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        // Test encoding and decoding for each case
        let testCases: [ReasoningEffort] = [.minimal, .low, .medium, .high]
        
        for originalCase in testCases {
            let encoded = try encoder.encode(originalCase)
            let decoded = try decoder.decode(ReasoningEffort.self, from: encoded)
            XCTAssertEqual(originalCase, decoded)
            
            // Test JSON string representation
            let jsonString = String(data: encoded, encoding: .utf8)
            XCTAssertEqual(jsonString, "\"\(originalCase.rawValue)\"")
        }
    }
    
    // MARK: - Integration Tests
    
    func testEnumsAreDistinct() {
        // Ensure the enums have distinct values and don't overlap
        let verbosityValues = Set(VerbosityLevel.allCases.map { $0.rawValue })
        let reasoningValues = Set(ReasoningEffort.allCases.map { $0.rawValue })
        
        // Check that each enum has unique values
        XCTAssertEqual(verbosityValues.count, VerbosityLevel.allCases.count)
        XCTAssertEqual(reasoningValues.count, ReasoningEffort.allCases.count)
        
        // Check overlapping values (medium is in both, which is fine)
        let overlapping = verbosityValues.intersection(reasoningValues)
        XCTAssertEqual(overlapping, ["low", "medium", "high"])
    }
}