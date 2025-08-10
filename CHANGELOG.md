# Changelog

All notable changes to SwiftOpenAI-CLI will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0] - 2024-01-10

### Added
- **GPT-5 Support**: Full support for GPT-5 family models (gpt-5, gpt-5-mini, gpt-5-nano)
- **Verbosity Control**: New `--verbose` parameter for GPT-5 models (low, medium, high)
- **Reasoning Effort**: New `--reasoning` parameter for GPT-5 models (minimal, low, medium, high)
- **Model Name Normalization**: Automatic conversion of user-friendly model names (e.g., `gpt5` → `gpt-5`)
- **Comprehensive Tests**: Added 50+ unit tests for new GPT-5 features
- **Enhanced Documentation**: Updated README with GPT-5 examples and usage guidelines

### Changed
- Updated SwiftOpenAI dependency to v4.3.2
- Improved model detection logic to support both hyphenated and non-hyphenated model names
- Made CompleteCommand use consistent enum types for verbose and reasoning parameters

### Technical Details
- Model name aliases support: `gpt5`/`gpt-5`, `gpt5mini`/`gpt-5-mini`, `gpt5nano`/`gpt-5-nano`
- Case-insensitive model name handling
- Parameters only apply to GPT-5 models, ignored for other models

## [1.1.0] - Previous Release

### Added
- Initial release with core functionality
- Chat, Image, Models, Complete, and Embed commands
- Configuration management
- Support for alternative providers