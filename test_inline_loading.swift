import Foundation

// Inline test of loading indicator concept
print("Testing inline loading indicator...")

func testLoadingAnimation() async {
    let words = ["Processing", "Searching", "Analyzing", "Computing"]
    
    for word in words {
        print("\nTesting: \(word)")
        
        // Start animation task
        let animationTask = Task { @MainActor in
            var dots = 0
            let maxDots = 3
            
            for _ in 0..<8 {  // Run for 8 iterations
                if Task.isCancelled { break }
                
                let dotsString = String(repeating: ".", count: dots)
                let spaces = String(repeating: " ", count: maxDots - dots)
                print("\r\(word)\(dotsString)\(spaces)  ", terminator: "")
                fflush(stdout)
                
                dots = (dots + 1) % 4
                try? await Task.sleep(nanoseconds: 400_000_000)
            }
        }
        
        // Let it run for a bit
        try? await Task.sleep(nanoseconds: 3_200_000_000)
        
        // Stop and clear
        animationTask.cancel()
        print("\r✓ \(word) complete                ")
    }
    
    print("\n✅ All animation tests complete!")
}

// Run the async test
Task {
    await testLoadingAnimation()
    exit(0)
}

RunLoop.main.run()