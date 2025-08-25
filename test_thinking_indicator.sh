#!/bin/bash

echo "Testing thinking indicators..."

# Test with ISA
echo -e "\n1. Testing ISA thinking indicator (should show animated word):"
echo -e "hello\nexit" | /Users/jamesrochabrun/Desktop/git/SwiftOpenAICLI/isa-cli/.build/debug/ISA --model gpt-4o-mini 2>&1 | grep -E "Assistant:|thinking" -A 1 -B 1

echo -e "\n2. Testing agent interactive thinking indicator:"
echo -e "hello\nexit" | swift run swiftopenai agent --interactive --model gpt-4o-mini 2>&1 | grep -E "Assistant:|thinking" -A 1 -B 1

echo "Done!"