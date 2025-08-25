#!/bin/bash

echo "Testing improved formatting..."

# Test single-line result
echo -e "\n1. Single-line result (pwd command):"
echo -e "pwd\nexit" | /Users/jamesrochabrun/Desktop/git/SwiftOpenAICLI/isa-cli/.build/debug/ISA --model gpt-4o-mini 2>&1 | grep -A 3 "Executing tool"

# Test multi-line result
echo -e "\n2. Multi-line result (ls command):"
echo -e "ls -la | head -5\nexit" | /Users/jamesrochabrun/Desktop/git/SwiftOpenAICLI/isa-cli/.build/debug/ISA --model gpt-4o-mini 2>&1 | grep -A 10 "Executing tool"

echo -e "\nDone!"