# ISA - Intelligent Swift Agent

A Claude Code-inspired AI agent for the command line, built with Swift.

<img width="600" alt="ISA CLI" src="https://github.com/jamesrochabrun/ISA/assets/isa-demo.png" />

## Features

- 🤖 **Intelligent Agent** - Claude Code-inspired control loop with interleaved thinking
- 🛠️ **Powerful Tools** - File operations, search (grep/glob), shell execution, and more
- 📋 **Task Management** - Built-in todo list for tracking complex tasks  
- 🎨 **Beautiful UI** - ASCII art branding and colored terminal output
- ⚙️ **Custom Tools** - Define your own tools with YAML/JSON configuration
- 📝 **Context Support** - Use `isa.md` files for project-specific context
- 🔄 **Interactive Mode** - Continuous conversations with session persistence

## Installation

### Using npm (Recommended)

```bash
npm install -g isa-cli
```

### Build from Source

```bash
git clone https://github.com/jamesrochabrun/ISA.git
cd ISA/isa-cli
./build.sh
cd npm && npm link
```

## Quick Start

1. Set your OpenAI API key:
```bash
export OPENAI_API_KEY=sk-...
```

2. Start using ISA:
```bash
# Interactive mode
isa

# Single command
isa "Help me refactor this code"

# With plan mode
isa "Build a REST API" --plan-mode

# With custom model
isa "Explain this" --model gpt-4
```

## Core Commands

- `isa` - Start interactive mode
- `isa <message>` - Execute a single task
- `isa --help` - Show help and options

## Built-in Tools

ISA comes with powerful built-in tools inspired by Claude Code:

- **File Operations**: `read`, `write`, `edit`
- **Search**: `grep` (ripgrep), `glob`, `ls`
- **Shell**: `bash` (with safety guards)
- **Task Management**: `todo_write`

## Custom Tools

Create custom tools by adding YAML files to `~/.isa/tools/`:

```yaml
# ~/.isa/tools/docker.yaml
name: docker_manager
description: Manage Docker containers
commands:
  - name: list_containers
    description: List all containers
    command: docker ps -a
    
  - name: build_image
    description: Build Docker image
    parameters:
      - name: path
        type: string
        required: true
    command: docker build {path}
```

## Project Context

Create an `isa.md` file in your project root to provide context:

```markdown
# Project Context

This is a React application using TypeScript.

## Conventions
- Use functional components with hooks
- Follow ESLint rules
- Write tests for all components

## Important Files
- src/App.tsx - Main application component
- src/api/ - API client code
```

## Configuration

ISA stores configuration in `~/.isa/config.json`:

```json
{
  "apiKey": "sk-...",
  "defaultModel": "gpt-5",
  "temperature": 0.7
}
```

## Architecture

ISA follows Claude Code's design principles:

1. **Simple Control Loop** - One main loop, maximum one branch
2. **LLM-Native Search** - Uses ripgrep instead of RAG
3. **Explicit Task Management** - Agent maintains its own todo list
4. **Tool Hierarchy** - Mix of low, medium, and high-level tools
5. **Smart Defaults** - Works out of the box, customizable when needed

## Development

```bash
# Run tests
swift test

# Build debug version
swift build

# Build release version
swift build -c release
```

## License

MIT

## Credits

Inspired by [Claude Code](https://claude.ai/code) and the excellent analysis by Vivek on what makes Claude Code great.