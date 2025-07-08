# SwiftOpenAI-CLI

A command-line interface for interacting with OpenAI's API, built with Swift.

## Features

- 💬 **Chat** - Interactive conversations with GPT models
- 🖼️ **Image Generation** - Create images using DALL-E
- 📊 **Models** - List and filter available models
- 🔤 **Completions** - Generate text completions
- 🧮 **Embeddings** - Generate text embeddings
- ⚙️ **Configuration** - Manage API keys and settings

## Installation

### Using Homebrew (Coming Soon)
```bash
brew install swiftopenai
```

### Build from Source

1. Clone the repository:
```bash
git clone https://github.com/jamesrochabrun/SwiftOpenAI-CLI.git
cd SwiftOpenAI-CLI
```

2. Build the project:
```bash
# For production use (no debug output)
swift build -c release

# For development with debug output (shows API requests/responses)
swift build
```

3. Copy the binary to your PATH:
```bash
# For release build
cp .build/release/swiftopenai /usr/local/bin/

# For debug build
cp .build/debug/swiftopenai /usr/local/bin/
```

#### Debug Mode

The CLI includes debug output that shows:
- Full curl commands for API requests
- HTTP response headers and status codes
- Raw JSON responses from the API

To control debug output:

**When using `swift run`:**
```bash
# Debug mode (default - shows verbose output)
swift run swiftopenai "your prompt"

# Release mode (clean output only)
swift run --configuration release swiftopenai "your prompt"
# or shorter:
swift run -c release swiftopenai "your prompt"
```

**When building and installing:**
```bash
swift build  # Debug mode (with verbose output)
swift build -c release  # Release mode (clean output only)
```

**Tip:** For daily use, build and install in release mode to avoid debug output:
```bash
swift build -c release && cp .build/release/swiftopenai /usr/local/bin/
```

**Note:** When using `swift run`, you'll see build output like "Building for production..." before your actual results. This is normal Swift behavior. To avoid this, install the binary as shown above.

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

### Using Alternative Providers

SwiftOpenAI-CLI supports any OpenAI-compatible API providers. Built with SwiftOpenAI v4.3.1, it can connect to providers like Grok, Groq, OpenRouter, DeepSeek, and more. Configure the CLI to use these providers:

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

### Image Options
- `-n, --number` - Number of images (1-10, dall-e-3 only supports 1)
- `--size` - Image size:
  - dall-e-2: `256x256`, `512x512`, `1024x1024`
  - dall-e-3: `1024x1024`, `1792x1024`, `1024x1792`
- `--model` - Model (`dall-e-2`, `dall-e-3`)
- `--quality` - Quality (`standard`, `hd` - dall-e-3 only)
- `--output` - Output directory for saving images

## Examples

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
- OpenAI API key

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