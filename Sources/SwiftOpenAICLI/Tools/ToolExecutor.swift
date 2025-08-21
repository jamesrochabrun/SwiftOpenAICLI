import Foundation
import SwiftOpenAI
import Rainbow

class ToolExecutor {
  private var availableTools: [String: CLITool] = [:]
  private var mcpClient: MCPClient?
  private var mcpServers: [MCPServerConfig] = []
  private let verbose: Bool
  private let useStderr: Bool
  
  init(mcpServers: [MCPServerConfig] = [], verbose: Bool = false, useStderr: Bool = false) {
    self.mcpServers = mcpServers
    self.verbose = verbose
    self.useStderr = useStderr
  }
  
  func initialize() async {
    if !mcpServers.isEmpty {
      await initializeMCPServers(verbose: self.verbose)
    }
  }
  
  
  private func printStatus(_ message: String) {
    if useStderr {
      FileHandle.standardError.write(Data("\(message)\n".utf8))
    } else {
      print(message)
    }
  }
  
  func getAllAvailableToolNames() -> Set<String> {
    return Set(availableTools.keys)
  }
  
  func getToolDefinitions(for toolNames: Set<String>?) -> [ChatCompletionParameters.Tool] {
    var effectiveToolNames = Set<String>()
    
    if let toolNames = toolNames {
      // Process each pattern in toolNames
      for pattern in toolNames {
        if pattern.contains("*") {
          // Handle glob patterns
          let regex = patternToRegex(pattern)
          for toolName in availableTools.keys {
            if toolName.range(of: regex, options: .regularExpression) != nil {
              effectiveToolNames.insert(toolName)
            }
          }
        } else {
          // Exact match
          if availableTools[pattern] != nil {
            effectiveToolNames.insert(pattern)
          }
        }
      }
    } else {
      // No specific tools requested, include all MCP tools
      for toolName in availableTools.keys {
        if toolName.hasPrefix("mcp__") {
          effectiveToolNames.insert(toolName)
        }
      }
    }
    
    return effectiveToolNames.compactMap { name in
      guard let tool = availableTools[name] else { return nil }
      return ChatCompletionParameters.Tool(
        type: "function",
        function: tool.toChatFunction()
      )
    }
  }
  
  private func patternToRegex(_ pattern: String) -> String {
    // Convert glob pattern to regex
    var regex = "^"
    for char in pattern {
      switch char {
      case "*":
        regex += ".*"
      case "?":
        regex += "."
      case ".":
        regex += "\\."
      default:
        regex += String(char)
      }
    }
    regex += "$"
    return regex
  }
  
  func executeTool(name: String, arguments: String, outputFormat: String = "plain") async throws -> String {
    guard let tool = availableTools[name] else {
      return "Error: Unknown tool '\(name)'"
    }
    
    // Only show detailed tool execution in plain format (silent mode shows nothing)
    if outputFormat == "plain" {
      print("\n🔧 Executing tool: \(name)".lightBlack)
      print("   Arguments: \(arguments)".lightBlack)
    }
    
    let result = try await tool.execute(arguments: arguments)
    
    if outputFormat == "plain" {
      print("   Result: \(result)".lightBlack)
    }
    
    return result
  }
  
  func printAvailableTools() {
    print("Available MCP tools:".cyan)
    
    let mcpTools = availableTools.filter { $0.key.hasPrefix("mcp__") }
    if !mcpTools.isEmpty {
      for (name, tool) in mcpTools.sorted(by: { $0.key < $1.key }) {
        print("  • \(name): \(tool.description)".lightBlack)
      }
    } else {
      print("  No MCP tools available. Configure MCP servers to add tools.".yellow)
    }
  }
  
  private func initializeMCPServers(verbose: Bool) async {
    mcpClient = MCPClient(verbose: verbose, useStderr: useStderr)
    
    for server in mcpServers {
      do {
        try await mcpClient?.connectToServer(server)
        await registerMCPTools(from: server.name)
      } catch {
        if verbose {
          printStatus("⚠️  Failed to connect to MCP server '\(server.name)': \(error.localizedDescription)".yellow)
        }
      }
    }
  }
  
  private func registerMCPTools(from serverName: String) async {
    guard let mcpClient = mcpClient else { return }
    
    do {
      let tools = try await mcpClient.getAvailableTools()
      
      for (toolKey, mcpTool) in tools {
        if toolKey.hasPrefix("\(serverName).") {
          let adapter = MCPToolAdapter(
            serverName: serverName,
            tool: mcpTool,
            mcpClient: mcpClient
          )
          // Use the sanitized name from the adapter (mcp__serverName__toolName)
          availableTools[adapter.name] = adapter
          if verbose {
            printStatus("   Registered tool: \(adapter.name)".lightBlack)
          }
        }
      }
    } catch {
      if verbose {
        printStatus("⚠️  Failed to register tools from '\(serverName)': \(error.localizedDescription)".yellow)
      }
    }
  }
  
  func connectMCPServer(_ config: MCPServerConfig, verbose: Bool = false) async throws {
    if mcpClient == nil {
      mcpClient = MCPClient(verbose: verbose, useStderr: useStderr)
    }
    
    try await mcpClient?.connectToServer(config)
    await registerMCPTools(from: config.name)
  }
  
  func disconnectMCPServer(_ name: String) async {
    await mcpClient?.disconnectFromServer(name)
    
    availableTools = availableTools.filter { !$0.key.hasPrefix("mcp__\(name)__") }
  }
  
  func cleanup() async {
    // Disconnect all MCP servers gracefully
    if let mcpClient = mcpClient {
      await mcpClient.disconnectAll()
    }
    
    // Clear all MCP tools from available tools
    availableTools = availableTools.filter { !$0.key.hasPrefix("mcp__") }
  }
  
  deinit {
    // Don't create Task in deinit - it causes retain cycle
    // The MCPClient actor will clean up on its own deallocation
  }
  
}
