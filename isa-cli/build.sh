#!/bin/bash

set -e

echo "Building ISA CLI..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Build for macOS ARM64 (Apple Silicon)
echo -e "${YELLOW}Building for macOS ARM64...${NC}"
swift build -c release --arch arm64 --product ISA
mkdir -p npm/binaries/darwin-arm64
cp .build/arm64-apple-macosx/release/ISA npm/binaries/darwin-arm64/isa
echo -e "${GREEN}✓ macOS ARM64 build complete${NC}"

# Build for macOS x64 (Intel) - requires Rosetta or cross-compilation
if [[ "$OSTYPE" == "darwin"* ]]; then
  echo -e "${YELLOW}Building for macOS x64...${NC}"
  swift build -c release --arch x86_64 --product ISA 2>/dev/null || {
    echo -e "${YELLOW}Note: x64 build requires Rosetta 2 or cross-compilation setup${NC}"
  }
  if [ -f .build/x86_64-apple-macosx/release/ISA ]; then
    mkdir -p npm/binaries/darwin-x64
    cp .build/x86_64-apple-macosx/release/ISA npm/binaries/darwin-x64/isa
    echo -e "${GREEN}✓ macOS x64 build complete${NC}"
  fi
fi

# Make binaries executable
chmod +x npm/binaries/*/isa 2>/dev/null || true

echo -e "${GREEN}Build complete!${NC}"
echo ""
echo "To test locally:"
echo "  cd npm && npm link"
echo "  isa"
echo ""
echo "To publish to npm:"
echo "  cd npm && npm publish"