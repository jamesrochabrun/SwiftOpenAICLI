#!/bin/bash

echo "Testing performance improvements..."
echo "Measuring response time for first message (should be fast now):"

# Test ISA response time
start=$(date +%s%N)
echo -e "hello\nexit" | timeout 10 /Users/jamesrochabrun/Desktop/git/SwiftOpenAICLI/isa-cli/.build/debug/ISA --model gpt-4o-mini 2>&1 | grep -q "Assistant:" 
end=$(date +%s%N)

elapsed=$(( ($end - $start) / 1000000 ))
echo "Time to first Assistant response: ${elapsed}ms"

echo -e "\nTesting variety of loading words (fallback should be random):"
for i in {1..5}; do
    echo -e "hello\nexit" | /Users/jamesrochabrun/Desktop/git/SwiftOpenAICLI/isa-cli/.build/debug/ISA --model gpt-4o-mini 2>&1 | grep "Assistant:" | head -1 | sed 's/.*(\(.*\)).*/\1/'
done

echo -e "\nDone!"