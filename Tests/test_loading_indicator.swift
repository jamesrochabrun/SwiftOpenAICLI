#!/usr/bin/env swift

import Foundation
import SwiftOpenAICLICore
import Rainbow

// Test the LoadingIndicator directly
print("Testing LoadingIndicator...")

// Test 1: Basic loading indicator
let indicator1 = LoadingIndicator(word: "Processing")
print("\nTest 1: Basic indicator for 3 seconds")
indicator1.start()
Thread.sleep(forTimeInterval: 3)
indicator1.stop()
print("✓ Test 1 complete")

// Test 2: Custom colored indicator
let indicator2 = LoadingIndicator(word: "Searching", color: { $0.cyan })
print("\nTest 2: Colored indicator for 2 seconds")
indicator2.start()
Thread.sleep(forTimeInterval: 2)
indicator2.stop()
print("✓ Test 2 complete")

// Test 3: Multiple indicators
print("\nTest 3: Multiple indicators sequentially")
let tools = ["Reading", "Writing", "Compiling"]
for tool in tools {
    let indicator = LoadingIndicator(word: tool, color: { $0.green })
    indicator.start()
    Thread.sleep(forTimeInterval: 1)
    indicator.stop()
    print("✓ \(tool) complete")
}

// Test 4: LoadingWordGenerator
print("\nTest 4: Testing LoadingWordGenerator")
Task {
    let generator = LoadingWordGenerator.shared
    
    // Test fallback words
    let words = ["bash", "file", "search", "thinking"]
    for word in words {
        let loadingWord = await generator.getLoadingWord(for: word, useAI: false)
        print("  Tool: \(word) -> \(loadingWord)")
    }
    
    print("\n✓ All tests complete!")
    exit(0)
}

RunLoop.main.run()