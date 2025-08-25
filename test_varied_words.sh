#!/bin/bash

echo "Testing varied thinking words (running 5 times)..."

for i in {1..5}; do
    echo -e "\nTest $i:"
    echo "hello" | timeout 5 /Users/jamesrochabrun/Desktop/git/SwiftOpenAICLI/isa-cli/.build/debug/ISA --model gpt-4o-mini 2>&1 | grep -E "Assistant:" | head -1
    sleep 1
done

echo -e "\nDone!"