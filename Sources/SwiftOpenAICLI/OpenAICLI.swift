import ArgumentParser
import Foundation

@main
struct OpenAICLI: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "swiftopenai",
    abstract: "A powerful command-line interface for OpenAI API with MCP (Model Context Protocol) support",
    discussion: """
    OVERVIEW:
    SwiftOpenAI CLI provides comprehensive access to OpenAI's APIs including chat, image generation,
    embeddings, and agent mode with tool support. Now featuring MCP integration for connecting to
    external data sources and services.

    QUICK START:
    1. Set your API key:
       swiftopenai config set api-key sk-...
    
    2. Start chatting:
       swiftopenai chat "Hello, how are you?"
    
    3. Use agent mode with tools:
       swiftopenai agent "What's 25 * 4?" --tools calculator

    MAIN COMMANDS:
    • chat      - Chat with OpenAI models (GPT-4, GPT-5, etc.)
    • agent     - Advanced mode with tool support and MCP integration
    • report    - Generate research reports with PDF export
    • image     - Generate images with DALL-E
    • models    - List available models
    • complete  - Text completion (legacy)
    • embed     - Generate text embeddings
    • config    - Manage configuration and MCP servers

    AGENT MODE WITH TOOLS:
    The agent command supports built-in tools and external MCP servers:
    
    Built-in tools:
    • calculator   - Perform mathematical calculations
    • datetime     - Get current date/time information
    • file_reader  - Read local files
    
    Example: swiftopenai agent "Calculate the square root of 144" --tools calculator

    MCP (MODEL CONTEXT PROTOCOL) INTEGRATION:
    Connect to external services through MCP servers (Claude Code SDK compatible):
    
    1. Add an MCP server:
       swiftopenai config mcp add github "npx" \\
         --args "@modelcontextprotocol/server-github" \\
         --env "GITHUB_PERSONAL_ACCESS_TOKEN=your-token" \\
         --enable
    
    2. Use with agent:
       swiftopenai agent "List my repositories" --mcp-servers github
    
    3. Control tool access with patterns:
       swiftopenai agent "Help me" --allowed-tools "mcp__github__*,calculator"
       swiftopenai agent "Query data" --allowed-tools "mcp__*"
    
    Available MCP servers:
    • GitHub      - Manage repos, issues, PRs
    • Filesystem  - Access local files
    • PostgreSQL  - Query databases
    • Slack       - Send messages, read channels
    • Google Drive - Access Drive files
    • Git         - Version control operations

    INTERACTIVE MODE:
    Both chat and agent commands support interactive mode for continuous conversations:
    
    swiftopenai chat --interactive
    swiftopenai agent --interactive --mcp-servers github

    CONFIGURATION:
    Configuration is stored in ~/.swiftopenai/config.json
    
    Set configuration values:
    • swiftopenai config set api-key sk-...
    • swiftopenai config set default-model gpt-4o
    • swiftopenai config set temperature 0.7
    
    MCP servers support both array and object formats (Claude Code SDK compatible):
    Array format: [{\"name\": \"github\", \"command\": \"npx\", ...}]
    Object format: {\"github\": {\"command\": \"npx\", ...}}
    
    Manage MCP servers:
    • swiftopenai config mcp list              - List all MCP servers
    • swiftopenai config mcp add <name> <cmd>  - Add new server
    • swiftopenai config mcp remove <name>     - Remove server
    • swiftopenai config mcp enable <name>     - Enable server
    • swiftopenai config mcp disable <name>    - Disable server

    OUTPUT FORMATS:
    • plain       - Human-readable text (default)
    • json        - JSON formatted response
    • stream-json - Streaming JSON output

    SESSION MANAGEMENT:
    Resume conversations using session IDs:
    swiftopenai chat "Continue our discussion" --session-id abc123
    
    Sessions automatically compact when approaching token limits.

    ENVIRONMENT VARIABLES:
    • OPENAI_API_KEY - API key (overrides config file)

    EXAMPLES:
    # Basic chat
    swiftopenai chat "Explain quantum computing"
    
    # Chat with system prompt
    swiftopenai chat "Write a poem" --system "You are a poet"
    
    # Agent with math calculations
    swiftopenai agent "What's the compound interest on $1000 at 5% for 10 years?" --tools calculator
    
    # Agent with GitHub integration
    swiftopenai agent "Create an issue about the bug we discussed" --mcp-servers github
    
    # Agent with specific tool patterns
    swiftopenai agent "Analyze this" --allowed-tools "mcp__github__*,calculator"
    
    # Generate an image
    swiftopenai image "A futuristic city at sunset" --model dall-e-3 --quality hd
    
    # List available models
    swiftopenai models
    
    # Interactive agent with all tools
    swiftopenai agent -i --tools calculator,datetime,file_reader --mcp-servers github

    TROUBLESHOOTING:
    • If npx is not found: Use 'which npx' to find the full path
    • NPX packages are auto-installed with -y flag (no manual install needed)
    • MCP tools use double underscore naming: mcp__serverName__toolName
    • For MCP issues: Use --show-mcp-status flag for debugging
    • For API errors: Check your API key with 'config get api-key'
    
    Debug output is controlled at compile time:
    • For debug output: Build with 'swift build' (debug mode)
    • For production: Build with 'swift build -c release'

    VERSION: 1.4.1
    
    For more information and updates, visit:
    https://github.com/jamesrochabrun/SwiftOpenAICLI
    """,
    version: "1.4.1",
    subcommands: [
      ChatCommand.self,
      AgentCommand.self,
      ReportCommand.self,
      ImageCommand.self,
      ModelsCommand.self,
      CompleteCommand.self,
      EmbedCommand.self,
      ConfigCommand.self
    ],
    defaultSubcommand: ChatCommand.self
  )
  
}
