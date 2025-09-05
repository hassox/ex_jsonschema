# Caching Guide

ExJsonschema provides a flexible caching system that allows you to cache compiled JSON schemas for improved performance. This guide covers everything you need to know about caching.

## Quick Start

By default, ExJsonschema uses `ExJsonschema.Cache.Noop` which disables caching:

```elixir
# Default behavior - no caching
{:ok, compiled} = ExJsonschema.compile(schema)
```

To enable caching, configure a cache module:

```elixir
# config/config.exs
config :ex_jsonschema, cache: MyApp.SchemaCache
```

## How Caching Works

ExJsonschema caches compiled schemas using their identifier:

1. **Primary Key**: Uses the `$id` field if present
2. **Fallback Key**: Uses the `$schema` field if `$id` is missing
3. **No Caching**: Schemas without both `$id` and `$schema` are not cached

```elixir
# This schema will be cached with key "http://example.com/user.json"
schema_with_id = ~s({
  "$id": "http://example.com/user.json",
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "properties": {"name": {"type": "string"}}
})

# This schema will be cached with key "http://json-schema.org/draft-07/schema#"
schema_with_schema = ~s({
  "$schema": "http://json-schema.org/draft-07/schema#", 
  "type": "string"
})

# This schema will NOT be cached (no identifier)
schema_anonymous = ~s({"type": "number"})
```

## Built-in Cache Implementations

### NoopCache (Default)

Disables caching entirely. Best for:
- Development environments
- Testing environments  
- Applications that rarely reuse schemas

```elixir
config :ex_jsonschema, cache: ExJsonschema.Cache.Noop
```

### Test Cache

Provides isolated caching for tests. See the [Testing Guide](testing.md) for details.

```elixir
# In tests only
config :ex_jsonschema, cache: ExJsonschema.Cache.Test
```

## Creating Custom Cache Implementations

To create a custom cache, implement the `ExJsonschema.Cache` behaviour:

```elixir
defmodule MyApp.EtsCache do
  @behaviour ExJsonschema.Cache
  
  # Start your cache in your application's supervision tree
  use GenServer
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @impl ExJsonschema.Cache
  def get(key) do
    # Return {:ok, compiled_schema} or {:error, :not_found}
    case :ets.lookup(:my_schema_cache, key) do
      [{^key, compiled_schema}] -> {:ok, compiled_schema}
      [] -> {:error, :not_found}
    end
  end
  
  @impl ExJsonschema.Cache
  def put(key, compiled_schema) do
    # Store the compiled schema
    :ets.insert(:my_schema_cache, {key, compiled_schema})
    :ok
  end
  
  @impl ExJsonschema.Cache
  def delete(key) do
    :ets.delete(:my_schema_cache, key)
    :ok
  end
  
  @impl ExJsonschema.Cache
  def clear() do
    :ets.delete_all_objects(:my_schema_cache)
    :ok
  end
  
  @impl GenServer
  def init(opts) do
    :ets.new(:my_schema_cache, [:named_table, :set, :protected, read_concurrency: true])
    {:ok, opts}
  end
end
```

### Advanced ETS Cache with TTL

```elixir
defmodule MyApp.EtsCacheWithTTL do
  @behaviour ExJsonschema.Cache
  use GenServer
  
  @cleanup_interval 60_000  # 1 minute
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @impl ExJsonschema.Cache
  def get(key) do
    case :ets.lookup(:schema_cache_ttl, key) do
      [{^key, compiled_schema, expires_at}] ->
        if System.system_time(:second) > expires_at do
          :ets.delete(:schema_cache_ttl, key)
          {:error, :not_found}
        else
          {:ok, compiled_schema}
        end
      [] -> 
        {:error, :not_found}
    end
  end
  
  @impl ExJsonschema.Cache
  def put(key, compiled_schema) do
    ttl_seconds = Application.get_env(:my_app, :schema_cache_ttl, 3600)
    expires_at = System.system_time(:second) + ttl_seconds
    :ets.insert(:schema_cache_ttl, {key, compiled_schema, expires_at})
    :ok
  end
  
  @impl ExJsonschema.Cache
  def delete(key) do
    :ets.delete(:schema_cache_ttl, key)
    :ok
  end
  
  @impl ExJsonschema.Cache  
  def clear() do
    :ets.delete_all_objects(:schema_cache_ttl)
    :ok
  end
  
  @impl GenServer
  def init(opts) do
    :ets.new(:schema_cache_ttl, [:named_table, :set, :protected, read_concurrency: true])
    schedule_cleanup()
    {:ok, opts}
  end
  
  @impl GenServer
  def handle_info(:cleanup, state) do
    cleanup_expired()
    schedule_cleanup()
    {:noreply, state}
  end
  
  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @cleanup_interval)
  end
  
  defp cleanup_expired do
    now = System.system_time(:second)
    expired_pattern = {:"$1", :"$2", :"$3"}
    expired_condition = {:<, :"$3", {:const, now}}
    expired_keys = :ets.select(:schema_cache_ttl, [{expired_pattern, [expired_condition], [:"$1"]}])
    
    Enum.each(expired_keys, fn key ->
      :ets.delete(:schema_cache_ttl, key)
    end)
  end
end
```

### Integration with External Cache Libraries

#### Cachex Integration

```elixir
defmodule MyApp.CachexCache do
  @behaviour ExJsonschema.Cache
  
  @cache_name :schema_cache
  
  @impl ExJsonschema.Cache
  def get(key) do
    case Cachex.get(@cache_name, key) do
      {:ok, nil} -> {:error, :not_found}
      {:ok, compiled_schema} -> {:ok, compiled_schema}
      {:error, _} -> {:error, :not_found}
    end
  end
  
  @impl ExJsonschema.Cache
  def put(key, compiled_schema) do
    ttl = Application.get_env(:my_app, :schema_cache_ttl, :timer.hours(1))
    Cachex.put(@cache_name, key, compiled_schema, ttl: ttl)
    :ok
  end
  
  @impl ExJsonschema.Cache
  def delete(key) do
    Cachex.del(@cache_name, key)
    :ok
  end
  
  @impl ExJsonschema.Cache
  def clear() do
    Cachex.clear(@cache_name)
    :ok
  end
end

# In your application.ex
def start(_type, _args) do
  children = [
    {Cachex, name: :schema_cache, limit: 1000}
  ]
  
  opts = [strategy: :one_for_one, name: MyApp.Supervisor]
  Supervisor.start_link(children, opts)
end

# In your config
config :ex_jsonschema, cache: MyApp.CachexCache
```

#### Nebulex Integration

```elixir
# Define your Nebulex cache
defmodule MyApp.SchemaCache do
  use Nebulex.Cache,
    otp_app: :my_app,
    adapter: Nebulex.Adapters.Local
end

# Create a wrapper for ExJsonschema
defmodule MyApp.NebulexCacheWrapper do
  @behaviour ExJsonschema.Cache
  
  alias MyApp.SchemaCache
  
  @impl ExJsonschema.Cache
  def get(key) do
    case SchemaCache.get(key) do
      nil -> {:error, :not_found}
      compiled_schema -> {:ok, compiled_schema}
    end
  end
  
  @impl ExJsonschema.Cache
  def put(key, compiled_schema) do
    SchemaCache.put(key, compiled_schema)
    :ok
  end
  
  @impl ExJsonschema.Cache
  def delete(key) do
    SchemaCache.delete(key)
    :ok
  end
  
  @impl ExJsonschema.Cache
  def clear() do
    SchemaCache.flush()
    :ok
  end
end

# In your application.ex
def start(_type, _args) do
  children = [
    MyApp.SchemaCache
  ]
  
  opts = [strategy: :one_for_one, name: MyApp.Supervisor]
  Supervisor.start_link(children, opts)
end

# In your config
config :ex_jsonschema, cache: MyApp.NebulexCacheWrapper
```

## Application Setup

### Starting Your Cache

Add your cache to your application's supervision tree:

```elixir
# lib/my_app/application.ex
defmodule MyApp.Application do
  use Application
  
  def start(_type, _args) do
    children = [
      # Your cache implementation
      {MyApp.EtsCache, []},
      
      # Other supervised processes
      MyApp.Repo,
      MyAppWeb.Endpoint
    ]
    
    opts = [strategy: :one_for_one, name: MyApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

### Configuration

```elixir
# config/config.exs
config :ex_jsonschema,
  cache: MyApp.EtsCache

# config/dev.exs  
config :ex_jsonschema,
  cache: MyApp.EtsCache  # Enable caching in development

# config/test.exs
config :ex_jsonschema,
  cache: ExJsonschema.Cache.Noop  # Disable caching in tests

# config/prod.exs
config :ex_jsonschema,
  cache: MyApp.EtsCache

# Cache-specific configuration
config :my_app,
  schema_cache_ttl: 3600,  # 1 hour
  schema_cache_size: 1000  # Max 1000 entries
```

## Performance Considerations

### When to Use Caching

**✅ Good candidates for caching:**
- Applications that reuse the same schemas frequently
- High-traffic web applications validating request/response data
- Background job systems with repeated schema validation
- Applications with complex, large schemas
- Microservices with standard API schemas

**❌ Poor candidates for caching:**
- Applications that rarely reuse schemas  
- One-off scripts or migrations
- Applications with highly dynamic schemas
- Memory-constrained environments

### Cache Performance Tips

1. **Use schema identifiers**: Always include `$id` in your schemas for optimal caching

```elixir
# Good - will be cached efficiently
schema = ~s({
  "$id": "http://myapp.com/schemas/user.json",
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "properties": {"name": {"type": "string"}}
})

# Poor - won't be cached
schema = ~s({
  "type": "object", 
  "properties": {"name": {"type": "string"}}
})
```

2. **Monitor cache hit rates**: Implement metrics to track cache effectiveness

```elixir
defmodule MyApp.MetricsCache do
  @behaviour ExJsonschema.Cache
  
  @impl ExJsonschema.Cache
  def get(key) do
    result = MyApp.EtsCache.get(key)
    
    case result do
      {:ok, _} -> :telemetry.execute([:schema_cache, :hit], %{count: 1})
      {:error, :not_found} -> :telemetry.execute([:schema_cache, :miss], %{count: 1})
    end
    
    result
  end
  
  # ... other callbacks delegate to MyApp.EtsCache
end
```

3. **Set appropriate TTL**: Balance memory usage with cache effectiveness

4. **Use read_concurrency for ETS**: Enable concurrent reads for better performance

## Monitoring and Debugging

### Cache Statistics

Many cache implementations provide statistics. Here's how to add them to your cache:

```elixir
defmodule MyApp.EtsCache do
  # ... existing implementation ...
  
  def stats do
    size = :ets.info(:my_schema_cache, :size)
    memory_words = :ets.info(:my_schema_cache, :memory)
    memory_bytes = memory_words * :erlang.system_info(:wordsize)
    
    %{
      size: size,
      memory_bytes: memory_bytes,
      memory_mb: Float.round(memory_bytes / (1024 * 1024), 2)
    }
  end
end
```

### Debugging Cache Issues

```elixir
# Check if schema has cacheable identifier
schema_json = ~s({"type": "string"})
case Jason.decode(schema_json) do
  {:ok, schema_map} ->
    id = Map.get(schema_map, "$id") || Map.get(schema_map, "$schema")
    IO.inspect(id, label: "Cache key")
  {:error, _} ->
    IO.puts("Invalid JSON schema")
end

# Manually check cache contents
MyApp.EtsCache.get("http://example.com/schema.json")

# Clear cache for testing
MyApp.EtsCache.clear()
```

## Best Practices

1. **Use NoopCache in tests** for reliability and simplicity
2. **Always include `$id` in schemas** you want to cache
3. **Start cache in supervision tree** to handle failures gracefully
4. **Set appropriate TTL** to prevent memory leaks
5. **Monitor cache performance** with metrics
6. **Use environment-specific configuration** (no cache in test, cache in prod)
7. **Handle cache failures gracefully** - schema compilation should still work if cache is down

## Examples

### High-Traffic Web Application

```elixir
# Fast ETS cache for web requests
defmodule MyWeb.FastSchemaCache do
  @behaviour ExJsonschema.Cache
  use GenServer
  
  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end
  
  def init(_) do
    :ets.new(:fast_schemas, [
      :named_table, 
      :set, 
      :protected, 
      read_concurrency: true,
      write_concurrency: false
    ])
    {:ok, []}
  end
  
  @impl ExJsonschema.Cache
  def get(key) do
    case :ets.lookup(:fast_schemas, key) do
      [{^key, compiled}] -> {:ok, compiled}
      [] -> {:error, :not_found}
    end
  end
  
  @impl ExJsonschema.Cache
  def put(key, compiled) do
    :ets.insert(:fast_schemas, {key, compiled})
    :ok
  end
  
  @impl ExJsonschema.Cache
  def delete(key) do
    :ets.delete(:fast_schemas, key)
    :ok
  end
  
  @impl ExJsonschema.Cache 
  def clear() do
    :ets.delete_all_objects(:fast_schemas)
    :ok
  end
end
```

### Background Job Processing

```elixir
# Persistent cache with TTL for background jobs
defmodule MyApp.JobSchemaCache do
  @behaviour ExJsonschema.Cache
  
  # Use Cachex for automatic TTL and eviction
  @cache_name :job_schemas
  
  @impl ExJsonschema.Cache
  def get(key), do: Cachex.get(@cache_name, key) |> handle_result()
  
  @impl ExJsonschema.Cache  
  def put(key, compiled) do
    ttl = :timer.hours(24)  # Long TTL for job schemas
    Cachex.put(@cache_name, key, compiled, ttl: ttl)
    :ok
  end
  
  @impl ExJsonschema.Cache
  def delete(key), do: Cachex.del(@cache_name, key) |> handle_result()
  
  @impl ExJsonschema.Cache
  def clear(), do: Cachex.clear(@cache_name) |> handle_result()
  
  defp handle_result({:ok, nil}), do: {:error, :not_found}
  defp handle_result({:ok, value}), do: {:ok, value}
  defp handle_result({:ok}), do: :ok
  defp handle_result(_), do: {:error, :cache_error}
end
```

This caching system provides the flexibility to choose the right caching strategy for your application while maintaining a clean, consistent API.