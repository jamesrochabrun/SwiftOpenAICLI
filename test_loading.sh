#!/bin/bash

echo "Testing loading indicators..."

# Test with agent mode
echo -e "\n1. Testing with agent mode (should show loading indicator):"
echo "Search for files containing 'LoadingIndicator' in the codebase" | swift run swiftopenai agent --model gpt-4o-mini --max-tool-calls 3 --output interactive-stream

# Test with ISA
echo -e "\n2. Testing with ISA (should show loading indicator):"
echo "Find all Swift files in the project" | .build/debug/ISA --model gpt-4o-mini --max-tool-calls 3

echo -e "\nDone testing!"