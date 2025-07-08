#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

const binaryPath = path.join(__dirname, '..', 'bin', 'swiftopenai');

try {
  if (fs.existsSync(binaryPath)) {
    fs.unlinkSync(binaryPath);
    console.log('SwiftOpenAI-CLI uninstalled successfully.');
  }
} catch (error) {
  // Ignore errors during uninstall
}