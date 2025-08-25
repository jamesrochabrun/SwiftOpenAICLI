import XCTest
@testable import SwiftOpenAICLICore

final class OpenAIServiceErrorTests: XCTestCase {
    
    func testNoAPIKeyError() {
        let error = OpenAIServiceError.noAPIKey
        XCTAssertEqual(error.errorDescription, "No OpenAI API key configured")
    }
}