# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2026-03-20

### Added

- **External schema resolution control** — the NIF no longer makes network calls by default
  - `external_schemas: :ignore` (default) — silently ignores all external `$ref`s with a permissive empty schema
  - `external_schemas: :http` — opt-in to the Rust crate's built-in HTTP fetching
  - `external_schemas: %{url => json}` — pass a pre-resolved map of URI → JSON string
  - `ref_resolver: MyModule` — behaviour-based resolver with automatic transitive ref resolution
- **`ExJsonschema.RefResolver` behaviour** — implement `resolve/1` to fetch external schemas from HTTP, database, filesystem, or any other source
- **`ExJsonschema.extract_refs/1`** — pure-Elixir function that walks a schema and returns all external `$ref` URIs (excludes local `#/...` fragment refs)
- New `:ref_resolution_error` type in `CompilationError` for resolver failures
- `MetaValidator.valid?/2`, `validate/2`, `validate_simple/2`, `validate!/2` — 2-arity variants accepting keyword opts

### Fixed

- **MetaValidator no longer deadlocks on schemas with external `$ref`s** — previously, `meta_validate` called Rust NIFs that attempted HTTP fetching for all `$ref` URIs, causing hangs when refs pointed to localhost or unreachable URLs. MetaValidator now routes through the same compile path with `external_schemas: :ignore`
- Removed `preprocess_schema_for_rust` workaround and `@safe_schema_urls` whitelist — no longer needed since meta-validation uses the compile path with `IgnoreRetriever`
- `valid?/1` now returns `false` instead of raising `ArgumentError` on malformed JSON (consistent with `valid?` semantics)

### Changed

- **Upgraded Rust `jsonschema` crate from 0.33 to 0.45** — picks up upstream bug fixes, performance improvements, and new JSON Schema spec coverage
- **Upgraded Rust `rustler` crate from 0.36 to 0.37** — aligns with the Elixir-side `rustler ~> 0.37.1` dependency
- **Improved validation error accuracy** — error keyword, instance value, and constraint data are now extracted from the crate's structured `ValidationErrorKind` enum instead of being guessed from schema path parsing
  - `error.kind().keyword()` replaces fragile last-segment-of-schema-path heuristic
  - `error.instance()` replaces manual JSON tree navigation for the failing value
  - Type constraint values now render as `"string"` instead of `Single(String)`
- Requires **Rust 1.91+** (due to rustler 0.37 MSRV)

### Removed

- Removed hand-rolled `extract_keyword_from_error` path-parsing logic (replaced by `ValidationErrorKind::keyword()`)
- Removed `get_schema_constraint_value` JSON tree navigation (replaced by `extract_constraint_from_kind`)

## [0.1.1] - 2024-12-17

### Fixed

- Fixed precompiled NIF file extension for macOS targets - now correctly uses `.so` instead of `.dylib` to match Erlang/OTP conventions
- Updated release workflow to generate correct file names for macOS precompiled binaries

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

[Unreleased]: https://github.com/hassox/ex_jsonschema/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/hassox/ex_jsonschema/compare/v0.1.1...v0.2.0
[0.1.1]: https://github.com/hassox/ex_jsonschema/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/hassox/ex_jsonschema/releases/tag/v0.1.0 