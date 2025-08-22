#!/bin/bash

# Test Zapier MCP connection with a timeout
(
    ./.build/debug/swiftopenai agent "Test connection to Zapier and list available tools" --mcp-servers zapier --show-mcp-status
) &

PID=$!
sleep 30
if kill -0 $PID 2>/dev/null; then
    echo "Command timed out, killing process"
    kill $PID
    exit 1
else
    wait $PID
    exit $?
fi