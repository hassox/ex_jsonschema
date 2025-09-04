# Surface 4: External References & Resolution

## Current State
- No external reference support
- No remote schema fetching
- Local-only schema compilation

## Target Capabilities (from Rust crate)
- External reference resolution (`$ref` to remote schemas)
- Custom retrievers for different protocols
- Base URI resolution
- Reference caching and management
- Blocking and non-blocking resolution
- Custom resource loading strategies

## Proposed Elixir API Design

### Reference Resolution Behaviors
```elixir
defmodule ExJsonschema.Retriever do
  @type uri :: String.t()
  @type schema_content :: String.t()
  @type retriever_opts :: keyword()
  
  @callback retrieve(uri(), retriever_opts()) :: {:ok, schema_content()} | {:error, term()}
  @callback retrieve_async(uri(), retriever_opts()) :: Task.t()
  @optional_callbacks [retrieve_async: 2]
end

defmodule ExJsonschema.ReferenceCache do  
  @type cache_key :: String.t()
  @type schema_content :: String.t()
  @type cache_opts :: keyword()
  
  @callback get(cache_key(), cache_opts()) :: {:ok, schema_content()} | {:error, :not_found}
  @callback put(cache_key(), schema_content(), cache_opts()) :: :ok | {:error, term()}
  @callback delete(cache_key(), cache_opts()) :: :ok
  @callback clear(cache_opts()) :: :ok
  @optional_callbacks [clear: 1]
end
```

### Reference Retriever Types (Behaviors to Implement)
```elixir
# Users would implement these behaviors:

# ExJsonschema.Retriever.HTTP - for fetching remote schemas
# ExJsonschema.Retriever.File - for local file system schemas  
# ExJsonschema.Retriever.Memory - for in-memory schema maps
# ExJsonschema.Retriever.S3 - for AWS S3 schema storage
# ExJsonschema.Retriever.Database - for database-stored schemas

# Configuration specifies which retriever to use:
config :ex_jsonschema,
  retriever: MyApp.SchemaRetriever,
  reference_cache: MyApp.ReferenceCache
```
```

### Enhanced Compilation with References
```elixir
# Basic external reference support
{:ok, validator} = ExJsonschema.compile(schema, 
  resolve_external_refs: true,
  retriever: ExJsonschema.Retrievers.HTTP
)

# With base URI for relative references  
{:ok, validator} = ExJsonschema.compile(schema,
  resolve_external_refs: true,
  base_uri: "https://schemas.example.com/v1/",
  retriever: ExJsonschema.Retrievers.HTTP
)

# With custom cache
{:ok, cache} = ExJsonschema.Cache.start_link()
{:ok, validator} = ExJsonschema.compile(schema,
  resolve_external_refs: true,
  retriever: ExJsonschema.Retrievers.HTTP,
  cache: cache
)

# With timeout and retry configuration
{:ok, validator} = ExJsonschema.compile(schema,
  resolve_external_refs: true,
  retriever: {ExJsonschema.Retrievers.HTTP, [timeout: 5000, retries: 3]}
)
```

### Schema Registry Pattern
```elixir
defmodule MyApp.SchemaRegistry do
  use ExJsonschema.Registry
  
  def start_link(opts) do
    ExJsonschema.Registry.start_link(__MODULE__, [
      base_uri: "https://schemas.myapp.com/",
      retriever: ExJsonschema.Retrievers.HTTP,
      cache_ttl: :timer.hours(1)
    ] ++ opts)
  end
  
  def get_validator(schema_id) do
    ExJsonschema.Registry.get_validator(__MODULE__, schema_id)
  end
  
  def preload_schemas(schema_urls) do
    ExJsonschema.Registry.preload(__MODULE__, schema_urls)
  end
end

# Usage
{:ok, _} = MyApp.SchemaRegistry.start_link()
{:ok, validator} = MyApp.SchemaRegistry.get_validator("user-profile.json")
```

### Async Reference Resolution
```elixir
# Non-blocking compilation (requires resolve-async feature)
{:ok, validator} = ExJsonschema.compile_async(schema,
  resolve_external_refs: true,
  retriever: ExJsonschema.Retrievers.HTTP
)
```

## Implementation Plan

### Phase 1: Basic Reference Resolution
1. Implement HTTP retriever with Tesla/Finch
2. Implement file system retriever  
3. Add reference resolution to Rust NIF
4. Create basic caching mechanism

### Phase 2: Advanced Retrievers
1. Implement memory retriever for testing
2. Add retriever configuration and options
3. Implement retry and timeout logic
4. Add custom retriever support

### Phase 3: Schema Registry
1. Design registry architecture
2. Implement schema caching and lifecycle
3. Add preloading and warmup capabilities
4. Implement TTL and invalidation

### Phase 4: Async Support (if feasible)
1. Research async compilation in Rustler
2. Implement non-blocking reference resolution
3. Add async validation support
4. Handle async error cases

## Rust Integration Points
- Use Rust `jsonschema::Retrieve` trait
- Implement custom retrievers in Elixir, call from Rust
- Use `jsonschema::Registry` for schema management
- Handle `jsonschema::ReferencingError` properly

## API Examples

### API Gateway Schema Resolution
```elixir
# Configure retriever with authentication
http_retriever = {ExJsonschema.Retrievers.HTTP, [
  headers: [{"Authorization", "Bearer #{token}"}],
  timeout: 10_000
]}

{:ok, validator} = ExJsonschema.compile(schema,
  base_uri: "https://internal-schemas.company.com/api/v1/",
  resolve_external_refs: true,
  retriever: http_retriever
)
```

### Development with Local Schemas
```elixir
# Use file retriever for development
{:ok, validator} = ExJsonschema.compile(schema,
  base_uri: "file:///app/schemas/",
  resolve_external_refs: true, 
  retriever: ExJsonschema.Retrievers.File
)
```

### Testing with Mock Schemas
```elixir
# In-memory retriever for testing
mock_schemas = %{
  "https://example.com/user.json" => File.read!("test/fixtures/user.json"),
  "https://example.com/address.json" => File.read!("test/fixtures/address.json")
}

memory_retriever = ExJsonschema.Retrievers.Memory.new(mock_schemas)

{:ok, validator} = ExJsonschema.compile(schema,
  resolve_external_refs: true,
  retriever: memory_retriever
)
```

### Production Schema Registry
```elixir
defmodule MyApp.Application do
  def start(_type, _args) do
    children = [
      MyApp.SchemaRegistry,
      # ... other children
    ]
    
    # Preload commonly used schemas
    Task.start(fn ->
      MyApp.SchemaRegistry.preload_schemas([
        "user-profile.json",
        "api-response.json", 
        "webhook-payload.json"
      ])
    end)
    
    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
```

## Error Handling

### Reference Resolution Errors
```elixir
case ExJsonschema.compile(schema, resolve_external_refs: true) do
  {:ok, validator} -> 
    validator
    
  {:error, %ExJsonschema.CompilationError{type: :reference_error} = error} ->
    Logger.error("Failed to resolve reference: #{error.details}")
    
  {:error, %ExJsonschema.CompilationError{type: :network_error} = error} ->
    Logger.warning("Network error resolving schema: #{error.details}")
end
```

## Performance Considerations
- Connection pooling for HTTP retrievers
- Intelligent caching with TTL
- Lazy loading vs preloading strategies
- Background refresh of cached schemas
- Circuit breaker pattern for unreliable references

## Security Considerations
- URL allowlisting for external references
- Authentication for private schema registries
- Timeout limits to prevent DoS
- Schema size limits
- Validation of retrieved schema content

## Backward Compatibility
- External reference resolution is opt-in
- Default behavior remains unchanged (no external refs)
- Clear error messages when references can't be resolved
- Graceful degradation when retrieval fails