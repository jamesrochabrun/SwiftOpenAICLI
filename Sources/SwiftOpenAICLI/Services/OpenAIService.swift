import Foundation
import SwiftOpenAI
import Rainbow

class OpenAIService {
    static let shared = OpenAIService()
    
    private var service: (any SwiftOpenAI.OpenAIService)?
    
    private init() {}
    
    func getService() throws -> any SwiftOpenAI.OpenAIService {
        guard let apiKey = ConfigurationManager.shared.apiKey else {
            print("✗ No API key found!".red)
            print("Set your API key using one of these methods:".yellow)
            print("1. Environment variable: export OPENAI_API_KEY=sk-...")
            print("2. CLI config: openai config set api-key sk-...")
            throw OpenAIServiceError.noAPIKey
        }
        
        if service == nil {
            service = OpenAIServiceFactory.service(apiKey: apiKey)
        }
        
        return service!
    }
    
    func chat(message: String, model: String, system: String? = nil, temperature: Double = 1.0, maxTokens: Int? = nil, stream: Bool = true) async throws {
        let openAI = try getService()
        
        var messages: [ChatCompletionParameters.Message] = []
        
        if let system = system {
            messages.append(.init(role: .system, content: .text(system)))
        }
        
        messages.append(.init(role: .user, content: .text(message)))
        
        let parameters = ChatCompletionParameters(
            messages: messages,
            model: .custom(model),
            maxTokens: maxTokens,
            temperature: temperature
        )
        
        if stream {
            print("Assistant: ".cyan, terminator: "")
            fflush(stdout)
            
            let stream = try await openAI.startStreamedChat(parameters: parameters)
            
            for try await result in stream {
                if let content = result.choices.first?.delta.content {
                    print(content, terminator: "")
                    fflush(stdout)
                }
            }
            print() // New line after streaming
        } else {
            let result = try await openAI.startChat(parameters: parameters)
            if let content = result.choices.first?.message.content {
                print("Assistant: ".cyan + content)
            }
        }
    }
    
    func listModels() async throws -> [ModelObject] {
        let openAI = try getService()
        let response = try await openAI.listModels()
        return response.data.sorted { $0.id < $1.id }
    }
    
    func generateImage(prompt: String, model: String, size: String, quality: String, n: Int) async throws -> [ImageObject] {
        let openAI = try getService()
        
        let dalleModel: Dalle
        if model == "dall-e-2" {
            let imageSize: Dalle.Dalle2ImageSize = switch size {
            case "256x256": .small
            case "512x512": .medium
            case "1024x1024": .large
            default: .large
            }
            dalleModel = .dalle2(imageSize)
        } else {
            let imageSize: Dalle.Dalle3ImageSize = switch size {
            case "1024x1024": .largeSquare
            case "1792x1024": .landscape
            case "1024x1792": .portrait
            default: .largeSquare
            }
            dalleModel = .dalle3(imageSize)
        }
        
        let parameters = ImageCreateParameters(
            prompt: prompt,
            model: dalleModel,
            numberOfImages: n,
            quality: quality == "hd" ? "hd" : "standard"
        )
        
        let response = try await openAI.createImages(parameters: parameters)
        return response.data
    }
    
    // Completions API is deprecated, use chat instead
    
    func generateEmbedding(text: String, model: String, dimensions: Int? = nil) async throws -> [Float] {
        let openAI = try getService()
        
        let parameters = EmbeddingParameter(
            input: text,
            model: .textEmbeddingAda002,  // Only ada-002 is supported in the enum
            encodingFormat: "float",
            dimensions: dimensions
        )
        
        let response = try await openAI.createEmbeddings(parameters: parameters)
        return response.data.first?.embedding ?? []
    }
}

enum OpenAIServiceError: LocalizedError {
    case noAPIKey
    
    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "No OpenAI API key configured"
        }
    }
}