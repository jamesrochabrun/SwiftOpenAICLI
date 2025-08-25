#!/bin/bash

echo "Testing ISA with loading indicators..."

# Make sure config is set
swift run swiftopenai config set animated-loading true
swift run swiftopenai config set ai-loading-words false

# Test ISA with a command that uses tools
echo -e "pwd\nexit" | /Users/jamesrochabrun/Desktop/git/SwiftOpenAICLI/isa-cli/.build/debug/ISA --model gpt-4o-mini --max-tool-calls 3 2>&1 | grep -A 5 -B 5 "Executing\|Processing\|Searching\|Computing\|tool:"

echo "Done!"