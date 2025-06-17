# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2024-12-17

### Added

- Initial release of ExJsonschema
- High-performance JSON Schema validation using Rust `jsonschema` crate v0.20
- Support for JSON Schema draft-07, draft 2019-09, and draft 2020-12
- Precompiled NIF binaries for major platforms (no Rust toolchain required)
- Comprehensive API with multiple validation functions:
  - `compile/1` and `compile!/1` - Schema compilation
  - `validate/2` and `validate!/2` - Full validation with detailed errors
  - `valid?/2` - Fast boolean validation check
  - `validate_once/2` - One-shot compilation and validation
- Enhanced error handling with structured `CompilationError` and `ValidationError` types
- Detailed error messages with JSON path information and validation context
- Memory-safe NIF implementation with proper panic handling
- Comprehensive test suite with 27 tests covering all functionality
- Complete documentation with examples and API reference
- Zero-dependency installation for end users

### Technical Details

- Built with Rustler v0.36 for safe Rust-Elixir interop
- Uses `rustler_precompiled` v0.8 for precompiled binary distribution
- Implements proper NIF resource management for compiled schemas
- Supports multiple architectures: x86_64 and aarch64 for macOS, Linux, and Windows
- Optimized for performance with compile-once, validate-many pattern

[Unreleased]: https://github.com/hassox/ex_jsonschema/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/hassox/ex_jsonschema/releases/tag/v0.1.0 