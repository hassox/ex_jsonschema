# Advanced Features

ExJsonschema provides powerful configuration options, caching, and validation features for sophisticated use cases. This guide covers profiles, caching strategies, advanced validation options, and best practices for production applications.

## Configuration Profiles

ExJsonschema includes three pre-built configuration profiles optimized for common scenarios:

### Profile Overview

| Profile | Use Case | Output Format | Format Validation | Performance |
|---------|----------|---------------|-------------------|-------------|
| `:strict` | APIs, compliance, production | `:verbose` | ✅ Enabled | Good |
| `:lenient` | User forms, UX, development | `:detailed` | ❌ Disabled | Better |
| `:performance` | High-throughput, batch processing | `:basic` | ❌ Disabled | Best |

### Using Profiles

```elixir
# Use a predefined profile
strict_opts = ExJsonschema.Options.new(:strict)
{:ok, validator} = ExJsonschema.compile(schema, strict_opts)

# Validate with profile options
lenient_opts = ExJsonschema.Options.new(:lenient)
ExJsonschema.validate(validator, data, lenient_opts)

# Override specific profile settings
custom_strict = ExJsonschema.Options.new({:strict, [output_format: :basic]})
ExJsonschema.validate(validator, data, custom_strict)
```

### Profile Details

#### Strict Profile
Best for APIs, compliance, and production environments where comprehensive validation is required:

```elixir
strict_opts = ExJsonschema.Options.new(:strict)
# Equivalent to:
# %ExJsonschema.Options{
#   validate_formats: true,     # Validate email, uri, etc.
#   output_format: :verbose,    # Maximum error detail
#   draft: :auto,               # Auto-detect schema version
#   regex_engine: :default      # Use default regex engine
# }

# Example: API endpoint validation
api_schema = ~s({
  "type": "object",
  "properties": {
    "email": {"type": "string", "format": "email"},
    "website": {"type": "string", "format": "uri"}
  }
})

{:ok, validator} = ExJsonschema.compile(api_schema)

# Strict validation catches format violations
invalid_data = ~s({"email": "not-an-email", "website": "invalid-uri"})
{:error, errors} = ExJsonschema.validate(validator, invalid_data, strict_opts)

# You get detailed format validation errors
errors
|> Enum.each(fn error -> 
  IO.puts("#{error.instance_path}: #{error.message}")
end)
# => /email: "not-an-email" is not a valid "email"
# => /website: "invalid-uri" is not a valid "uri"
```

#### Lenient Profile  
Perfect for user-facing forms where UX matters more than strict compliance:

```elixir
lenient_opts = ExJsonschema.Options.new(:lenient)
# Equivalent to:
# %ExJsonschema.Options{
#   validate_formats: false,    # Skip format validation
#   output_format: :detailed,   # Good error detail
#   draft: :auto,
#   regex_engine: :default
# }

# Example: User registration form
user_form_data = ~s({
  "name": "Alice",
  "email": "alice@invalid-domain",  # Invalid email format
  "age": 25
})

# Lenient validation focuses on structure, not formats
case ExJsonschema.validate(validator, user_form_data, lenient_opts) do
  :ok -> 
    # Email format not validated - passes validation
    # You can add format validation in your application layer
    IO.puts("Basic structure is valid!")
  {:error, errors} ->
    # Only structural violations reported
    IO.puts("Structure errors: #{length(errors)}")
end
```

#### Performance Profile
Optimized for high-throughput scenarios where speed is critical:

```elixir
perf_opts = ExJsonschema.Options.new(:performance)
# Equivalent to:
# %ExJsonschema.Options{
#   validate_formats: false,    # Skip format validation
#   output_format: :basic,      # Minimal error info
#   draft: :auto,
#   regex_engine: :default
# }

# Example: Batch processing
data_batch = [
  ~s({"id": 1, "name": "Alice"}),
  ~s({"id": 2, "name": "Bob"}),
  ~s({"id": 3, "name": "Carol"})
  # ... thousands more
]

# Fast validation with minimal overhead
{valid_count, invalid_count} = 
  Enum.reduce(data_batch, {0, 0}, fn item, {valid, invalid} ->
    case ExJsonschema.validate(validator, item, perf_opts) do
      :ok -> {valid + 1, invalid}
      {:error, _} -> {valid, invalid + 1}
    end
  end)

IO.puts("Processed: #{valid_count} valid, #{invalid_count} invalid")
```

### Custom Profiles

Create your own profiles for specific use cases:

```elixir
# API profile: strict validation with optimized output
api_profile = ExJsonschema.Options.new(
  validate_formats: true,
  output_format: :detailed,  # Less verbose than :verbose
  draft: :draft7             # Lock to specific draft
)

# Debug profile: maximum information
debug_profile = ExJsonschema.Options.new(
  validate_formats: true,
  output_format: :verbose,
  draft: :auto
)

# Batch profile: balanced speed and error info
batch_profile = ExJsonschema.Options.new(
  validate_formats: false,
  output_format: :detailed,  # More info than :basic
  draft: :auto
)
```

## Advanced Validation Options

### Output Formats

Control the level of detail in validation errors:

```elixir
# Basic: fastest, minimal error info
basic_opts = ExJsonschema.Options.new(output_format: :basic)
case ExJsonschema.validate(validator, data, basic_opts) do
  :ok -> :valid
  {:error, _errors} -> :invalid  # Errors list is minimal
end

# Detailed: good balance of speed and information (default)
detailed_opts = ExJsonschema.Options.new(output_format: :detailed)
{:error, errors} = ExJsonschema.validate(validator, data, detailed_opts)
error = List.first(errors)
IO.puts("Path: #{error.instance_path}")
IO.puts("Message: #{error.message}")

# Verbose: maximum detail, includes schema paths
verbose_opts = ExJsonschema.Options.new(output_format: :verbose)
{:error, errors} = ExJsonschema.validate(validator, data, verbose_opts)
error = List.first(errors)
IO.puts("Instance path: #{error.instance_path}")
IO.puts("Schema path: #{error.schema_path}")
IO.puts("Message: #{error.message}")
```

### Draft Version Control

Explicitly control which JSON Schema draft to use:

```elixir
# Auto-detect from schema (default)
auto_opts = ExJsonschema.Options.new(draft: :auto)

# Force specific draft versions
draft7_opts = ExJsonschema.Options.new(draft: :draft7)
draft2019_opts = ExJsonschema.Options.new(draft: :"2019-09")
draft2020_opts = ExJsonschema.Options.new(draft: :"2020-12")

# Example: ensure consistent draft behavior
schema_v7 = ~s({
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "properties": {
    "name": {"type": "string"}
  }
})

# Force draft-07 even if schema specifies different version
{:ok, validator} = ExJsonschema.compile(schema_v7, draft7_opts)
```

### Format Validation Control

Fine-tune string format validation:

```elixir
# Enable all format validation
format_opts = ExJsonschema.Options.new(validate_formats: true)

schema_with_formats = ~s({
  "type": "object",
  "properties": {
    "email": {"type": "string", "format": "email"},
    "date": {"type": "string", "format": "date"},
    "uri": {"type": "string", "format": "uri"},
    "uuid": {"type": "string", "format": "uuid"}
  }
})

{:ok, validator} = ExJsonschema.compile(schema_with_formats)

# Test format validation
test_data = ~s({
  "email": "user@example.com",
  "date": "2024-01-15",
  "uri": "https://example.com", 
  "uuid": "123e4567-e89b-12d3-a456-426614174000"
})

:ok = ExJsonschema.validate(validator, test_data, format_opts)

# Invalid formats are caught
invalid_data = ~s({
  "email": "not-an-email",
  "date": "invalid-date",
  "uri": "not a uri",
  "uuid": "not-a-uuid"
})

{:error, errors} = ExJsonschema.validate(validator, invalid_data, format_opts)
IO.puts("Format errors found: #{length(errors)}")
```

## Caching Strategies

ExJsonschema provides flexible caching for compiled schemas to boost performance in applications with repeated schema usage.

### Cache Backends

#### No Caching (Default)
```elixir
# Default behavior - no caching
{:ok, validator1} = ExJsonschema.compile(schema)
{:ok, validator2} = ExJsonschema.compile(schema)
# validator1 != validator2 (different references)
```

#### Noop Cache (Testing)
```elixir
# config/test.exs - recommended for tests
config :ex_jsonschema, cache: ExJsonschema.Cache.Noop

# All cache operations are no-ops, schemas are never cached
{:ok, validator} = ExJsonschema.compile(schema_with_id)
```

#### Custom Cache Implementation

You can implement your own cache backend by creating a module that implements the `ExJsonschema.Cache` behaviour. You might use ETS, Cachex, Nebulex, or any other storage system that fits your needs.

```elixir
# config/config.exs
config :ex_jsonschema, cache: MyApp.SchemaCache
```

### Cache Testing

For tests, disable caching to avoid interdependence between test cases:

```elixir
# config/test.exs
config :ex_jsonschema, cache: ExJsonschema.Cache.Noop
```

## Best Practices

### Schema Organization

Organize schemas in a dedicated module:

```elixir
defmodule MyApp.Schemas do
  @moduledoc "JSON Schema definitions and validators"

  # Schemas with $id will be cached automatically by ExJsonschema
  @user_schema ~s({
    "$id": "http://myapp.com/schemas/user.json",
    "type": "object",
    "properties": {
      "name": {"type": "string", "minLength": 1},
      "email": {"type": "string", "format": "email"},
      "age": {"type": "integer", "minimum": 0}
    },
    "required": ["name", "email"]
  })

  @product_schema ~s({
    "$id": "http://myapp.com/schemas/product.json",
    "type": "object", 
    "properties": {
      "name": {"type": "string"},
      "price": {"type": "number", "minimum": 0},
      "category": {"type": "string", "enum": ["electronics", "books", "clothing"]}
    },
    "required": ["name", "price", "category"]
  })

  # Validation functions - library handles caching automatically
  def validate_user(data) do
    case ExJsonschema.compile(@user_schema) do
      {:ok, validator} -> ExJsonschema.validate(validator, data)
      error -> error
    end
  end

  def validate_product(data) do
    case ExJsonschema.compile(@product_schema) do
      {:ok, validator} -> ExJsonschema.validate(validator, data)  
      error -> error
    end
  end
  
  # Quick validity checks
  def valid_user?(data) do
    case ExJsonschema.compile(@user_schema) do
      {:ok, validator} -> ExJsonschema.valid?(validator, data)
      {:error, _} -> false
    end
  end

  def valid_product?(data) do
    case ExJsonschema.compile(@product_schema) do
      {:ok, validator} -> ExJsonschema.valid?(validator, data)
      {:error, _} -> false
    end
  end

  # If you need the compiled validators for advanced usage
  def get_user_validator, do: ExJsonschema.compile(@user_schema)
  def get_product_validator, do: ExJsonschema.compile(@product_schema)
end
```

### Error Information

Validation errors contain:

- `instance_path` - Location in the data where the error occurred
- `schema_path` - Location in the schema that caused the error  
- `message` - Human-readable error message

```elixir
case ExJsonschema.validate(validator, data) do
  :ok -> 
    # validation passed
  {:error, errors} ->
    # errors is a list of validation error structs
    Enum.each(errors, fn error ->
      IO.puts("Error at #{error.instance_path}: #{error.message}")
    end)
end
```

### Integration Patterns

#### Ecto Changesets
```elixir
defmodule MyApp.User do
  use Ecto.Schema
  import Ecto.Changeset

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:name, :email, :metadata])
    |> validate_required([:name, :email])
    |> validate_metadata()
  end

  defp validate_metadata(changeset) do
    case get_field(changeset, :metadata) do
      nil -> changeset
      metadata ->
        json_metadata = Jason.encode!(metadata)
        
        case MyApp.Schemas.validate_user_metadata(json_metadata) do
          :ok -> changeset
          {:error, errors} ->
            error_msg = Enum.map(errors, & &1.message) |> Enum.join(", ")
            add_error(changeset, :metadata, "invalid metadata: #{error_msg}")
        end
    end
  end
end
```

#### Plug Validation
```elixir
defmodule MyAppWeb.ValidateJsonPlug do
  import Plug.Conn

  def init(schema_validator), do: schema_validator

  def call(conn, validator) do
    with {:ok, body, conn} <- read_body(conn),
         :ok <- ExJsonschema.validate(validator, body) do
      assign(conn, :validated_json, body)
    else
      {:error, validation_errors} ->
        errors = Enum.map(validation_errors, & &1.message)
        
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(400, Jason.encode!(%{errors: errors}))
        |> halt()
    end
  end
end
```

## Troubleshooting

### Common Issues

**Schema compilation fails**:
```elixir
# Check JSON syntax
case Jason.decode(schema_string) do
  {:ok, _} -> IO.puts("Valid JSON")
  {:error, error} -> IO.puts("JSON error: #{error}")
end

# Check schema validity 
case ExJsonschema.compile(schema_string) do
  {:ok, _} -> IO.puts("Valid schema")
  {:error, error} -> IO.puts("Schema error: #{error.message}")
end
```

**Unexpected validation results**:
```elixir
# Use verbose output for debugging
debug_opts = ExJsonschema.Options.new(output_format: :verbose)
case ExJsonschema.validate(validator, data, debug_opts) do
  :ok -> IO.puts("Valid")
  {:error, errors} ->
    Enum.each(errors, fn error ->
      IO.puts("Error at #{error.instance_path}")
      IO.puts("  Schema path: #{error.schema_path}")
      IO.puts("  Message: #{error.message}")
    end)
end
```

**Performance issues**:
```elixir
# Profile your validation
:timer.tc(fn -> 
  ExJsonschema.validate(validator, data, performance_opts)
end)
|> IO.inspect(label: "Validation time (microseconds)")
```

### Debug Helpers

```elixir
defmodule MyApp.ValidationDebug do
  def inspect_schema(validator) do
    # Print schema information (if available)
    IO.puts("Validator: #{inspect(validator)}")
  end

  def compare_results(validator, data, opts1, opts2) do
    result1 = ExJsonschema.validate(validator, data, opts1)
    result2 = ExJsonschema.validate(validator, data, opts2)
    
    IO.puts("Options 1 result: #{inspect(result1)}")
    IO.puts("Options 2 result: #{inspect(result2)}")
    IO.puts("Results match: #{result1 == result2}")
  end

  def validate_with_timing(validator, data, opts \\ []) do
    {time, result} = :timer.tc(ExJsonschema, :validate, [validator, data, opts])
    
    IO.puts("Validation took #{time} microseconds")
    result
  end
end
```

## Next Steps

- **[Performance & Production Guide](performance_production.html)** - Optimization and deployment strategies  
- **[Streaming Validation Guide](streaming_validation.html)** - Handle large datasets efficiently
- **[API Documentation](ExJsonschema.html)** - Complete reference for all functions