# SwiftOpenAI-CLI

[![Version](https://img.shields.io/badge/version-1.3.3-blue.svg)](https://github.com/jamesrochabrun/SwiftOpenAICLI/releases)

<img width="1090" height="680" alt="Image" src="https://github.com/user-attachments/assets/4c4dbbea-c557-43a2-8a5d-fdcad9987510" />

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue.svg)
![Linux](https://img.shields.io/badge/Linux-blue.svg)
[![Buy me a coffee](https://img.shields.io/badge/Buy%20me%20a%20coffee-048754?logo=buymeacoffee)](https://buymeacoffee.com/jamesrochabrun)

A command-line interface for interacting with OpenAI's API, built with Swift.

## Features

- 💬 **Chat** - Interactive conversations with GPT models
- 🤖 **Agent Mode** - AI agent with MCP tool integration and conversation memory
- 🔌 **MCP Integration** - Connect to GitHub, databases, Slack, and more via Model Context Protocol
- 🚀 **GPT-5 Support** - Advanced reasoning and verbosity controls for GPT-5 models
- 🖼️ **Image Generation** - Generate images with AI models
- 📊 **Models** - List and filter available models
- 🔤 **Completions** - Generate text completions
- 🧮 **Embeddings** - Generate text embeddings
- ⚙️ **Configuration** - Manage API keys and settings

## Installation

### Using npm (Recommended)

The easiest way to install SwiftOpenAI-CLI is via npm:

```bash
npm install -g swiftopenai-cli
```

That's it! The `swiftopenai` command is now available globally.

**Platform Support:**
- ✅ macOS (Apple Silicon M1/M2/M3)
- ⚠️ macOS (Intel) - Requires Rosetta 2
- ❌ Linux - Use "Build from Source" below

### Build from Source

Perfect for developers, contributors, or if you need to run on Linux.

1. Clone the repository:
```bash
git clone https://github.com/jamesrochabrun/SwiftOpenAICLI.git
cd SwiftOpenAICLI
```

2. Build the project:
```bash
swift build -c release
```

3. Install the binary:
```bash
cp .build/release/swiftopenai /usr/local/bin/
```

Or run directly without installing:
```bash
swift run swiftopenai "Hello, world!"
```

### Alternative Installation Methods

<details>
<summary><b>Using Mint</b></summary>

[Mint](https://github.com/yonaskolb/Mint) is a package manager for Swift command-line tools.

1. Install Mint:
```bash
brew install mint
```

2. Install SwiftOpenAI-CLI:
```bash
mint install jamesrochabrun/SwiftOpenAICLI
```

**Note:** You'll need to add Mint's bin directory to your PATH:
```bash
export PATH="$HOME/.mint/bin:$PATH"
```
</details>

<details>
<summary><b>Debug Build Information</b></summary>

The CLI includes debug output when built in debug mode:
- Full curl commands for API requests
- HTTP response headers and status codes  
- Raw JSON responses from the API

To build with debug output:
```bash
swift build  # Debug mode
swift build -c release  # Release mode (recommended)
```
</details>

## Updating

### For npm installations

Check if an update is available:
```bash
npm outdated -g swiftopenai-cli
```

Update to the latest version:
```bash
npm update -g swiftopenai-cli
```

Or force update to the latest version:
```bash
npm install -g swiftopenai-cli@latest
```

### For source builds

Pull the latest changes and rebuild:
```bash
cd SwiftOpenAICLI
git pull
swift build -c release
cp .build/release/swiftopenai /usr/local/bin/
```

### Verify your version

After updating, confirm the new version:
```bash
swiftopenai --version
```

**Note:** Check the [releases page](https://github.com/jamesrochabrun/SwiftOpenAICLI/releases) for any breaking changes before updating.

## Configuration

Set your OpenAI API key using one of these methods:

### Environment Variable
```bash
export OPENAI_API_KEY=sk-...
```

### CLI Configuration
```bash
swiftopenai config set api-key sk-...
```

## Usage

### Chat
```bash
# Simple chat
swiftopenai "What is the capital of France?"

# Plain output without formatting (useful for scripts)
swiftopenai -p "What is the capital of France?"

# Interactive mode
swiftopenai chat --interactive

# Interactive mode with plain output
swiftopenai chat --interactive --plain

# With specific model
swiftopenai chat --model gpt-4o "Explain quantum computing"

# With GPT-5 models (supports both formats)
swiftopenai chat --model gpt5 "Write a function" --reasoning minimal
swiftopenai chat --model gpt-5-mini "Explain this concept" --verbose high

# With system prompt
swiftopenai chat --system "You are a helpful assistant" "How do I sort an array?"
```

### Agent Mode 🤖

AI agent with MCP (Model Context Protocol) integration for external tools, conversation memory, and auto-compaction for infinite conversations.

#### Basic Usage

```bash
# Simple agent command (uses GPT-5 by default)
swiftopenai agent "Calculate 25 * 37 and tell me what day it is today"

# With specific model
swiftopenai agent "What's the weather like?" --model gpt-4o-mini

# Interactive agent mode
swiftopenai agent --interactive

# Interactive with tool events visible
swiftopenai agent --interactive --show-tool-events

# Use with MCP servers for tools (--allowed-tools required)
swiftopenai agent "Read the config.json file" --mcp-servers filesystem --allowed-tools "mcp__filesystem__*"
```

#### Advanced Usage

```bash
# Stream JSON events (like Claude SDK)
swiftopenai agent "Calculate the square root of 144" --output-format stream-json

# With session ID for conversation continuity
swiftopenai agent "My name is Alice" --session-id abc123
swiftopenai agent "What's my name?" --session-id abc123  # Remembers Alice

# GPT-5 with verbosity and reasoning controls
swiftopenai agent "Explain quantum computing" --model gpt-5 --model-verbosity high --reasoning high

# MCP tools with JSON output
swiftopenai agent "Query the database for recent orders" \
  --mcp-servers postgres \
  --output-format json

# With custom system prompt
swiftopenai agent "Help me debug this" \
  --system "You are an expert programmer" \
  --model gpt-5-mini
```

#### Output Formats

- `plain` (default) - Human-readable output with colored formatting
- `json` - Structured JSON response with metadata
- `stream-json` - Event stream for each tool call and response (Claude SDK style)

#### Interactive Mode Features

```bash
swiftopenai agent --interactive --model gpt-5 --show-tool-events
```

- **Conversation Memory** - Maintains context within session
- **Auto-Compaction** - Automatically summarizes long conversations at 92% capacity
- **Context Warnings** - Shows capacity usage (e.g., "💭 85% capacity (7% until auto-compacting)")
- **Commands**:
  - `clear` - Reset conversation history
  - `exit` or `quit` - Exit interactive mode
  - `Ctrl+C` - Interrupt and exit
  - `Ctrl+D` - EOF exit

#### Session Management

```bash
# Start new conversation
swiftopenai agent "Hello, I'm working on a Swift project" --session-id work-session

# Continue conversation (remembers context)
swiftopenai agent "What language did I mention?" --session-id work-session

# Auto-compaction keeps conversations infinite
# When reaching context limit, automatically summarizes with GPT-5-mini/gpt-4o-mini
```

#### Context Windows

- **GPT-5 models**: 400K tokens
- **GPT-4o models**: 128K tokens
- Auto-compaction triggers at 92% capacity
- Fallback chain: GPT-5-mini → gpt-4o-mini → gpt-3.5-turbo

#### Real-World Examples

```bash
# Complex task with MCP tools (--allowed-tools required)
swiftopenai agent "List all my GitHub repositories and create an issue about updating documentation" \
  --mcp-servers github --allowed-tools "mcp__github__*"

# Code analysis with filesystem MCP
swiftopenai agent "Read the Package.swift file and explain what dependencies this project uses" \
  --mcp-servers filesystem --allowed-tools "mcp__filesystem__*"

# Interactive problem-solving session
swiftopenai agent --interactive --model gpt-5 --show-tool-events
# You: I need to plan a project that starts today
# You: Calculate how many work days are in the next 30 days
# You: What's the date 30 days from now?

# Production monitoring with MCP and JSON output
swiftopenai agent "Query the database for system metrics and calculate uptime percentage" \
  --output-format json \
  --mcp-servers postgres
```

### MCP (Model Context Protocol) Integration 🔌

SwiftOpenAI-CLI supports the Model Context Protocol (MCP), allowing you to connect to external services and tools through MCP servers. This feature is fully compatible with the Claude Code SDK specification, enabling seamless integration with a growing ecosystem of MCP-compatible tools.

#### What is MCP?

MCP is an open protocol developed by Anthropic that enables AI assistants to securely connect to external data sources and tools. Instead of building custom integrations for each service, MCP provides a standardized way to:

- **Access external APIs** - GitHub, Slack, Google Drive, databases, and more
- **Perform system operations** - File system access, shell commands, git operations
- **Query data sources** - PostgreSQL, SQLite, REST APIs, GraphQL endpoints
- **Extend capabilities** - Add any custom tool without modifying the CLI

#### Quick Start

```bash
# 1. Add the GitHub MCP server to your configuration
swiftopenai config mcp add github npx --args "@modelcontextprotocol/server-github" --env "GITHUB_PERSONAL_ACCESS_TOKEN=your-token" --enable

# 2. Use it with the agent command (--allowed-tools is REQUIRED for MCP tools)
swiftopenai agent "List my recent pull requests" --mcp-servers github --allowed-tools "mcp__github__*"

# 3. Interactive mode for continuous conversations
swiftopenai agent --interactive --mcp-servers github --allowed-tools "mcp__*"
# 🚀 MCP servers initialized once for this session (optimized!)
# You: Create an issue about the bug we discussed
# You: Show me all open issues
# You: Close issue #123
```

**⚠️ Important:** Following the Claude Code SDK security model, MCP tools must be explicitly allowed using the `--allowed-tools` flag. Without this flag, MCP servers will connect but their tools won't be available to the agent.

#### Available MCP Servers

Popular MCP servers you can use immediately:

- **GitHub** (`@modelcontextprotocol/server-github`) - Manage repos, issues, PRs, releases
- **Filesystem** (`@modelcontextprotocol/server-filesystem`) - Read/write local files with permissions
- **PostgreSQL** (`@modelcontextprotocol/server-postgres`) - Query and manage PostgreSQL databases
- **Slack** (`@modelcontextprotocol/server-slack`) - Send messages, read channels, manage workspace
- **Google Drive** (`@modelcontextprotocol/server-gdrive`) - Access and manage Drive files
- **Git** (`@modelcontextprotocol/server-git`) - Version control operations
- **Puppeteer** (`@modelcontextprotocol/server-puppeteer`) - Web scraping and browser automation
- **Airbnb** (`@openbnb/mcp-server-airbnb`) - Search listings, get details, read reviews

Find more at [MCP Servers Repository](https://github.com/modelcontextprotocol/servers)

#### Configuration

##### Method 1: CLI Commands (Recommended)

```bash
# Add a new MCP server
swiftopenai config mcp add <name> <command> --args <arguments> --env <KEY=VALUE> --enable

# Examples
swiftopenai config mcp add github npx \
  --args "@modelcontextprotocol/server-github" \
  --env "GITHUB_PERSONAL_ACCESS_TOKEN=ghp_..." \
  --enable

swiftopenai config mcp add postgres npx \
  --args "@modelcontextprotocol/server-postgres" \
  --env "DATABASE_URL=postgresql://user:pass@localhost/db" \
  --enable

# Manage servers
swiftopenai config mcp list                    # List all configured servers
swiftopenai config mcp enable github           # Enable a server
swiftopenai config mcp disable github          # Disable a server  
swiftopenai config mcp remove github           # Remove a server
```

##### Method 2: Direct Configuration File

Edit `~/.swiftopenai/config.json`:

**Object Format (Claude Code SDK compatible):**
```json
{
  "apiKey": "sk-...",
  "defaultModel": "gpt-4o",
  "mcpServers": {
    "github": {
      "command": "npx",
      "args": ["@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "ghp_..."
      },
      "enabled": true
    },
    "postgres": {
      "command": "npx",
      "args": ["@modelcontextprotocol/server-postgres"],
      "env": {
        "DATABASE_URL": "postgresql://localhost/mydb"
      },
      "enabled": true
    }
  }
}
```

**Array Format (Legacy, still supported):**
```json
{
  "mcpServers": [
    {
      "name": "github",
      "command": "npx",
      "args": ["@modelcontextprotocol/server-github"],
      "environment": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "ghp_..."
      },
      "enabled": true
    }
  ]
}
```

#### Usage Examples

##### GitHub Workflow
```bash
# Repository management (--allowed-tools is required for MCP tools)
swiftopenai agent "Create a new repo called my-project with a README" --mcp-servers github --allowed-tools "mcp__github__*"
swiftopenai agent "List all issues in repo jamesrochabrun/SwiftOpenAI" --mcp-servers github --allowed-tools "mcp__github__*"
swiftopenai agent "Create a pull request from feature branch to main" --mcp-servers github --allowed-tools "mcp__github__*"

# Interactive development session
swiftopenai agent --interactive --mcp-servers github --allowed-tools "mcp__github__*"
# You: Show me all my starred repositories
# You: Create an issue in the first one about updating dependencies
# You: Add a comment to issue #42 with the solution we discussed
```

##### Database Operations
```bash
# Add PostgreSQL server
swiftopenai config mcp add postgres npx \
  --args "@modelcontextprotocol/server-postgres" \
  --env "DATABASE_URL=postgresql://user:pass@localhost/myapp" \
  --enable

# Query database (--allowed-tools required)
swiftopenai agent "Show me all users created in the last week" --mcp-servers postgres --allowed-tools "mcp__postgres__*"
swiftopenai agent "What's the total revenue this month?" --mcp-servers postgres --allowed-tools "mcp__postgres__*"

# Interactive data analysis
swiftopenai agent --interactive --mcp-servers postgres --allowed-tools "mcp__postgres__*"
# You: List all tables in the database
# You: Show me the schema for the orders table
# You: Calculate the average order value for each month
```

##### File System Operations
```bash
# Add filesystem server with specific permissions
swiftopenai config mcp add fs npx \
  --args "@modelcontextprotocol/server-filesystem,/Users/me/projects" \
  --enable

# File operations (--allowed-tools required)
swiftopenai agent "List all Python files in the current directory" --mcp-servers fs --allowed-tools "mcp__fs__*"
swiftopenai agent "Read the package.json and summarize dependencies" --mcp-servers fs --allowed-tools "mcp__fs__*"
swiftopenai agent "Create a new file called notes.md with our discussion" --mcp-servers fs --allowed-tools "mcp__fs__*"
```

##### Multi-Server Usage
```bash
# Use multiple MCP servers together (--allowed-tools required)
swiftopenai agent "Read the README.md file and create a GitHub issue about missing docs" \
  --mcp-servers fs,github \
  --allowed-tools "mcp__fs__*,mcp__github__*"

# Interactive with multiple servers
swiftopenai agent --interactive --mcp-servers github,postgres,fs --allowed-tools "mcp__*"
# You: Read the database schema from schema.sql
# You: Check if there are any GitHub issues about database migrations
# You: Create a migration script based on the schema changes
```

#### Advanced Features

##### Tool Naming Convention
MCP tools follow the naming pattern: `mcp__serverName__toolName`

```bash
# Tools are automatically namespaced
mcp__github__create_issue
mcp__github__list_repos
mcp__postgres__query
mcp__fs__read_file
```

##### Pattern Matching with --allowed-tools
Control which tools the agent can use with glob patterns:

```bash
# Allow only GitHub tools
swiftopenai agent "Help me manage my repos" --allowed-tools "mcp__github__*"

# Allow specific tools from multiple servers
swiftopenai agent "Analyze data" --allowed-tools "mcp__postgres__query,mcp__fs__read*"

# Allow all MCP tools but no built-in tools
swiftopenai agent "Do something" --allowed-tools "mcp__*"

# Mix different MCP server tools
swiftopenai agent "Query and store data" --allowed-tools "mcp__postgres__*,mcp__fs__*"
```

##### Auto-Installation
NPX packages are automatically installed with the `-y` flag - no manual installation needed:

```bash
# Just add and use - auto-installs on first run
swiftopenai config mcp add newserver npx --args "@org/mcp-server" --enable
swiftopenai agent "Use the new server" --mcp-servers newserver
# Automatically runs: npx -y @org/mcp-server
```

##### Performance Optimization
In interactive mode, MCP servers are initialized once and reused for the entire session:

```bash
swiftopenai agent --interactive --mcp-servers github,postgres
# 🚀 MCP servers initialized once for this session
# Fast responses - no reconnection between messages!
```

Non-interactive mode creates fresh connections for each command (stateless execution).

#### Real-World Scenarios

##### Development Workflow
```bash
# Morning standup prep
swiftopenai agent --interactive --mcp-servers github,postgres --allowed-tools "mcp__*"
# You: Show me all PRs assigned to me
# You: Check if the database has the migrations from PR #123
# You: List all issues labeled 'bug' created yesterday
# You: Generate a summary for the standup
```

##### Content Management
```bash
# Blog post workflow
swiftopenai agent --interactive --mcp-servers fs,github --allowed-tools "mcp__*"
# You: Read all markdown files in the blog directory
# You: Create a new post about MCP integration
# You: Generate a table of contents
# You: Create a PR with the new post
```

##### Data Analysis
```bash
# Sales analysis
swiftopenai agent --interactive --mcp-servers postgres --allowed-tools "mcp__postgres__*"
# You: Show me total sales by region this quarter
# You: Calculate the month-over-month growth rate
# You: Which products have the highest margin?
# You: Export the top 10 products to a report
```

#### Troubleshooting

**NPX not found:**
```bash
# Find npx location
which npx
# Usually: /usr/local/bin/npx or ~/.nvm/versions/node/vX.X.X/bin/npx

# The CLI automatically resolves npx through PATH
# If issues persist, use the full path in configuration
```

**Authentication errors:**
```bash
# Check environment variables are set correctly
swiftopenai config mcp list
# Verify the env vars show correctly

# Test with a simple command
swiftopenai agent "Test connection" --mcp-servers github --show-mcp-status
```

**Tool not found:**
```bash
# List all available tools
swiftopenai agent "What tools are available?" --mcp-servers github --show-mcp-status

# Tools are named: mcp__serverName__toolName
# Use --allowed-tools with correct pattern
swiftopenai agent "Do something" --allowed-tools "mcp__github__*"
```

**Server not connecting:**
```bash
# Enable verbose output
swiftopenai agent "Test" --mcp-servers myserver --show-mcp-status

# Check server is enabled
swiftopenai config mcp list

# Try re-adding with correct arguments
swiftopenai config mcp remove myserver
swiftopenai config mcp add myserver npx --args "@correct/package" --enable
```

### Image Generation
```bash
# Generate an image
swiftopenai image "A sunset over mountains in watercolor style"

# With options
swiftopenai image "A futuristic city" --model dall-e-3 --size 1024x1024 --quality hd

# Save to directory
swiftopenai image "A cat" --output ./images
```

### List Models
```bash
# List all models
swiftopenai models

# Filter models
swiftopenai models --filter gpt

# Detailed view
swiftopenai models --detailed
```

### Embeddings
```bash
# Generate embeddings
swiftopenai embed "Hello world"

# Save to file
swiftopenai embed "Your text here" --output embeddings.json

# Show statistics
swiftopenai embed "Text to embed" --stats
```

### Configuration
```bash
# Set API key
swiftopenai config set api-key sk-...

# Get configuration value
swiftopenai config get default-model

# List all settings
swiftopenai config list
```

### GPT-5 Models

SwiftOpenAI-CLI now supports GPT-5 models with advanced reasoning and verbosity controls. The CLI automatically normalizes model names for convenience:

#### Supported Model Names
- `gpt5` or `gpt-5` - Complex reasoning, broad world knowledge, and code-heavy or multi-step agentic tasks
- `gpt5mini` or `gpt-5-mini` - Cost-optimized reasoning and chat; balances speed, cost, and capability
- `gpt5nano` or `gpt-5-nano` - High-throughput tasks, especially simple instruction-following or classification

```bash
# Fast coding assistance with minimal reasoning
swiftopenai "Write a Python function to sort a list" --model gpt5 --reasoning minimal --verbose low

# Detailed explanations with thorough reasoning
swiftopenai "Explain quantum entanglement" --model gpt-5 --reasoning high --verbose high

# Cost-optimized with balanced settings
swiftopenai "Help me debug this code" --model gpt5mini --reasoning medium --verbose medium

# High-throughput simple tasks
swiftopenai "Classify this text as positive or negative" --model gpt5nano --reasoning minimal --verbose low

# Interactive mode with GPT-5 Mini
swiftopenai chat --interactive --model gpt-5-mini --reasoning minimal
```

#### Verbosity Levels
- `low` - Concise responses with minimal detail
- `medium` - Balanced responses (default)
- `high` - Detailed, comprehensive responses

#### Reasoning Effort
- `minimal` - Very few reasoning tokens for fastest response (great for coding and instructions)
- `low` - Light reasoning for simple tasks
- `medium` - Balanced reasoning (default)
- `high` - Thorough reasoning for complex problems

**Notes:**
- The `--verbose` and `--reasoning` parameters only apply to GPT-5 family models
- Model names are case-insensitive and hyphens are optional (e.g., `gpt5`, `GPT5`, `gpt-5` all work)
- The CLI automatically normalizes model names to the correct API format

### Using Alternative Providers

SwiftOpenAI-CLI supports any OpenAI-compatible API providers. Built with [SwiftOpenAI v4.3.2](https://github.com/jamesrochabrun/SwiftOpenAI), it can connect to providers like Grok, Groq, OpenRouter, DeepSeek, and more. Configure the CLI to use these providers:

**Note:** When using alternative providers, use the `--model` flag with the provider's specific model names. For example:
- OpenRouter: `anthropic/claude-3.5-sonnet`, `openai/gpt-4`, `google/gemini-pro`
- DeepSeek: `deepseek-reasoner`, `deepseek-chat`
- Groq: `llama2-70b-4096`, `mixtral-8x7b-32768`

#### Grok (xAI)
```bash
# Configure for Grok
swiftopenai config set provider grok
swiftopenai config set base-url https://api.x.ai
swiftopenai config set api-key your-grok-api-key

# Use Grok models
swiftopenai "What's the latest in AI?" --model grok-beta
```

#### Groq
```bash
# Configure for Groq
swiftopenai config set provider groq
swiftopenai config set base-url https://api.groq.com
swiftopenai config set api-key your-groq-api-key

# Use Groq models
swiftopenai "Explain quantum computing" --model llama2-70b-4096
```

#### Local Models (Ollama)
```bash
# Configure for Ollama
swiftopenai config set provider ollama
swiftopenai config set base-url http://localhost:11434
swiftopenai config set api-key optional-or-empty

# Use local models
swiftopenai "Hello!" --model llama2
```

#### OpenRouter (Access 300+ Models)
```bash
# Configure for OpenRouter
swiftopenai config set provider openrouter
swiftopenai config set base-url https://openrouter.ai/api
swiftopenai config set api-key your-openrouter-api-key

# Use any of the 300+ available models
swiftopenai "Explain quantum computing" --model anthropic/claude-3.5-sonnet
swiftopenai "Write a haiku" --model openai/gpt-4-turbo
swiftopenai "Solve this math problem" --model google/gemini-pro
```

#### DeepSeek (Advanced Reasoning Models)
```bash
# Configure for DeepSeek
swiftopenai config set provider deepseek
swiftopenai config set base-url https://api.deepseek.com
swiftopenai config set api-key your-deepseek-api-key

# Use DeepSeek models
swiftopenai "What is the Manhattan project?" --model deepseek-reasoner
swiftopenai "Explain step by step how to solve x^2 + 5x + 6 = 0" --model deepseek-chat
```

#### Reset to OpenAI
```bash
# Clear provider configuration to use OpenAI
swiftopenai config set provider ""
swiftopenai config set base-url ""
```

#### Quick Provider Switching

You can create shell aliases for quick provider switching:

```bash
# Add to your ~/.zshrc or ~/.bashrc
alias ai-openai='swiftopenai config set provider "" && swiftopenai config set base-url ""'
alias ai-grok='swiftopenai config set provider grok && swiftopenai config set base-url https://api.x.ai'
alias ai-deepseek='swiftopenai config set provider deepseek && swiftopenai config set base-url https://api.deepseek.com'
alias ai-openrouter='swiftopenai config set provider openrouter && swiftopenai config set base-url https://openrouter.ai/api'

# Then switch providers easily
ai-deepseek
swiftopenai "What is quantum entanglement?" --model deepseek-reasoner

ai-openrouter
swiftopenai "Write a poem" --model anthropic/claude-3-haiku
```

### Debug Mode

Enable debug mode to see detailed API requests and responses:

```bash
# Enable debug mode
swiftopenai config set debug true

# Disable debug mode
swiftopenai config set debug false
```

When debug mode is enabled and the CLI is built in debug configuration, you'll see:
- Full curl commands for API requests
- HTTP response headers and status codes
- Raw JSON responses from the API

**Note:** Debug output requires building the CLI in debug mode (`swift build`) rather than release mode.

## Command Options

### Global Options
- `--help` - Show help information
- `--version` - Show version

### Chat Options
- `-m, --model` - Model to use (default: gpt-4o)
- `-i, --interactive` - Interactive chat mode
- `-p, --plain` - Plain output without formatting (useful for scripts)
- `--system` - System prompt
- `--temperature` - Temperature (0.0-2.0)
- `--max-tokens` - Maximum tokens to generate
- `--no-stream` - Disable streaming response
- `--verbose` - Verbosity level for GPT-5 models (`low`, `medium`, `high`) - default: `medium`
- `--reasoning` - Reasoning effort for GPT-5 models (`minimal`, `low`, `medium`, `high`) - default: `medium`

### Image Options
- `-n, --number` - Number of images (1-10, dall-e-3 only supports 1)
- `--size` - Image size:
  - dall-e-2: `256x256`, `512x512`, `1024x1024`
  - dall-e-3: `1024x1024`, `1792x1024`, `1024x1792`
- `--model` - Model (`dall-e-2`, `dall-e-3`)
- `--quality` - Quality (`standard`, `hd` - dall-e-3 only)
- `--output` - Output directory for saving images

## Examples

### GPT-5 Examples
```bash
# Using different GPT-5 models (with or without hyphens)
$ swiftopenai "Generate a sorting algorithm" --model gpt5 --reasoning high
$ swiftopenai "Summarize this text" --model gpt5mini --verbose low
$ swiftopenai "Yes or No?" --model gpt5nano --reasoning minimal

# The CLI normalizes these model names automatically:
# gpt5 → gpt-5
# gpt5mini → gpt-5-mini  
# gpt5nano → gpt-5-nano
```

### Interactive Chat Session
```bash
$ swiftopenai chat -i
🤖 OpenAI Chat (gpt-4o)
Type 'exit' to quit, 'clear' to clear history

You: Hello! Can you help me with Swift?
Assistant: Of course! I'd be happy to help you with Swift...

You: exit
Goodbye!
```

### Generate Multiple Images
```bash
$ swiftopenai image "A serene landscape" -n 3 --output ./landscapes
Generating image with prompt: "A serene landscape"
Model: dall-e-3, Size: 1024x1024, Quality: standard

Generated 3 image(s):
1. URL: https://...
   Saved to: ./landscapes/dalle_1_1234567890.png
2. URL: https://...
   Saved to: ./landscapes/dalle_2_1234567890.png
3. URL: https://...
   Saved to: ./landscapes/dalle_3_1234567890.png
```

### Using Plain Output in Scripts
```bash
# Get a plain response for use in scripts
$ answer=$(swiftopenai -p "What is 2+2?")
$ echo "The answer is: $answer"
The answer is: 4

# Compare with formatted output
$ swiftopenai "What is 2+2?"
Assistant: 4
```

## Using it with Claude Code

https://github.com/user-attachments/assets/3fa87fe1-e672-4ade-9255-ce53b1301081

## Requirements

- macOS 13.0+
- Swift 5.9+

## License

MIT License

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Acknowledgments

Built with:
- [SwiftOpenAI](https://github.com/jamesrochabrun/SwiftOpenAI) - Swift client for OpenAI API
- [Swift Argument Parser](https://github.com/apple/swift-argument-parser) - Command-line argument parsing
- [Rainbow](https://github.com/onevcat/Rainbow) - Terminal colors
- [SwiftyTextTable](https://github.com/scottrhoyt/SwiftyTextTable) - Text tables
