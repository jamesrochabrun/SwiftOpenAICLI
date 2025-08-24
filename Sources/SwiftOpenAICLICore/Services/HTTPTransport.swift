import Foundation
import MCP
import Logging

/// A transport that communicates with an HTTP-based MCP server
actor HTTPTransport {
    private let endpoint: URL
    private let verbose: Bool
    private var httpTransport: HTTPClientTransport?
    
    nonisolated let logger = Logger(label: "HTTPTransport")
    
    init(endpoint: URL, verbose: Bool = false) {
        self.endpoint = endpoint
        self.verbose = verbose
    }
    
    func getTransport() -> HTTPClientTransport {
        if let transport = httpTransport {
            return transport
        }
        
        // Create HTTP transport with streaming support for real-time updates
        let transport = HTTPClientTransport(
            endpoint: endpoint,
            streaming: true // Enable Server-Sent Events
        )
        
        if verbose {
            print("[HTTPTransport] Created transport for endpoint: \(endpoint)")
        }
        
        httpTransport = transport
        return transport
    }
}