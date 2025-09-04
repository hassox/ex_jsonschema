# ExJsonschema

🚀 **High-performance JSON Schema validation for Elixir using Rust**

ExJsonschema is a fast, safe, and spec-compliant JSON Schema validator for Elixir, powered by the battle-tested Rust [`jsonschema`](https://crates.io/crates/jsonschema) crate. It provides an idiomatic Elixir API with detailed error reporting and supports multiple JSON Schema draft versions.

## ✨ Features

- **🔥 High Performance**: Rust-powered validation with zero-copy JSON processing (3M+ validations/second)
- **🛡️ Memory Safe**: No risk of crashing the BEAM VM - all Rust panics are caught
- **📋 Spec Compliant**: Supports JSON Schema draft-07, draft 2019-09, and draft 2020-12
- **🔍 Rich Error Formats**: Multiple output formats - basic (fastest), detailed (default), verbose (comprehensive)
- **⚙️ Flexible Validation**: Configurable options for format validation, error handling, and annotations
- **📊 Performance Monitoring**: Built-in benchmarking tools via `mix benchmark`
- **📦 Zero Dependencies**: Precompiled NIFs mean no Rust toolchain required for end users
- **🎯 Idiomatic Elixir**: Clean, functional API with Options structs and keyword lists

## 📋 Installation

Add `ex_jsonschema` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ex_jsonschema, "~> 0.1.0"}
  ]
end
```

That's it! No Rust toolchain required - precompiled binaries are included.

## 🚀 Quick Start

```elixir
# Compile a schema once
schema = ~s({
  "type": "object",
  "properties": {
    "name": {"type": "string", "minLength": 1},
    "age": {"type": "number", "minimum": 0}
  },
  "required": ["name"]
})

{:ok, compiled} = ExJsonschema.compile(schema)

# Validate JSON - fast validation
valid_json = ~s({"name": "Alice", "age": 30})
:ok = ExJsonschema.validate(compiled, valid_json)

# Invalid JSON with detailed errors
invalid_json = ~s({"age": -5})
{:error, errors} = ExJsonschema.validate(compiled, invalid_json)

Enum.each(errors, fn error ->
  IO.puts("❌ #{error.message} at #{error.instance_path}")
end)
# Output:
# ❌ "name" is a required property at 
# ❌ -5 is less than the minimum of 0 at /age
```

## 🎛️ Advanced Features

### Configuration Profiles

ExJsonschema provides three optimized configuration profiles for common use cases:

```elixir
# Strict validation for APIs and compliance
strict_opts = ExJsonschema.Options.new(:strict)
{:ok, validator} = ExJsonschema.compile(schema, strict_opts)

# Lenient validation for user forms and UX
lenient_opts = ExJsonschema.Options.new(:lenient) 
ExJsonschema.validate(validator, user_data, lenient_opts)

# Performance-optimized for high-volume processing
perf_opts = ExJsonschema.Options.new(:performance)
is_valid = ExJsonschema.valid?(validator, data, perf_opts)

# Customize any profile with overrides
custom = ExJsonschema.Options.new({:strict, [output_format: :basic]})

# Create your own custom profile
api_profile = ExJsonschema.Options.new(
  validate_formats: true,
  output_format: :detailed,
  stop_on_first_error: true,
  draft: :draft7
)
```

### Flexible Validation Options

```elixir
# Multiple output formats
ExJsonschema.validate(validator, json, output: :verbose)

# Validation options
ExJsonschema.validate(validator, json, validate_formats: true)

# Options struct for reusable configuration  
opts = ExJsonschema.Options.new(validate_formats: true)
ExJsonschema.validate(validator, json, opts)

# Profile-based configuration
opts = ExJsonschema.Profile.strict(draft: :draft7)
ExJsonschema.validate(validator, json, opts)

# Use your custom profile anywhere
{:ok, validator} = ExJsonschema.compile(schema, api_profile)
ExJsonschema.validate(validator, json, api_profile)
```

See the [API documentation](https://hexdocs.pm/ex_jsonschema) for comprehensive details.

## 📖 API Reference

### Schema Compilation

```elixir
# Compile a schema
{:ok, compiled} = ExJsonschema.compile(schema_json)

# Compile with error handling
case ExJsonschema.compile(schema_json) do
  {:ok, compiled} -> 
    # Use compiled schema
  {:error, %ExJsonschema.CompilationError{} = error} ->
    IO.puts("Schema error: #{error}")
end

# Compile and raise on error
compiled = ExJsonschema.compile!(schema_json)
```

### Validation

```elixir
# Full validation with detailed errors (default)
case ExJsonschema.validate(compiled, json) do
  :ok -> 
    IO.puts("Valid!")
  {:error, errors} ->
    Enum.each(errors, &IO.puts("Error: #{&1}"))
end

# Quick validity check (faster)
if ExJsonschema.valid?(compiled, json) do
  IO.puts("Valid!")
end

# Validation with options
ExJsonschema.validate(compiled, json, validate_formats: true)

# One-shot validation (compile + validate)
ExJsonschema.validate_once(schema_json, instance_json)
```

For comprehensive validation options, output formats, and detailed examples, see the [full API documentation](https://hexdocs.pm/ex_jsonschema).

## 🔍 Enhanced Error Handling

ExJsonschema provides detailed error information to help you debug validation issues:

### Schema Compilation Errors

```elixir
# JSON parsing error
invalid_json = ~s({"type": "string)  # Missing quote
{:error, error} = ExJsonschema.compile(invalid_json)

error.type     # :json_parse_error
error.message  # "Invalid JSON: EOF while parsing a string at line 1 column 16"
error.details  # "Failed to parse JSON at line 1, column 16"

# Schema validation error  
invalid_schema = ~s({"type": "invalid_type"})
{:error, error} = ExJsonschema.compile(invalid_schema)

error.type     # :compilation_error  
error.message  # "Schema compilation failed"
error.details  # "\"invalid_type\" is not valid under any of the schemas listed in the 'anyOf' keyword"
```

### Validation Errors

```elixir
schema = ~s({
  "type": "object",
  "properties": {
    "user": {
      "type": "object", 
      "properties": {
        "age": {"type": "number", "minimum": 0}
      }
    }
  }
})

{:ok, compiled} = ExJsonschema.compile(schema)
{:error, [error]} = ExJsonschema.validate(compiled, ~s({"user": {"age": -5}}))

error.instance_path  # "/user/age"
error.schema_path    # "/properties/user/properties/age/minimum"  
error.message        # "-5 is less than the minimum of 0"
```

## 🏗️ Building from Source

For development or if you need to build from source:

```bash
# Clone the repository
git clone https://github.com/your-username/ex_jsonschema.git
cd ex_jsonschema

# Install dependencies
mix deps.get

# Force build from source (requires Rust toolchain)
EX_JSONSCHEMA_BUILD=1 mix compile

# Run tests
EX_JSONSCHEMA_BUILD=1 mix test
```

## 🎯 Performance

ExJsonschema is designed for high-performance applications:

- **Compiled schemas**: Compile once, validate many times
- **Zero-copy**: Direct validation of JSON strings without intermediate parsing
- **Rust performance**: Orders of magnitude faster than pure Elixir implementations
- **Memory efficient**: Minimal memory allocation during validation
- **Benchmarked**: 3M+ validations/second across all output formats

### Performance Benchmarking

Run the built-in benchmarking suite to measure performance on your system:

```bash
# Run all benchmarks
mix benchmark

# Benchmark specific output format
mix benchmark --format basic
mix benchmark --format detailed  
mix benchmark --format verbose

# Custom iteration count
mix benchmark --iterations 5000
```

### Performance Tips

1. **Compile once, validate many**: Compiled schemas are significantly faster for repeated validation
2. **Choose the right output format**: Use `:basic` for maximum speed when you only need pass/fail
3. **Use configuration profiles**: The `:performance` profile is optimized for high-throughput scenarios
4. **Enable format validation selectively**: Only use `validate_formats: true` when needed  
5. **Use `valid?/2` for boolean checks**: Faster than `validate/2` when you don't need error details

### Configuration Profiles

Choose the profile that best matches your use case:

| Profile | Use Case | Output | Format Validation | Annotations |
|---------|----------|--------|------------------|-------------|
| `:strict` | APIs, compliance | `:verbose` | ✅ Enabled | ✅ Collected |
| `:lenient` | Forms, UX | `:detailed` | ❌ Disabled | ✅ Collected |
| `:performance` | High-volume | `:basic` | ❌ Disabled | ❌ Disabled |

```elixir
# Compare profile differences
ExJsonschema.Profile.compare(:strict, :performance)
# => %{
#      validate_formats: {true, false},
#      output_format: {:verbose, :basic},
#      collect_annotations: {true, false},
#      ...
#    }
```

## 🤝 JSON Schema Support

ExJsonschema supports multiple JSON Schema draft versions:

- ✅ **Draft 7** (2019)
- ✅ **Draft 2019-09** 
- ✅ **Draft 2020-12** (latest)

All core keywords and validation rules are supported, including:
- Type validation (`string`, `number`, `object`, `array`, etc.)
- Constraints (`minimum`, `maximum`, `minLength`, `maxLength`, etc.)
- Object validation (`properties`, `required`, `additionalProperties`, etc.)
- Array validation (`items`, `minItems`, `maxItems`, etc.)
- String formats (`email`, `uri`, `date-time`, etc.)
- Conditional schemas (`if`/`then`/`else`, `allOf`, `anyOf`, `oneOf`)

## 📚 Examples

### User Registration Validation

```elixir
user_schema = ~s({
  "type": "object",
  "properties": {
    "email": {"type": "string", "format": "email"},
    "username": {"type": "string", "minLength": 3, "maxLength": 20},
    "age": {"type": "integer", "minimum": 13, "maximum": 120},
    "preferences": {
      "type": "object",
      "properties": {
        "newsletter": {"type": "boolean"},
        "theme": {"type": "string", "enum": ["light", "dark"]}
      }
    }
  },
  "required": ["email", "username", "age"]
})

{:ok, compiled} = ExJsonschema.compile(user_schema)

# Valid user
user_data = ~s({
  "email": "alice@example.com",
  "username": "alice_cooper", 
  "age": 25,
  "preferences": {
    "newsletter": true,
    "theme": "dark"
  }
})

:ok = ExJsonschema.validate(compiled, user_data)
```

### API Response Validation

```elixir
api_response_schema = ~s({
  "type": "object",
  "properties": {
    "status": {"type": "string", "enum": ["success", "error"]},
    "data": {"type": "object"},
    "message": {"type": "string"},
    "timestamp": {"type": "string", "format": "date-time"}
  },
  "required": ["status", "timestamp"],
  "if": {"properties": {"status": {"const": "error"}}},
  "then": {"required": ["message"]},
  "else": {"required": ["data"]}
})
```

## 🔧 Development

### Requirements

- Elixir 1.12+
- Erlang/OTP 22+
- Rust 1.70+ (only for building from source)

### Running Tests

```bash
mix test                    # Uses precompiled NIF
EX_JSONSCHEMA_BUILD=1 mix test  # Builds from source
```

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built on the excellent [jsonschema](https://crates.io/crates/jsonschema) Rust crate
- Powered by [Rustler](https://github.com/rusterlium/rustler) for safe Rust-Elixir interop
- Inspired by the JSON Schema specification and community

