import Foundation

// Simple test to verify randomElement works
let words = ["Pondering", "Cogitating", "Ruminating", "Contemplating", "Musing", "Deliberating"]

print("Testing randomElement():")
for _ in 0..<10 {
    print("  - \(words.randomElement() ?? "none")")
}

// Test if the AI generation timeout might be the issue
print("\nTesting timeout:")
Task {
    let start = Date()
    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
    let elapsed = Date().timeIntervalSince(start)
    print("  Timeout elapsed: \(elapsed) seconds")
    exit(0)
}

RunLoop.main.run()