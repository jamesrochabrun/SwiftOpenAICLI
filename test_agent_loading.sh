#!/bin/bash

echo "Testing loading indicators in agent mode..."

# Enable animated loading
swift run swiftopenai config set animated-loading true
swift run swiftopenai config set ai-loading-words false

# Test with a command that will use tools
echo "List the Swift files in this project" | swift run swiftopenai agent --model gpt-4o-mini --max-tool-calls 3 --verbose

echo "Done!"