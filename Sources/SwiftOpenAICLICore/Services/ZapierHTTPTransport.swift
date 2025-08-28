import Foundation
import MCP
import System
import Logging

/// A custom HTTP transport specifically designed for Zapier MCP servers
/// Handles the specific header requirements that Zapier needs
actor ZapierHTTPTransport: Transport {
    private let endpoint: URL
    private let session: URLSession
    private var isConnected = false
    private var pendingResponses: [Data] = []
    private var continuation: AsyncThrowingStream<Data, Error>.Continuation?
    
    nonisolated let logger = Logger(label: "ZapierHTTPTransport")
    
    init(endpoint: URL) {
        self.endpoint = endpoint
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 120
        self.session = URLSession(configuration: config)
    }
    
    func connect() async throws {
        isConnected = true
    }
    
    func disconnect() async {
        isConnected = false
        continuation?.finish()
        continuation = nil
        pendingResponses.removeAll()
    }
    
    func send(_ data: Data) async throws {
        guard isConnected else {
            throw ZapierTransportError.notConnected
        }
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        
        // Set the specific headers that Zapier requires
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("2024-11-05", forHTTPHeaderField: "MCP-Protocol-Version")
        request.setValue("SwiftOpenAICLI/1.0.0", forHTTPHeaderField: "User-Agent")
        
        request.httpBody = data
        
        // Make the request and handle response
        let (responseData, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ZapierTransportError.invalidResponse
        }
        
        // Accept both 200 (OK) and 202 (Accepted) as valid responses
        if httpResponse.statusCode != 200 && httpResponse.statusCode != 202 {
            let errorMessage = "HTTP \(httpResponse.statusCode)"
            if let errorData = String(data: responseData, encoding: .utf8) {
                logger.error("Error response: \(errorData)")
            }
            throw ZapierTransportError.httpError(errorMessage)
        }
        
        // Handle the response - check if it's SSE format or regular JSON
        var responseToStore: Data = responseData
        
        if let responseString = String(data: responseData, encoding: .utf8) {
            // Check if this is SSE format
            if responseString.contains("event: message") && responseString.contains("data: ") {
                let lines = responseString.components(separatedBy: .newlines)
                
                for line in lines {
                    if line.hasPrefix("data: ") {
                        let jsonPart = String(line.dropFirst(6)) // Remove "data: " prefix
                        if let jsonData = jsonPart.data(using: .utf8) {
                            responseToStore = jsonData
                            break
                        }
                    }
                }
            }
        }
        
        // Log the actual response for debugging (only when needed)
        if let responseString = String(data: responseToStore, encoding: .utf8) {
            // Check if this looks like an unexpected message
            if !responseString.contains("\"jsonrpc\"") && !responseString.contains("\"result\"") && !responseString.contains("\"method\"") {
                logger.info("Zapier response (non-MCP format): \(responseString)")
            }
        }
        
        // Add the response to pending queue and notify continuation
        pendingResponses.append(responseToStore)
        
        // If we have a continuation waiting, send the response
        if let continuation = self.continuation {
            while !pendingResponses.isEmpty {
                let response = pendingResponses.removeFirst()
                continuation.yield(response)
            }
        }
    }
    
    nonisolated func receive() -> AsyncThrowingStream<Data, Error> {
        return AsyncThrowingStream { continuation in
            Task { [weak self] in
                guard let self = self else {
                    continuation.finish(throwing: ZapierTransportError.notConnected)
                    return
                }
                
                await self.setContinuation(continuation)
                
                // Send any pending responses
                await self.flushPendingResponses()
            }
        }
    }
    
    private func setContinuation(_ continuation: AsyncThrowingStream<Data, Error>.Continuation) {
        self.continuation = continuation
    }
    
    private func flushPendingResponses() {
        guard let continuation = self.continuation else { return }
        
        while !pendingResponses.isEmpty {
            let response = pendingResponses.removeFirst()
            continuation.yield(response)
        }
    }
}

enum ZapierTransportError: LocalizedError {
    case invalidData
    case invalidResponse
    case httpError(String)
    case notConnected
    
    var errorDescription: String? {
        switch self {
        case .invalidData:
            return "Invalid data format"
        case .invalidResponse:
            return "Invalid HTTP response"
        case .httpError(let message):
            return "HTTP error: \(message)"
        case .notConnected:
            return "Transport not connected"
        }
    }
}