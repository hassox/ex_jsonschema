# ExJsonschema

**Fast, safe JSON Schema validation for Elixir**

ExJsonschema validates JSON against schemas using a battle-tested Rust engine. It's designed to be simple to use while providing the performance and reliability you need for production applications.

## Why ExJsonschema?

- **Zero Setup** - Add to your deps, it just works (no Rust toolchain needed)
- **Blazing Fast** - Rust-powered validation that scales with your traffic
- **Battle-Tested** - Built on the proven [`jsonschema`](https://crates.io/crates/jsonschema) Rust crate
- **Great Errors** - Clear, actionable validation error messages
- **Spec Compliant** - Supports JSON Schema draft-07, 2019-09, and 2020-12

## Installation

```elixir
def deps do
  [{:ex_jsonschema, "~> 0.1.1"}]
end
```

That's it! No Rust toolchain needed.

## Quick Start

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

# Compile once, validate many times
{:ok, validator} = ExJsonschema.compile(schema)

# Validate your data
:ok = ExJsonschema.validate(validator, ~s({"name": "Alice", "age": 30}))

# Get helpful errors
{:error, errors} = ExJsonschema.validate(validator, ~s({"age": -5}))
# => [%{message: "\"name\" is a required property", instance_path: ""}]
```

**That's it!** Compile your schema once, then validate as much data as you need.

## External Schema Resolution

Schemas that use `$ref` to reference external URLs are fully supported. By default, external refs are silently ignored (no network calls from inside the NIF). You control resolution in Elixir:

```elixir
# Default: ignore unknown $refs (permissive, no network I/O)
{:ok, compiled} = ExJsonschema.compile(schema)

# Pre-resolved map: you fetch the schemas however you want
{:ok, compiled} = ExJsonschema.compile(schema,
  external_schemas: %{
    "https://example.com/address.json" => ~s({"type": "object", ...})
  }
)

# Behaviour-based resolver: handles transitive refs automatically
{:ok, compiled} = ExJsonschema.compile(schema, ref_resolver: MyApp.SchemaResolver)

# Inspect what refs a schema needs
{:ok, refs} = ExJsonschema.extract_refs(schema)
#=> ["https://example.com/address.json", "https://example.com/person.json"]
```

Implement the `ExJsonschema.RefResolver` behaviour to resolve refs from HTTP, a database, the filesystem, or anything else:

```elixir
defmodule MyApp.SchemaResolver do
  @behaviour ExJsonschema.RefResolver

  @impl true
  def resolve(uris) do
    resolved = Map.new(uris, fn uri ->
      {:ok, %{body: body}} = Req.get(uri)
      {uri, body}
    end)
    {:ok, resolved}
  end
end
```

## More Features

ExJsonschema includes everything you need for production use:

- **External Ref Resolution** - Behaviour-based resolver, pre-resolved maps, or ignore mode
- **Performance Profiles** - `:strict`, `:lenient`, and `:performance` presets
- **Flexible Output** - Choose between `:basic`, `:detailed`, and `:verbose` error formats
- **Schema Caching** - Automatic caching for schemas with `$id` fields
- **Stream Processing** - Works great with Elixir's `Stream` module
- **Format Validation** - Email, URI, date-time, and more built-in formats

```elixir
# Performance tuned for your use case
opts = ExJsonschema.Options.new(:performance)
ExJsonschema.validate(validator, data, opts)

# Just need a boolean?
ExJsonschema.valid?(validator, data)
```

## Documentation

For detailed usage, check out the guides:

- **[Getting Started](https://hexdocs.pm/ex_jsonschema/getting_started.html)** - Learn the basics with practical examples
- **[Advanced Features](https://hexdocs.pm/ex_jsonschema/advanced_features.html)** - Profiles, caching, and integration patterns
- **[Streaming Validation](https://hexdocs.pm/ex_jsonschema/streaming_validation.html)** - Process large datasets efficiently
- **[Performance & Production](https://hexdocs.pm/ex_jsonschema/performance_production.html)** - Optimization and deployment

**[Full API Documentation](https://hexdocs.pm/ex_jsonschema)**

## Benchmarking

Test performance on your system:

```bash
mix benchmark
```

## License

MIT - see [LICENSE](LICENSE) file for details.

