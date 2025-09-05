# Performance & Production

This guide covers the performance characteristics of ExJsonschema.

## Performance Characteristics

ExJsonschema has two main operations:

1. **Schema Compilation**: Takes milliseconds, should be done once
2. **Validation**: Takes microseconds, scales with data size

### Performance Profiles

The library provides three built-in performance profiles:

- `:performance` - Fastest validation, minimal error information
- `:lenient` - Balanced speed and error detail  
- `:strict` - Maximum error detail and format validation

```elixir
perf_opts = ExJsonschema.Options.new(:performance)
ExJsonschema.validate(validator, data, perf_opts)
```

### Functions

- `validate/2` - Returns detailed error information
- `valid?/2` - Returns boolean only, faster for simple checks

## Caching

ExJsonschema automatically caches compiled schemas that have an `$id` field:

```elixir
schema_with_id = ~s({
  "$id": "http://myapp.com/schemas/user.json",
  "type": "object",
  "properties": {"name": {"type": "string"}}
})

# First call compiles and caches
{:ok, validator1} = ExJsonschema.compile(schema_with_id)

# Second call returns cached version
{:ok, validator2} = ExJsonschema.compile(schema_with_id)
# validator1 == validator2
```

The default cache keeps schemas in memory indefinitely. You can implement your own cache by creating a module that implements the `ExJsonschema.Cache` behaviour:

```elixir
# config/config.exs
config :ex_jsonschema, cache: MyApp.SchemaCache
```

For tests, disable caching:

```elixir
# config/test.exs
config :ex_jsonschema, cache: ExJsonschema.Cache.Noop
```

## Benchmarking

The library includes a benchmark tool:

```bash
mix benchmark
```

This measures validation performance with different profiles and data sizes.