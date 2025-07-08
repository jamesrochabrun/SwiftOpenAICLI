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