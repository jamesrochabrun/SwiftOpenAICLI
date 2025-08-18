# SwiftOpenAI-CLI

A powerful command-line interface for OpenAI API and compatible providers, built with Swift.

## Installation

```bash
npm install -g swiftopenai-cli
```

## Quick Start

1. Set your API key:
```bash
swiftopenai config set api-key YOUR_API_KEY
```

2. Start chatting:
```bash
swiftopenai "What is the capital of France?"
```

## Features

- 💬 **Chat** - Interactive conversations with GPT models
- 🤖 **Agent Mode** - Tool-calling AI agent with memory and auto-compaction
- 🚀 **GPT-5 Support** - Advanced reasoning and verbosity controls
- 🖼️ **Image Generation** - Create images with DALL-E
- 📊 **Models** - List available models
- 🧮 **Embeddings** - Generate text embeddings
- ⚙️ **Multi-Provider Support** - OpenAI, Grok, Groq, DeepSeek, OpenRouter, and more

## Usage Examples

### Chat
```bash
# Simple chat
swiftopenai "Explain quantum computing"

# Interactive mode
swiftopenai chat --interactive

# With specific model
swiftopenai chat --model gpt-4o "Write a haiku"

# Plain output for scripts
swiftopenai -p "What is 2+2?"
```

### Agent Mode 🤖

AI agent with tool-calling capabilities, conversation memory, and auto-compaction for infinite conversations.

```bash
# Simple agent command (uses GPT-5 by default)
swiftopenai agent "Calculate 25 * 37 and tell me what day it is today"

# Interactive agent mode
swiftopenai agent --interactive

# With tool events visible
swiftopenai agent --interactive --show-tool-events

# Stream JSON events
swiftopenai agent "What's the square root of 144?" --output-format stream-json

# With session ID for conversation memory
swiftopenai agent "My name is Alice" --session-id abc123
swiftopenai agent "What's my name?" --session-id abc123  # Remembers Alice
```

**Built-in Tools:**
- **Calculator** - Mathematical expressions (sqrt, sin, cos, etc.)
- **DateTime** - Current date/time and date calculations
- **FileReader** - Read local files

**Features:**
- Conversation memory with session management
- Auto-compaction at 92% capacity for infinite conversations
- Multiple output formats (plain, json, stream-json)
- 400K token context window for GPT-5 models

### Image Generation
```bash
swiftopenai image "A sunset over mountains"
```

### Configuration
```bash
# Set API key
swiftopenai config set api-key sk-...

# Use alternative provider
swiftopenai config set provider openrouter
swiftopenai config set base-url https://openrouter.ai/api
```

## Documentation

For full documentation, visit: https://github.com/jamesrochabrun/SwiftOpenAICLI

## License

MIT