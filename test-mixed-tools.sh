#!/bin/bash

# Test mixed tools (local and MCP)
echo "Testing mixed local and MCP tools..."
echo

# Test 1: List available tools
echo "1. Testing local tool (system_info):"
./.build/debug/swiftopenai agent "What operating system is this?" \
  --local-tools-config ./local-tools-example.json \
  --allowed-tools system_info

echo
echo "2. Testing with both local and potential MCP tools (if configured):"
./.build/debug/swiftopenai agent "List files in current directory and tell me the system info" \
  --local-tools-config ./local-tools-example.json \
  --allowed-tools "list_files,system_info"

echo
echo "3. Testing glob pattern for all local tools:"
./.build/debug/swiftopenai agent "What's the date and what OS is this?" \
  --local-tools-config ./local-tools-example.json \
  --allowed-tools "local__*"