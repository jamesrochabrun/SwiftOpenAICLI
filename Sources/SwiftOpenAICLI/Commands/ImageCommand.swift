import ArgumentParser
import Foundation
import SwiftOpenAI
import Rainbow

struct ImageCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "image",
        abstract: "Generate images with AI models"
    )
    
    @Argument(help: "The prompt for image generation")
    var prompt: String
    
    @Option(name: [.short, .long], help: "Number of images to generate (1-10)")
    var number: Int = 1
    
    @Option(name: .long, help: "Image size (256x256, 512x512, 1024x1024, 1024x1792, 1792x1024)")
    var size: String = "1024x1024"
    
    @Option(name: .long, help: "Model to use (dall-e-2, dall-e-3)")
    var model: String = "dall-e-3"
    
    @Option(name: .long, help: "Image quality (standard, hd)")
    var quality: String = "standard"
    
    @Option(name: .long, help: "Output directory for saving images")
    var output: String = "."
    
    mutating func run() async throws {
        print("Generating image with prompt: \"\(prompt)\"".cyan)
        print("Model: \(model), Size: \(size), Quality: \(quality)".green)
        
        do {
            let response = try await OpenAIService.shared.generateImage(
                prompt: prompt,
                model: model,
                size: size,
                quality: quality,
                n: number
            )
            
            guard let images = response.data else {
                print("No images were generated".yellow)
                return
            }
            
            print("\nGenerated \(images.count) image(s):".green)
            
            for (index, image) in images.enumerated() {
                if let urlString = image.url, let url = URL(string: urlString) {
                    print("\(index + 1). URL: \(url.absoluteString)")
                    
                    // Download and save if output directory is specified
                    if output != "." {
                        try await saveImage(from: url, index: index + 1)
                    }
                } else if let b64 = image.b64JSON {
                    print("\(index + 1). Base64 data received (length: \(b64.count))")
                    
                    // Save base64 image if output directory is specified
                    if output != "." {
                        try saveBase64Image(b64, index: index + 1)
                    }
                }
            }
        } catch {
            print("Error generating image: \(error.localizedDescription)".red)
            throw ExitCode.failure
        }
    }
    
    private func saveImage(from url: URL, index: Int) async throws {
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let filename = "dalle_\(index)_\(Date().timeIntervalSince1970).png"
        let outputURL = URL(fileURLWithPath: output).appendingPathComponent(filename)
        
        try data.write(to: outputURL)
        print("   Saved to: \(outputURL.path)".lightBlack)
    }
    
    private func saveBase64Image(_ base64: String, index: Int) throws {
        guard let data = Data(base64Encoded: base64) else { return }
        
        let filename = "dalle_\(index)_\(Date().timeIntervalSince1970).png"
        let outputURL = URL(fileURLWithPath: output).appendingPathComponent(filename)
        
        try data.write(to: outputURL)
        print("   Saved to: \(outputURL.path)".lightBlack)
    }
}