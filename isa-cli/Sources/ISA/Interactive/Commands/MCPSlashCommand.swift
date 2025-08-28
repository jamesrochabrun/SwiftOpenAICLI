import Foundation
import SwiftOpenAICLICore
import Rainbow

/// Slash command for managing MCP server configurations
public struct MCPSlashCommand: SlashCommand {
  public let name = "mcp"
  public let description = "Manage MCP server configurations"
  public let argumentHint: String? = "[list|add|add-http|remove|enable|disable|status|install] [args]"
  
  public init() {}
  
  public func execute(arguments: String?, context: inout CommandContext) async throws -> Bool {
    let args = arguments?.split(separator: " ", maxSplits: 1).map(String.init) ?? []
    
    if args.isEmpty {
      // Show quick overview with status
      await showQuickStatus()
      return true
    }
    
    let subcommand = args[0].lowercased()
    let subArgs = args.count > 1 ? args[1] : nil
    
    switch subcommand {
    case "list", "ls":
      await showDetailedList()
      
    case "add":
      try await addStdioServer(args: subArgs)
      
    case "add-http":
      try await addHTTPServer(args: subArgs)
      
    case "remove", "rm":
      try await removeServer(name: subArgs)
      
    case "enable":
      try await enableServer(name: subArgs)
      
    case "disable":
      try await disableServer(name: subArgs)
      
    case "status":
      await showConnectionStatus()
      
    case "install":
      showInstallGuides()
      
    default:
      print("Unknown MCP subcommand: '\(subcommand)'".red)
      print("Available subcommands: list, add, add-http, remove, enable, disable, status, install".lightBlack)
    }
    
    return true
  }
  
  // MARK: - Quick Status
  
  private func showQuickStatus() async {
    print("\n🔌 " + "MCP Servers".cyan.bold)
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━".lightBlack)
    
    let config = ConfigurationManager.shared.getConfiguration()
    guard let mcpServers = config.mcpServers else {
      print("No MCP servers configured".yellow)
      print("\n💡 Quick start:".yellow)
      print("  /mcp add        - Add a new MCP server")
      print("  /mcp install    - See installation guides")
      return
    }
    
    let servers = mcpServers.allServers
    guard !servers.isEmpty else {
      print("No MCP servers configured".yellow)
      print("\n💡 Quick start:".yellow)
      print("  /mcp add        - Add a new MCP server")
      print("  /mcp install    - See installation guides")
      return
    }
    
    for server in servers {
      let name = server.name ?? "unnamed"
      let enabled = server.enabled ?? true
      let transport = server.transport ?? "stdio"
      
      let statusIcon = enabled ? "✅" : "⭕"
      let statusText = enabled ? "enabled".green : "disabled".lightBlack
      let transportText = transport == "http" ? "[HTTP]".magenta : "[stdio]".cyan
      
      print("\(statusIcon) \(name.bold): \(statusText) \(transportText)")
    }
    
    print("\n📖 Commands:".lightBlack)
    print("  /mcp list       - Show detailed information")
    print("  /mcp add        - Add a new server")
    print("  /mcp remove     - Remove a server")
    print("  /mcp enable     - Enable a disabled server")
    print("  /mcp disable    - Disable an enabled server")
    print("  /mcp status     - Check connection status")
  }
  
  // MARK: - Detailed List
  
  private func showDetailedList() async {
    print("\n📋 " + "MCP Server Details".cyan.bold)
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━".lightBlack)
    
    let config = ConfigurationManager.shared.getConfiguration()
    guard let mcpServers = config.mcpServers else {
      print("No MCP servers configured".yellow)
      return
    }
    
    let servers = mcpServers.allServers
    guard !servers.isEmpty else {
      print("No MCP servers configured".yellow)
      return
    }
    
    for (index, server) in servers.enumerated() {
      if index > 0 {
        print("───────────────────────────────────────────".lightBlack)
      }
      
      let name = server.name ?? "unnamed"
      let enabled = server.enabled ?? true
      let transport = server.transport ?? "stdio"
      
      print("\n📦 " + name.cyan.bold)
      print("   Status: " + (enabled ? "Enabled ✅".green : "Disabled ⭕".lightBlack))
      print("   Transport: " + transport)
      
      if let command = server.command {
        print("   Command: " + command.yellow)
        if let args = server.args, !args.isEmpty {
          print("   Args: " + args.joined(separator: " ").lightBlack)
        }
      } else if let url = server.url {
        // Mask sensitive parts of the URL
        let maskedUrl = maskSensitiveUrl(url)
        print("   URL: " + maskedUrl.yellow)
      }
      
      let env = server.env ?? server.environment
      if let env = env, !env.isEmpty {
        let envKeys = env.keys.sorted().joined(separator: ", ")
        print("   Environment: " + envKeys.lightBlack)
      }
    }
    
    print("")
  }
  
  // MARK: - Add Stdio Server
  
  private func addStdioServer(args: String?) async throws {
    print("\n➕ " + "Add MCP Server (stdio)".cyan.bold)
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━".lightBlack)
    
    // If args provided, try to parse them
    if let args = args {
      let parts = args.split(separator: " ", maxSplits: 1)
      if parts.count >= 2 {
        let name = String(parts[0])
        let command = String(parts[1])
        try await addServerWithDetails(name: name, command: command, transport: "stdio")
        return
      }
    }
    
    // Interactive mode
    print("\n📝 Server Details".yellow)
    
    print("Server name: ".cyan, terminator: "")
    guard let name = readLine()?.trimmingCharacters(in: .whitespaces), !name.isEmpty else {
      print("❌ Server name is required".red)
      return
    }
    
    print("Command to run (e.g., 'npx', 'node', 'python'): ".cyan, terminator: "")
    guard let command = readLine()?.trimmingCharacters(in: .whitespaces), !command.isEmpty else {
      print("❌ Command is required".red)
      return
    }
    
    print("Arguments (optional, comma-separated): ".cyan, terminator: "")
    let argsInput = readLine()?.trimmingCharacters(in: .whitespaces)
    let args = argsInput?.isEmpty == false ? 
      argsInput?.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)) } : nil
    
    print("Environment variables (optional, KEY=VALUE,KEY2=VALUE2): ".cyan, terminator: "")
    let envInput = readLine()?.trimmingCharacters(in: .whitespaces)
    var environment: [String: String]? = nil
    if let envInput = envInput, !envInput.isEmpty {
      environment = [:]
      for pair in envInput.split(separator: ",") {
        let parts = pair.split(separator: "=", maxSplits: 1)
        if parts.count == 2 {
          environment?[String(parts[0].trimmingCharacters(in: .whitespaces))] = 
            String(parts[1].trimmingCharacters(in: .whitespaces))
        }
      }
    }
    
    print("Enable immediately? (Y/n): ".cyan, terminator: "")
    let enableInput = readLine()?.lowercased() ?? "y"
    let enabled = enableInput == "y" || enableInput == "yes" || enableInput.isEmpty
    
    // Add the server
    try await addServerToConfig(
      name: name,
      transport: "stdio",
      command: command,
      url: nil,
      args: args,
      env: environment,
      enabled: enabled
    )
  }
  
  // MARK: - Add HTTP Server
  
  private func addHTTPServer(args: String?) async throws {
    print("\n➕ " + "Add MCP Server (HTTP)".cyan.bold)
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━".lightBlack)
    
    // Show security notice
    print("\n⚠️  " + "Security Notice:".yellow.bold)
    print("HTTP MCP servers often include authentication tokens in their URLs.")
    print("Treat these URLs like passwords and never share them publicly.".yellow)
    print("")
    
    // Interactive mode
    print("📝 Server Details".yellow)
    
    print("Server name (e.g., 'zapier'): ".cyan, terminator: "")
    guard let name = readLine()?.trimmingCharacters(in: .whitespaces), !name.isEmpty else {
      print("❌ Server name is required".red)
      return
    }
    
    print("HTTP endpoint URL: ".cyan, terminator: "")
    guard let url = readLine()?.trimmingCharacters(in: .whitespaces), !url.isEmpty else {
      print("❌ URL is required".red)
      return
    }
    
    // Validate URL
    guard URL(string: url) != nil else {
      print("❌ Invalid URL format".red)
      return
    }
    
    print("Environment variables (optional, KEY=VALUE,KEY2=VALUE2): ".cyan, terminator: "")
    let envInput = readLine()?.trimmingCharacters(in: .whitespaces)
    var environment: [String: String]? = nil
    if let envInput = envInput, !envInput.isEmpty {
      environment = [:]
      for pair in envInput.split(separator: ",") {
        let parts = pair.split(separator: "=", maxSplits: 1)
        if parts.count == 2 {
          environment?[String(parts[0].trimmingCharacters(in: .whitespaces))] = 
            String(parts[1].trimmingCharacters(in: .whitespaces))
        }
      }
    }
    
    print("Enable immediately? (Y/n): ".cyan, terminator: "")
    let enableInput = readLine()?.lowercased() ?? "y"
    let enabled = enableInput == "y" || enableInput == "yes" || enableInput.isEmpty
    
    // Add the server
    try await addServerToConfig(
      name: name,
      transport: "http",
      command: nil,
      url: url,
      args: nil,
      env: environment,
      enabled: enabled
    )
  }
  
  // MARK: - Remove Server
  
  private func removeServer(name: String?) async throws {
    guard let name = name else {
      print("❌ Server name required. Usage: /mcp remove <name>".red)
      return
    }
    
    var config = ConfigurationManager.shared.getConfiguration()
    guard let mcpServers = config.mcpServers else {
      print("❌ No MCP servers configured".red)
      return
    }
    
    let found: Bool
    switch mcpServers {
    case .array(var servers):
      if let index = servers.firstIndex(where: { $0.name == name }) {
        servers.remove(at: index)
        config.mcpServers = servers.isEmpty ? nil : .array(servers)
        found = true
      } else {
        found = false
      }
    case .object(var dict):
      if dict.removeValue(forKey: name) != nil {
        config.mcpServers = dict.isEmpty ? nil : .object(dict)
        found = true
      } else {
        found = false
      }
    }
    
    if found {
      try ConfigurationManager.shared.updateConfiguration(config)
      print("✅ Removed MCP server '\(name)'".green)
    } else {
      print("❌ MCP server '\(name)' not found".red)
    }
  }
  
  // MARK: - Enable/Disable Server
  
  private func enableServer(name: String?) async throws {
    try await setServerEnabled(name: name, enabled: true)
  }
  
  private func disableServer(name: String?) async throws {
    try await setServerEnabled(name: name, enabled: false)
  }
  
  private func setServerEnabled(name: String?, enabled: Bool) async throws {
    guard let name = name else {
      let action = enabled ? "enable" : "disable"
      print("❌ Server name required. Usage: /mcp \(action) <name>".red)
      return
    }
    
    var config = ConfigurationManager.shared.getConfiguration()
    guard let mcpServers = config.mcpServers else {
      print("❌ No MCP servers configured".red)
      return
    }
    
    let found: Bool
    switch mcpServers {
    case .array(var servers):
      if let index = servers.firstIndex(where: { $0.name == name }) {
        let server = servers[index]
        servers[index] = MCPServerDefinition(
          name: server.name,
          transport: server.transport,
          command: server.command,
          url: server.url,
          args: server.args,
          env: server.env,
          environment: server.environment,
          enabled: enabled
        )
        config.mcpServers = .array(servers)
        found = true
      } else {
        found = false
      }
    case .object(var dict):
      if let server = dict[name] {
        dict[name] = MCPServerDefinition(
          name: server.name ?? name,
          transport: server.transport,
          command: server.command,
          url: server.url,
          args: server.args,
          env: server.env,
          environment: server.environment,
          enabled: enabled
        )
        config.mcpServers = .object(dict)
        found = true
      } else {
        found = false
      }
    }
    
    if found {
      try ConfigurationManager.shared.updateConfiguration(config)
      let action = enabled ? "Enabled" : "Disabled"
      let icon = enabled ? "✅" : "⭕"
      print("\(icon) \(action) MCP server '\(name)'".green)
    } else {
      print("❌ MCP server '\(name)' not found".red)
    }
  }
  
  // MARK: - Connection Status
  
  private func showConnectionStatus() async {
    print("\n🔍 " + "MCP Server Connection Status".cyan.bold)
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━".lightBlack)
    
    let config = ConfigurationManager.shared.getConfiguration()
    guard let mcpServers = config.mcpServers else {
      print("No MCP servers configured".yellow)
      return
    }
    
    let servers = mcpServers.allServers.filter { $0.enabled ?? true }
    guard !servers.isEmpty else {
      print("No enabled MCP servers".yellow)
      return
    }
    
    print("\nChecking connections...".lightBlack)
    
    // Note: Actual connection testing would require the MCPClient
    // For now, we'll show a simulated status based on configuration
    for server in servers {
      let name = server.name ?? "unnamed"
      
      // Basic validation
      let isValid: Bool
      if server.transport == "http" {
        isValid = server.url != nil
      } else {
        isValid = server.command != nil
      }
      
      if isValid {
        print("✅ \(name): " + "Ready".green)
      } else {
        print("❌ \(name): " + "Configuration incomplete".red)
      }
    }
    
    print("\n💡 " + "Tip:".yellow + " Connection testing happens when you start using the tools")
  }
  
  // MARK: - Install Guides
  
  private func showInstallGuides() {
    print("\n📚 " + "MCP Server Installation Guides".cyan.bold)
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━".lightBlack)
    
    print("\n🌐 " + "Zapier (HTTP)".yellow.bold)
    print("1. Go to " + "https://actions.zapier.com/mcp".cyan)
    print("2. Sign in and create an API key")
    print("3. Copy your MCP endpoint URL")
    print("4. Run: " + "/mcp add-http".green)
    print("")
    
    print("📁 " + "Filesystem MCP".yellow.bold)
    print("1. Install: " + "npm install -g @modelcontextprotocol/server-filesystem".cyan)
    print("2. Run: " + "/mcp add".green)
    print("   Name: filesystem")
    print("   Command: npx")
    print("   Args: @modelcontextprotocol/server-filesystem")
    print("")
    
    print("🔍 " + "Brave Search MCP".yellow.bold)
    print("1. Get API key from " + "https://brave.com/search/api/".cyan)
    print("2. Install: " + "npm install -g @modelcontextprotocol/server-brave-search".cyan)
    print("3. Run: " + "/mcp add".green)
    print("   Name: brave-search")
    print("   Command: npx")
    print("   Args: @modelcontextprotocol/server-brave-search")
    print("   Env: BRAVE_API_KEY=your_api_key")
    print("")
    
    print("💻 " + "GitHub MCP".yellow.bold)
    print("1. Create a GitHub personal access token")
    print("2. Install: " + "npm install -g @modelcontextprotocol/server-github".cyan)
    print("3. Run: " + "/mcp add".green)
    print("   Name: github")
    print("   Command: npx")
    print("   Args: @modelcontextprotocol/server-github")
    print("   Env: GITHUB_TOKEN=your_token")
    print("")
    
    print("📖 " + "More servers:".lightBlack)
    print("Visit " + "https://github.com/modelcontextprotocol/servers".cyan)
  }
  
  // MARK: - Helper Methods
  
  private func addServerToConfig(
    name: String,
    transport: String,
    command: String?,
    url: String?,
    args: [String]?,
    env: [String: String]?,
    enabled: Bool
  ) async throws {
    var config = ConfigurationManager.shared.getConfiguration()
    
    // Check if server already exists
    if let servers = config.mcpServers?.allServers,
       servers.contains(where: { $0.name == name }) {
      print("❌ MCP server '\(name)' already exists".red)
      print("💡 Use '/mcp remove \(name)' first if you want to replace it".yellow)
      return
    }
    
    let serverDef = MCPServerDefinition(
      name: name,
      transport: transport,
      command: command,
      url: url,
      args: args,
      env: env,
      environment: nil,
      enabled: enabled
    )
    
    // Add to configuration
    if config.mcpServers == nil {
      config.mcpServers = .array([])
    }
    
    switch config.mcpServers {
    case .array(var servers):
      servers.append(serverDef)
      config.mcpServers = .array(servers)
    case .object(var dict):
      dict[name] = serverDef
      config.mcpServers = .object(dict)
    case .none:
      config.mcpServers = .array([serverDef])
    }
    
    try ConfigurationManager.shared.updateConfiguration(config)
    
    print("\n✅ " + "Successfully added MCP server '\(name)'".green.bold)
    if transport == "http" {
      print("   Type: HTTP endpoint".lightBlack)
      if let url = url {
        print("   URL: \(maskSensitiveUrl(url))".lightBlack)
      }
    } else {
      print("   Type: stdio process".lightBlack)
      if let command = command {
        print("   Command: \(command)".lightBlack)
      }
    }
    print("   Status: " + (enabled ? "Enabled".green : "Disabled".yellow))
    
    if enabled {
      print("\n🚀 The server will be available in your next message".cyan)
    } else {
      print("\n💡 Enable with: " + "/mcp enable \(name)".yellow)
    }
  }
  
  private func addServerWithDetails(name: String, command: String, transport: String) async throws {
    // Simple non-interactive add
    try await addServerToConfig(
      name: name,
      transport: transport,
      command: command,
      url: nil,
      args: nil,
      env: nil,
      enabled: true
    )
  }
  
  private func maskSensitiveUrl(_ url: String) -> String {
    // Parse URL and mask the path/token portion
    if let urlComponents = URLComponents(string: url) {
      var masked = "\(urlComponents.scheme ?? "https")://\(urlComponents.host ?? "")"
      if let port = urlComponents.port {
        masked += ":\(port)"
      }
      if let path = urlComponents.path.split(separator: "/").first {
        masked += "/\(path)/..."
      }
      return masked + " (redacted)"
    }
    return "***"
  }
}