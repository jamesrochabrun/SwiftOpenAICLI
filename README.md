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
swift build -c release
```

3. Copy the binary to your PATH:
```bash
cp .build/release/swiftopenai /usr/local/bin/
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

# Interactive mode
swiftopenai chat --interactive

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

## Command Options

### Global Options
- `--help` - Show help information
- `--version` - Show version

### Chat Options
- `-m, --model` - Model to use (default: gpt-4o)
- `-i, --interactive` - Interactive chat mode
- `--system` - System prompt
- `--temperature` - Temperature (0.0-2.0)
- `--max-tokens` - Maximum tokens to generate
- `--no-stream` - Disable streaming response

### Image Options
- `-n, --number` - Number of images (1-10)
- `--size` - Image size
- `--model` - Model (dall-e-2, dall-e-3)
- `--quality` - Quality (standard, hd)
- `--output` - Output directory

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