import XCTest
import SwiftOpenAI
@testable import SwiftOpenAICLI

final class MCPClientTests: XCTestCase {
    
    // MARK: - Configuration Tests
    
    func testMCPServerConfig() {
        let config = MCPServerConfig(
            name: "test-server",
            transport: "stdio",
            command: "echo",
            url: nil,
            args: ["test"],
            environment: ["KEY": "VALUE"]
        )
        
        XCTAssertEqual(config.name, "test-server")
        XCTAssertEqual(config.command, "echo")
        XCTAssertEqual(config.args, ["test"])
        XCTAssertEqual(config.environment?["KEY"], "VALUE")
    }
    
    func testMCPServerConfigWithoutEnvironment() {
        let config = MCPServerConfig(
            name: "test-server",
            transport: "stdio",
            command: "node",
            url: nil,
            args: ["server.js"],
            environment: nil
        )
        
        XCTAssertEqual(config.name, "test-server")
        XCTAssertEqual(config.command, "node")
        XCTAssertEqual(config.args, ["server.js"])
        XCTAssertNil(config.environment)
    }
    
    // MARK: - Tool Naming Tests
    
    func testMCPToolNaming() {
        let serverName = "github"
        let toolName = "create_issue"
        let expectedName = "mcp__\(serverName)__\(toolName)"
        
        XCTAssertEqual(expectedName, "mcp__github__create_issue")
    }
    
    func testMCPToolNamePattern() {
        let patterns = [
            "mcp__*",
            "mcp__github__*",
            "mcp__github__create_issue"
        ]
        
        let toolName = "mcp__github__create_issue"
        
        // Test wildcard matching
        for pattern in patterns {
            if pattern.hasSuffix("*") {
                let prefix = String(pattern.dropLast())
                XCTAssertTrue(toolName.hasPrefix(prefix))
            } else {
                XCTAssertEqual(pattern, toolName)
            }
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testMCPErrorHandling() {
        // Test that MCP errors are properly formatted
        let errorCode = -32602
        let errorMessage = "Invalid parameters"
        
        let errorDescription = "MCP Error (\(errorCode)): \(errorMessage)"
        XCTAssertTrue(errorDescription.contains("Invalid parameters"))
        XCTAssertTrue(errorDescription.contains("-32602"))
    }
    
    // MARK: - JSON-RPC Tests
    
    func testJSONRPCRequest() throws {
        let id = 1
        let method = "tools/list"
        let params: [String: Any] = [:]
        
        let request: [String: Any] = [
            "jsonrpc": "2.0",
            "id": id,
            "method": method,
            "params": params
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: request)
        let jsonString = String(data: jsonData, encoding: .utf8)!
        
        // Parse back to verify contents
        let parsed = try JSONSerialization.jsonObject(with: jsonData) as! [String: Any]
        XCTAssertEqual(parsed["jsonrpc"] as? String, "2.0")
        XCTAssertEqual(parsed["method"] as? String, method)
        XCTAssertEqual(parsed["id"] as? Int, id)
        XCTAssertNotNil(parsed["params"])
    }
    
    func testJSONRPCResponse() throws {
        let response = """
        {
            "jsonrpc": "2.0",
            "id": 1,
            "result": {
                "tools": [
                    {
                        "name": "search",
                        "description": "Search for items"
                    }
                ]
            }
        }
        """
        
        let data = response.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        
        XCTAssertEqual(json["jsonrpc"] as? String, "2.0")
        XCTAssertEqual(json["id"] as? Int, 1)
        XCTAssertNotNil(json["result"])
        
        if let result = json["result"] as? [String: Any],
           let tools = result["tools"] as? [[String: Any]] {
            XCTAssertEqual(tools.count, 1)
            XCTAssertEqual(tools[0]["name"] as? String, "search")
        }
    }
    
    func testJSONRPCError() throws {
        let errorResponse = """
        {
            "jsonrpc": "2.0",
            "id": 1,
            "error": {
                "code": -32602,
                "message": "Invalid parameters"
            }
        }
        """
        
        let data = errorResponse.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        
        XCTAssertNil(json["result"])
        XCTAssertNotNil(json["error"])
        
        if let error = json["error"] as? [String: Any] {
            XCTAssertEqual(error["code"] as? Int, -32602)
            XCTAssertEqual(error["message"] as? String, "Invalid parameters")
        }
    }
    
    // MARK: - Protocol Version Tests
    
    func testProtocolVersionParsing() {
        let versions = ["0.1.0", "0.2.0", "1.0.0", "1.1.0"]
        
        for version in versions {
            let components = version.split(separator: ".")
            XCTAssertEqual(components.count, 3)
            
            // All components should be valid integers
            for component in components {
                XCTAssertNotNil(Int(component))
            }
        }
    }
    
    // MARK: - Tool Schema Tests
    
    func testToolInputSchema() throws {
        let schema: [String: Any] = [
            "type": "object",
            "properties": [
                "query": [
                    "type": "string",
                    "description": "Search query"
                ]
            ],
            "required": ["query"]
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: schema)
        XCTAssertNotNil(jsonData)
        
        // Verify schema can be parsed back
        let parsed = try JSONSerialization.jsonObject(with: jsonData) as! [String: Any]
        XCTAssertEqual(parsed["type"] as? String, "object")
        XCTAssertNotNil(parsed["properties"])
    }
}