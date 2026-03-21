# Meta-Validation Guide

Meta-validation ensures that JSON Schema documents themselves are valid according to their respective meta-schema specifications.

## Overview

Meta-validation validates that:
- Schema structure follows the correct JSON Schema format
- All keywords are valid for the declared draft version
- Schema constraints are properly defined
- Schema is well-formed and complete

## Basic Usage

```elixir
# Quick validation check
schema = ~s({"type": "string", "minLength": 5})
ExJsonschema.meta_valid?(schema)
#=> true

# Detailed validation with error reporting
invalid_schema = ~s({"type": "invalid_type"})
case ExJsonschema.meta_validate(invalid_schema) do
  :ok -> IO.puts("Schema is valid!")
  {:error, errors} -> 
    formatted = ExJsonschema.format_errors(errors, :human)
    IO.puts("Schema validation failed:\n#{formatted}")
end

# Validation with exception on error
ExJsonschema.meta_validate!(schema)
#=> :ok
```

## Draft Support

Meta-validation automatically detects the JSON Schema draft version from the `$schema` property:

```elixir
draft4_schema = ~s({
  "$schema": "http://json-schema.org/draft-04/schema#",
  "type": "object",
  "properties": {"name": {"type": "string"}}
})

ExJsonschema.meta_valid?(draft4_schema)
```

If no `$schema` is specified, validation defaults to the latest supported draft.

## Error Handling

Meta-validation errors use the same format as regular validation errors:

```elixir
{:error, errors} = ExJsonschema.meta_validate(invalid_schema)

# Use with error formatting
ExJsonschema.format_errors(errors, :human, color: true)
ExJsonschema.format_errors(errors, :json, pretty: true)

# Use with error analysis
analysis = ExJsonschema.analyze_errors(errors)
```

## External References

Meta-validation uses `external_schemas: :ignore` internally, so schemas with
external `$ref` URIs will never trigger network requests or deadlock. Unknown
refs are treated as permissive empty schemas during meta-validation.

## Integration

Meta-validation integrates seamlessly with your validation workflow. Since
`meta_validate` uses the same compile path as `ExJsonschema.compile`, you can
combine schema validation and compilation in a single step:

```elixir
def validate_data_with_schema_check(schema_json, data_json) do
  # compile/1 already validates the schema — if it compiles, it's valid
  case ExJsonschema.compile(schema_json) do
    {:ok, validator} ->
      ExJsonschema.validate(validator, data_json)

    {:error, compilation_error} ->
      {:error, {:invalid_schema, compilation_error}}
  end
end
```

If you need an explicit meta-validation step (e.g. for user-uploaded schemas
before storing them), use `meta_validate`:

```elixir
def validate_data_with_schema_check(schema_json, data_json) do
  case ExJsonschema.meta_validate(schema_json) do
    :ok ->
      {:ok, validator} = ExJsonschema.compile(schema_json)
      ExJsonschema.validate(validator, data_json)

    {:error, meta_errors} ->
      {:error, {:invalid_schema, meta_errors}}
  end
end
```

## Best Practices

1. **Always validate schemas** before using them in production
2. **Check during development** - add meta-validation to your test suite
3. **Handle different error types** - distinguish between schema and data validation errors
4. **Use appropriate output formats** - human for development, JSON for APIs