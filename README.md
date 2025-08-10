# SwiftOpenAI-CLI

[![Version](https://img.shields.io/badge/version-1.2.0-blue.svg)](https://github.com/jamesrochabrun/SwiftOpenAICLI/releases)

<img width="1090" alt="repoOpenAI" src="https://github.com/user-attachments/assets/693325f3-b633-49c8-98ac-7c8b25b29a6c">

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue.svg)
![Linux](https://img.shields.io/badge/Linux-blue.svg)
[![Buy me a coffee](https://img.shields.io/badge/Buy%20me%20a%20coffee-048754?logo=buymeacoffee)](https://buymeacoffee.com/jamesrochabrun)

A command-line interface for interacting with OpenAI's API, built with Swift.

## Features

- 💬 **Chat** - Interactive conversations with GPT models
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

```bash
npm update -g swiftopenai-cli
```

To check your current version:
```bash
swiftopenai --version
```

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
