import XCTest
@testable import SwiftOpenAICLI

final class ConfigurationErrorTests: XCTestCase {
    
    func testUnknownKeyError() {
        let error = ConfigurationError.unknownKey("invalid-key")
        XCTAssertEqual(error.errorDescription, "Unknown configuration key: 'invalid-key'")
    }
    
    func testInvalidValueError() {
        let error = ConfigurationError.invalidValue(key: "temperature", value: "invalid")
        XCTAssertEqual(error.errorDescription, "Invalid value 'invalid' for key 'temperature'")
    }
    
}