#!/bin/bash

set -e

echo "Building SwiftOpenAI CLI with optimizations..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Optimization flags for smaller binary size
OPTIMIZATION_FLAGS="-Xswiftc -O -Xswiftc -whole-module-optimization -Xswiftc -enforce-exclusivity=unchecked -Xswiftc -cross-module-optimization"

# Build for macOS ARM64 (Apple Silicon)
echo -e "${YELLOW}Building optimized binary for macOS ARM64...${NC}"
swift build -c release --arch arm64 --product SwiftOpenAICLI $OPTIMIZATION_FLAGS
mkdir -p npm/binaries/darwin-arm64
cp .build/arm64-apple-macosx/release/SwiftOpenAICLI npm/binaries/darwin-arm64/swiftopenai

# Strip debug symbols from ARM64 binary
echo -e "${YELLOW}Stripping debug symbols from ARM64 binary...${NC}"
strip -rSTx npm/binaries/darwin-arm64/swiftopenai
echo -e "${GREEN}✓ macOS ARM64 optimized build complete${NC}"

# Build for macOS x64 (Intel) - requires Rosetta or cross-compilation
if [[ "$OSTYPE" == "darwin"* ]]; then
  echo -e "${YELLOW}Building optimized binary for macOS x64...${NC}"
  swift build -c release --arch x86_64 --product SwiftOpenAICLI $OPTIMIZATION_FLAGS 2>/dev/null || {
    echo -e "${YELLOW}Note: x64 build requires Rosetta 2 or cross-compilation setup${NC}"
  }
  if [ -f .build/x86_64-apple-macosx/release/SwiftOpenAICLI ]; then
    mkdir -p npm/binaries/darwin-x64
    cp .build/x86_64-apple-macosx/release/SwiftOpenAICLI npm/binaries/darwin-x64/swiftopenai
    
    # Strip debug symbols from x64 binary
    echo -e "${YELLOW}Stripping debug symbols from x64 binary...${NC}"
    strip -rSTx npm/binaries/darwin-x64/swiftopenai
    echo -e "${GREEN}✓ macOS x64 optimized build complete${NC}"
  fi
fi

# Make binaries executable
chmod +x npm/binaries/*/swiftopenai 2>/dev/null || true

# Copy the most appropriate binary to npm/bin for local testing
mkdir -p npm/bin
if [ -f npm/binaries/darwin-arm64/swiftopenai ]; then
  cp npm/binaries/darwin-arm64/swiftopenai npm/bin/swiftopenai
elif [ -f npm/binaries/darwin-x64/swiftopenai ]; then
  cp npm/binaries/darwin-x64/swiftopenai npm/bin/swiftopenai
fi
chmod +x npm/bin/swiftopenai 2>/dev/null || true

echo -e "${GREEN}Build complete!${NC}"

# Display binary sizes
echo ""
echo -e "${YELLOW}Binary sizes:${NC}"
if [ -f npm/binaries/darwin-arm64/swiftopenai ]; then
  SIZE_ARM64=$(ls -lh npm/binaries/darwin-arm64/swiftopenai | awk '{print $5}')
  echo -e "  ARM64: ${GREEN}$SIZE_ARM64${NC}"
fi
if [ -f npm/binaries/darwin-x64/swiftopenai ]; then
  SIZE_X64=$(ls -lh npm/binaries/darwin-x64/swiftopenai | awk '{print $5}')
  echo -e "  x64:   ${GREEN}$SIZE_X64${NC}"
fi

echo ""
echo "To test locally:"
echo "  cd npm && npm link"
echo "  swiftopenai"
echo ""
echo "To publish to npm:"
echo "  cd npm && npm publish"