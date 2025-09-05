# Getting Started with ExJsonschema

ExJsonschema provides fast, safe JSON Schema validation for Elixir using a Rust-powered engine. This guide will walk you through the basics and get you validating JSON in minutes.

## Installation

Add ExJsonschema to your dependencies:

```elixir
# mix.exs
def deps do
  [
    {:ex_jsonschema, "~> 0.1.0"}
  ]
end
```

No Rust toolchain required - precompiled binaries are included!

## Basic Usage

### 1. Compile a Schema

First, compile your JSON Schema:

```elixir
# Define your schema
schema = ~s({
  "type": "object",
  "properties": {
    "name": {"type": "string"},
    "age": {"type": "number", "minimum": 0}
  },
  "required": ["name"]
})

# Compile it (do this once, reuse many times)
{:ok, compiled_schema} = ExJsonschema.compile(schema)
```

### 2. Validate JSON Data

Now validate your JSON data:

```elixir
# Valid data
valid_data = ~s({"name": "Alice", "age": 30})
:ok = ExJsonschema.validate(compiled_schema, valid_data)

# Invalid data  
invalid_data = ~s({"age": -5})
{:error, errors} = ExJsonschema.validate(compiled_schema, invalid_data)

# Print the errors
Enum.each(errors, fn error ->
  IO.puts("Error: #{error.message} at #{error.instance_path}")
end)
# => Error: "name" is a required property at 
# => Error: -5 is less than the minimum of 0 at /age
```

### 3. Quick Validity Check

For simple true/false validation (faster):

```elixir
if ExJsonschema.valid?(compiled_schema, valid_data) do
  IO.puts("Data is valid!")
end
```

## Common Patterns

### User Registration Form

A typical use case - validating user registration data:

```elixir
user_schema = ~s({
  "type": "object",
  "properties": {
    "email": {
      "type": "string",
      "format": "email"
    },
    "username": {
      "type": "string", 
      "minLength": 3,
      "maxLength": 20,
      "pattern": "^[a-zA-Z0-9_]+$"
    },
    "age": {
      "type": "integer",
      "minimum": 13,
      "maximum": 120
    },
    "terms_accepted": {
      "type": "boolean",
      "const": true
    }
  },
  "required": ["email", "username", "age", "terms_accepted"],
  "additionalProperties": false
})

{:ok, user_validator} = ExJsonschema.compile(user_schema)

# Test with user data
user_data = ~s({
  "email": "alice@example.com",
  "username": "alice123",
  "age": 25,
  "terms_accepted": true
})

case ExJsonschema.validate(user_validator, user_data) do
  :ok -> 
    IO.puts("User registration is valid!")
  {:error, errors} ->
    IO.puts("Validation failed:")
    Enum.each(errors, &IO.puts("  - #{&1.message}"))
end
```

### API Response Validation

Validate API responses with conditional logic:

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

{:ok, api_validator} = ExJsonschema.compile(api_response_schema)

# Success response
success_response = ~s({
  "status": "success",
  "data": {"user_id": 123},
  "timestamp": "2024-01-15T10:30:00Z"
})

:ok = ExJsonschema.validate(api_validator, success_response)

# Error response  
error_response = ~s({
  "status": "error",
  "message": "User not found",
  "timestamp": "2024-01-15T10:30:00Z"
})

:ok = ExJsonschema.validate(api_validator, error_response)
```

## Working with Different Data Sources

### Phoenix Controllers

```elixir
defmodule MyAppWeb.UserController do
  use MyAppWeb, :controller

  @user_schema ~s({
    "type": "object",
    "properties": {
      "name": {"type": "string", "minLength": 1},
      "email": {"type": "string", "format": "email"}
    },
    "required": ["name", "email"]
  })

  def create(conn, params) do
    # Compile schema once (consider moving to module attribute)
    {:ok, validator} = ExJsonschema.compile(@user_schema)
    
    # Convert params to JSON for validation
    json_params = Jason.encode!(params["user"])
    
    case ExJsonschema.validate(validator, json_params) do
      :ok ->
        # Proceed with user creation
        {:ok, user} = create_user(params["user"])
        render(conn, "show.json", user: user)
        
      {:error, errors} ->
        error_messages = Enum.map(errors, & &1.message)
        conn
        |> put_status(:unprocessable_entity)
        |> render("error.json", errors: error_messages)
    end
  end
end
```

### LiveView Forms

```elixir
defmodule MyAppWeb.UserFormLive do
  use MyAppWeb, :live_view

  @user_schema ~s({
    "type": "object", 
    "properties": {
      "name": {"type": "string", "minLength": 1},
      "email": {"type": "string", "format": "email"},
      "age": {"type": "integer", "minimum": 0, "maximum": 150}
    },
    "required": ["name", "email"]
  })

  def mount(_params, _session, socket) do
    {:ok, validator} = ExJsonschema.compile(@user_schema)
    
    socket = assign(socket, 
      user: %{},
      validator: validator,
      errors: []
    )
    
    {:ok, socket}
  end

  def handle_event("validate_user", %{"user" => user_params}, socket) do
    json_data = Jason.encode!(user_params)
    
    errors = case ExJsonschema.validate(socket.assigns.validator, json_data) do
      :ok -> []
      {:error, errors} -> Enum.map(errors, & &1.message)
    end
    
    {:noreply, assign(socket, user: user_params, errors: errors)}
  end
end
```

## Schema Compilation Strategies

### Static Schemas with Caching (Recommended)

For schemas that don't change, use the library's built-in caching with schema IDs:

```elixir
defmodule MyApp.Validators do
  # Schema with $id will be automatically cached by the library
  @user_schema ~s({
    "$id": "http://myapp.com/schemas/user.json",
    "type": "object",
    "properties": {
      "name": {"type": "string"},
      "email": {"type": "string", "format": "email"}
    },
    "required": ["name", "email"]
  })

  def validate_user(data) do
    # First call compiles and caches, subsequent calls use cached version
    case ExJsonschema.compile(@user_schema) do
      {:ok, validator} -> ExJsonschema.validate(validator, data)
      {:error, _} = error -> error
    end
  end

  # Alternative: compile once at module level and store in a module attribute
  # (This works for truly static schemas that never change)
  def validate_user_static(data) do
    validator = get_cached_validator()
    ExJsonschema.validate(validator, data)
  end

  # Private function to ensure we only compile once per module
  defp get_cached_validator do
    case :persistent_term.get({__MODULE__, :user_validator}, nil) do
      nil ->
        {:ok, validator} = ExJsonschema.compile(@user_schema)
        :persistent_term.put({__MODULE__, :user_validator}, validator)
        validator
      validator ->
        validator
    end
  end
end
```

### Runtime Compilation

For dynamic schemas or schemas loaded from external sources:

```elixir
defmodule MyApp.DynamicValidator do
  def validate_with_schema(data, schema_json) do
    with {:ok, compiled} <- ExJsonschema.compile(schema_json),
         :ok <- ExJsonschema.validate(compiled, data) do
      :ok
    end
  end
end
```

### One-Shot Validation

For infrequent validations where performance isn't critical:

```elixir
# Compiles and validates in one step
case ExJsonschema.validate_once(schema_json, data_json) do
  :ok -> :valid
  {:error, errors} -> {:invalid, errors}
end
```

## Error Handling

### Compilation Errors

Handle schema compilation failures gracefully:

```elixir
case ExJsonschema.compile(invalid_schema) do
  {:ok, compiled} -> 
    # Use compiled schema
    compiled
    
  {:error, %ExJsonschema.CompilationError{} = error} ->
    Logger.error("Schema compilation failed: #{error.message}")
    # Fallback behavior or re-raise
    raise "Invalid schema configuration"
end
```

### Validation Errors

Extract useful information from validation errors:

```elixir
case ExJsonschema.validate(validator, data) do
  :ok ->
    :valid
    
  {:error, errors} ->
    # Group errors by field path
    errors_by_field = 
      errors
      |> Enum.group_by(& &1.instance_path)
      |> Enum.map(fn {path, field_errors} ->
        messages = Enum.map(field_errors, & &1.message)
        {path, messages}
      end)
    
    {:invalid, errors_by_field}
end
```

## Performance Tips

1. **Compile Once, Validate Many**: Always compile schemas once and reuse them
2. **Use Module Attributes**: For static schemas, compile at module load time
3. **Choose the Right Function**: Use `valid?/2` when you only need true/false
4. **Consider Output Formats**: Use `:basic` output format for maximum speed

```elixir
# Fastest validation (basic output)
opts = ExJsonschema.Options.new(output_format: :basic)
case ExJsonschema.validate(validator, data, opts) do
  :ok -> :valid
  {:error, _} -> :invalid  # No detailed errors
end
```

## Next Steps

Now that you understand the basics, explore more advanced features:

- **[Advanced Features Guide](advanced_features.html)** - Profiles, caching, and configuration options
- **[Performance Guide](performance_production.html)** - Optimization for high-throughput applications
- **[API Documentation](ExJsonschema.html)** - Complete reference for all functions and options

## Common Gotchas

### JSON String Requirements

ExJsonschema expects JSON strings, not Elixir data structures:

```elixir
# ❌ This won't work - Elixir map
data = %{"name" => "Alice"}  
ExJsonschema.validate(validator, data)  # Type error!

# ✅ This works - JSON string
data = ~s({"name": "Alice"})
ExJsonschema.validate(validator, data)  # Success!

# ✅ Or encode Elixir data to JSON first
data = Jason.encode!(%{"name" => "Alice"})
ExJsonschema.validate(validator, data)  # Success!
```

### Schema JSON Format

Schemas must also be valid JSON strings:

```elixir
# ❌ Invalid JSON syntax
schema = ~s({"type": "object",})  # Trailing comma

# ✅ Valid JSON
schema = ~s({"type": "object"})
```

### Format Validation

String formats like "email" are NOT validated by default:

```elixir
# Enable format validation explicitly
opts = ExJsonschema.Options.new(validate_formats: true)
ExJsonschema.validate(validator, data, opts)

# Or use a profile that includes format validation
strict_opts = ExJsonschema.Options.new(:strict)
ExJsonschema.validate(validator, data, strict_opts)
```