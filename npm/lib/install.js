#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// Detect platform and architecture
const platform = process.platform;
const arch = process.arch;

// Map Node.js arch names to our binary names
const archMap = {
  'x64': 'x64',
  'arm64': 'arm64',
  'arm': 'arm64' // Treat arm as arm64 for Apple Silicon
};

const mappedArch = archMap[arch] || arch;

console.log(`Installing swiftopenai-cli for ${platform}-${mappedArch}...`);

// Determine binary path
let binaryName = 'swiftopenai';
let sourcePath;

if (platform === 'darwin') {
  sourcePath = path.join(__dirname, '..', 'binaries', `darwin-${mappedArch}`, binaryName);
} else if (platform === 'linux') {
  sourcePath = path.join(__dirname, '..', 'binaries', `linux-${mappedArch}`, binaryName);
} else {
  console.error(`Unsupported platform: ${platform}`);
  console.error('SwiftOpenAI-CLI currently supports macOS and Linux only.');
  process.exit(1);
}

// Check if binary exists
if (!fs.existsSync(sourcePath)) {
  console.error(`Binary not found for ${platform}-${mappedArch}`);
  console.error(`Expected at: ${sourcePath}`);
  console.error('Please report this issue at: https://github.com/jamesrochabrun/SwiftOpenAICLI/issues');
  process.exit(1);
}

// Copy binary to bin directory
const destPath = path.join(__dirname, '..', 'bin', binaryName);

try {
  // Ensure bin directory exists
  const binDir = path.dirname(destPath);
  if (!fs.existsSync(binDir)) {
    fs.mkdirSync(binDir, { recursive: true });
  }

  // Copy binary
  fs.copyFileSync(sourcePath, destPath);
  
  // Make executable
  fs.chmodSync(destPath, '755');
  
  console.log('✅ SwiftOpenAI-CLI installed successfully!');
  console.log('');
  console.log('You can now use: swiftopenai --help');
  console.log('');
  console.log('Quick start:');
  console.log('1. Set your API key: swiftopenai config set api-key YOUR_KEY');
  console.log('2. Chat with AI: swiftopenai "Hello, world!"');
  
} catch (error) {
  console.error('Failed to install binary:', error.message);
  process.exit(1);
}