import Foundation
import XCTest
@testable import SwiftOpenAICLI

// Test error for simulating failures
enum TestError: Error, LocalizedError {
    case mockError(String)
    
    var errorDescription: String? {
        switch self {
        case .mockError(let message):
            return message
        }
    }
}

// Test output capture
class TestOutputCapture {
    private var output: String = ""
    
    func capture(_ text: String) {
        output += text
    }
    
    func captureWithNewline(_ text: String) {
        output += text + "\n"
    }
    
    var capturedOutput: String {
        return output
    }
    
    func reset() {
        output = ""
    }
}

// Test fixture for temporary files
class TestFileManager {
    private var temporaryDirectory: URL?
    
    func createTemporaryDirectory() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true
        )
        temporaryDirectory = tempDir
        return tempDir
    }
    
    func cleanup() {
        guard let tempDir = temporaryDirectory else { return }
        try? FileManager.default.removeItem(at: tempDir)
    }
}

// Assert helpers
extension XCTestCase {
    func assertContains(_ string: String, in text: String, file: StaticString = #file, line: UInt = #line) {
        XCTAssertTrue(text.contains(string), "Expected '\(text)' to contain '\(string)'", file: file, line: line)
    }
    
    func assertNotContains(_ string: String, in text: String, file: StaticString = #file, line: UInt = #line) {
        XCTAssertFalse(text.contains(string), "Expected '\(text)' to not contain '\(string)'", file: file, line: line)
    }
}

// Mock factory for creating test services
class MockServiceFactory {
    static func createMockConfigurationManager() -> MockConfigurationManager {
        return MockConfigurationManager()
    }
}