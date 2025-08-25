#!/bin/bash

echo "Testing final implementation..."

# Clean config to remove old ai-loading-words setting
swift run swiftopenai config set animated-loading true

echo -e "\n1. Testing /config command in ISA (should NOT show output-format):"
echo -e "/config\nexit" | /Users/jamesrochabrun/Desktop/git/SwiftOpenAICLI/isa-cli/.build/debug/ISA --model gpt-4o-mini 2>&1 | grep -A 20 "Current Configuration"

echo -e "\n2. Testing loading indicators with AI words (should show creative words):"
echo -e "pwd\nexit" | /Users/jamesrochabrun/Desktop/git/SwiftOpenAICLI/isa-cli/.build/debug/ISA --model gpt-4o-mini --max-tool-calls 3 2>&1 | grep -E "Calling tool:|Result:" -A 1 -B 1

echo "Done!"