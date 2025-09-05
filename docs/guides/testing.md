# Testing Guide

This guide covers best practices for testing applications that use ExJsonschema, including how to handle caching in tests.

## Basic Testing Approach

For most tests, you don't need any special setup. ExJsonschema works out of the box:

```elixir
defmodule MyAppTest do
  use ExUnit.Case, async: true
  
  test "validates user data" do
    schema = ~s({
      "type": "object",
      "properties": {
        "name": {"type": "string"},
        "age": {"type": "integer", "minimum": 0}
      },
      "required": ["name"]
    })
    
    {:ok, compiled} = ExJsonschema.compile(schema)
    
    # Test valid data
    assert :ok = ExJsonschema.validate(compiled, ~s({"name": "John", "age": 25}))
    
    # Test invalid data
    assert {:error, _errors} = ExJsonschema.validate(compiled, ~s({"age": 25}))
  end
end
```


## Recommended: Disable Caching in Tests

For the most robust testing experience, we recommend disabling caching entirely in your test environment:

```elixir
# config/test.exs
config :ex_jsonschema, cache: ExJsonschema.Cache.Noop
```

This approach:
- ✅ **Eliminates cache-related test flakiness**
- ✅ **Ensures each test gets fresh compilation**
- ✅ **Works with all test scenarios (async, spawns, etc.)**
- ✅ **No special test setup required**
- ✅ **Performance impact is minimal in tests**

## Testing Cache Behavior (When Needed)

If you're specifically testing caching behavior or have cache-dependent logic, use the test cache:

### Async Tests (Recommended)

```elixir
defmodule MyCacheTest do
  use ExUnit.Case, async: true
  
  setup do
    test_cache = start_supervised!({Agent, fn -> %{} end})
    cleanup = ExJsonschema.Cache.Test.setup_process_mode(test_cache)
    on_exit(cleanup)
    :ok
  end
  
  test "schema compilation uses cache" do
    schema = ~s({"$id": "http://example.com/test.json", "type": "string"})
    
    # First compilation
    {:ok, compiled1} = ExJsonschema.compile(schema)
    
    # Second compilation - should return same reference (cached)
    {:ok, compiled2} = ExJsonschema.compile(schema)
    assert compiled1 == compiled2
    
    # Verify it's in cache
    assert {:ok, _} = ExJsonschema.Cache.Test.get("http://example.com/test.json")
  end
end
```

### Non-Async Tests (For Spawns/Tasks)

```elixir
defmodule MyIntegrationTest do
  use ExUnit.Case, async: false
  
  setup do
    test_cache = start_supervised!({Agent, fn -> %{} end})
    cleanup = ExJsonschema.Cache.Test.setup_global_mode(test_cache)
    on_exit(cleanup)
    :ok
  end
  
  test "cache works across spawned processes" do
    schema = ~s({"$id": "http://example.com/spawn-test.json", "type": "number"})
    
    # Compile in main process
    {:ok, _compiled} = ExJsonschema.compile(schema)
    
    # Use in spawned task - should hit cache
    task = Task.async(fn ->
      ExJsonschema.compile(schema)
    end)
    
    {:ok, cached_compiled} = Task.await(task)
    assert is_reference(cached_compiled)
  end
end
```

## Testing with Custom Cache Implementations

If you're testing a custom cache implementation:

```elixir
defmodule MyCustomCacheTest do
  use ExUnit.Case, async: false
  
  setup do
    # Start your custom cache
    cache_pid = start_supervised!({MyApp.CustomCache, []})
    
    # Configure ExJsonschema to use it
    original_cache = Application.get_env(:ex_jsonschema, :cache)
    Application.put_env(:ex_jsonschema, :cache, MyApp.CustomCache)
    
    on_exit(fn ->
      case original_cache do
        nil -> Application.delete_env(:ex_jsonschema, :cache)
        cache -> Application.put_env(:ex_jsonschema, :cache, cache)
      end
    end)
    
    %{cache_pid: cache_pid}
  end
  
  test "custom cache works correctly", %{cache_pid: cache_pid} do
    # Test your cache implementation
    schema = ~s({"$id": "http://example.com/custom.json", "type": "boolean"})
    {:ok, _compiled} = ExJsonschema.compile(schema)
    
    # Verify your cache received the data
    assert MyApp.CustomCache.has_key?(cache_pid, "http://example.com/custom.json")
  end
end
```

## Performance Testing

For performance tests, you may want to use a real cache to measure realistic performance:

```elixir
defmodule MyPerformanceTest do
  use ExUnit.Case, async: false
  
  @tag :performance
  test "schema compilation performance with cache" do
    # Use a real cache for performance testing
    Application.put_env(:ex_jsonschema, :cache, MyApp.EtsCache)
    
    schema = ~s({"$id": "http://example.com/perf.json", "type": "string"})
    
    # Time first compilation (cache miss)
    {time1, {:ok, _}} = :timer.tc(fn -> ExJsonschema.compile(schema) end)
    
    # Time second compilation (cache hit)
    {time2, {:ok, _}} = :timer.tc(fn -> ExJsonschema.compile(schema) end)
    
    # Cache hit should be significantly faster
    assert time2 < time1 / 2
  end
end
```

## Common Patterns

### Schema Factories

```elixir
defmodule SchemaFactory do
  def user_schema do
    ~s({
      "type": "object",
      "properties": {
        "id": {"type": "string"},
        "name": {"type": "string", "minLength": 1},
        "email": {"type": "string", "format": "email"},
        "age": {"type": "integer", "minimum": 0, "maximum": 120}
      },
      "required": ["id", "name", "email"]
    })
  end
  
  def compiled_user_schema do
    {:ok, compiled} = ExJsonschema.compile(user_schema())
    compiled
  end
end

# In tests
test "validates user data" do
  compiled = SchemaFactory.compiled_user_schema()
  assert :ok = ExJsonschema.validate(compiled, valid_user_json())
end
```

### Test Helpers

```elixir
defmodule MyApp.TestHelpers do
  def assert_valid_json(schema, json) do
    {:ok, compiled} = ExJsonschema.compile(schema)
    assert :ok = ExJsonschema.validate(compiled, json)
  end
  
  def assert_invalid_json(schema, json) do
    {:ok, compiled} = ExJsonschema.compile(schema)
    assert {:error, _errors} = ExJsonschema.validate(compiled, json)
  end
end

# In tests
import MyApp.TestHelpers

test "user validation" do
  schema = SchemaFactory.user_schema()
  assert_valid_json(schema, ~s({"id": "1", "name": "John", "email": "john@example.com"}))
  assert_invalid_json(schema, ~s({"name": "John"}))  # Missing required fields
end
```

## Summary

- **Default**: Use `ExJsonschema.Cache.Noop` in test config for robust testing
- **Cache Testing**: Use `ExJsonschema.Cache.Test` only when testing cache-specific behavior  
- **Async Tests**: Use `setup_process_mode/1` for isolated per-process caches
- **Non-Async Tests**: Use `setup_global_mode/1` when you need spawns/tasks
- **Custom Caches**: Temporarily configure your cache implementation for testing
- **Performance**: Use real caches for performance testing scenarios

This approach ensures reliable, fast tests while giving you the flexibility to test caching behavior when needed.