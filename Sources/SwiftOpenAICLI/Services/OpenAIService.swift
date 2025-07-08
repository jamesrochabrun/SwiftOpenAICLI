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
            print("2. CLI config: swiftopenai config set api-key sk-...")
            throw OpenAIServiceError.noAPIKey
        }
        
        if service == nil {
            // Check if we have a custom provider configuration
            if let _ = ConfigurationManager.shared.provider,
               let baseURL = ConfigurationManager.shared.baseURL {
                // Use custom provider configuration
                let debugEnabled = ConfigurationManager.shared.debugEnabled ?? false
                service = OpenAIServiceFactory.service(
                    apiKey: apiKey,
                    overrideBaseURL: baseURL,
                    debugEnabled: debugEnabled
                )
            } else {
                // Use standard OpenAI configuration
                let debugEnabled = ConfigurationManager.shared.debugEnabled ?? false
                service = OpenAIServiceFactory.service(
                    apiKey: apiKey,
                    debugEnabled: debugEnabled
                )
            }
        }
        
        return service!
    }
    
    func chat(message: String, model: String, system: String? = nil, temperature: Double = 1.0, maxTokens: Int? = nil, stream: Bool = true, plain: Bool = false) async throws {
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
            if !plain {
                print("Assistant: ".cyan, terminator: "")
                fflush(stdout)
            }
            
            let stream = try await openAI.startStreamedChat(parameters: parameters)
            
            for try await result in stream {
                if let content = result.choices?.first?.delta?.content {
                    print(content, terminator: "")
                    fflush(stdout)
                }
            }
            print() // New line after streaming
        } else {
            // Show loading indicator for non-streaming mode
            if !plain {
                print("Thinking...".lightBlack, terminator: "")
                fflush(stdout)
            }
            
            let result = try await openAI.startChat(parameters: parameters)
            
            // Clear the loading indicator
            if !plain {
                print("\r", terminator: "") // Carriage return to overwrite "Thinking..."
                fflush(stdout)
            }
            
            if let content = result.choices?.first?.message?.content {
                if plain {
                    print(content)
                } else {
                    print("Assistant: ".cyan + content)
                }
            }
        }
    }
    
    func listModels() async throws -> [ModelObject] {
        let openAI = try getService()
        let response = try await openAI.listModels()
        return response.data.sorted { $0.id < $1.id }
    }
    
    func generateImage(prompt: String, model: String, size: String, quality: String, n: Int) async throws -> CreateImageResponse {
        let openAI = try getService()
        
        let imageModel: CreateImageParameters.Model = model == "dall-e-2" ? .dallE2 : .dallE3
        let imageQuality: CreateImageParameters.Quality = quality == "hd" ? .hd : .standard
        
        let parameters = CreateImageParameters(
            prompt: prompt,
            model: imageModel,
            n: n,
            quality: imageQuality,
            size: size
        )
        
        return try await openAI.createImages(parameters: parameters)
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