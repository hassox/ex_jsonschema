defmodule ExJsonschema.CacheBehaviorTest do
  use ExUnit.Case, async: true

  setup do
    # Set up test cache for each test using the helper function
    test_cache = start_supervised!({Agent, fn -> %{} end})
    cleanup = ExJsonschema.Cache.Test.setup_process_mode(test_cache)
    on_exit(cleanup)
    :ok
  end

  describe "cache integration with schema compilation" do
    test "caches and reuses compiled schemas with $id" do
      schema_with_id = ~s({
        "$id": "http://example.com/person.json",
        "$schema": "http://json-schema.org/draft-07/schema#",
        "type": "object",
        "properties": {
          "name": {"type": "string"},
          "age": {"type": "integer", "minimum": 0}
        },
        "required": ["name"]
      })

      # First compilation - should cache the result
      {:ok, validator1} = ExJsonschema.compile(schema_with_id)

      # Verify it's cached by checking if we can get it directly
      assert {:ok, _cached} = ExJsonschema.Cache.Test.get("http://example.com/person.json")

      # Second compilation with same schema - should reuse cached result  
      {:ok, validator2} = ExJsonschema.compile(schema_with_id)

      # Both validators should be the same reference (cached)
      assert validator1 == validator2

      # Both validators should work for validation
      valid_data = ~s({"name": "John", "age": 30})
      assert :ok = ExJsonschema.validate(validator1, valid_data)
      assert :ok = ExJsonschema.validate(validator2, valid_data)

      invalid_data = ~s({"age": 30})
      assert {:error, _} = ExJsonschema.validate(validator1, invalid_data)
      assert {:error, _} = ExJsonschema.validate(validator2, invalid_data)
    end

    test "different schema IDs create separate cache entries" do
      schema1 = ~s({"$id": "http://example.com/schema1.json", "type": "string"})
      schema2 = ~s({"$id": "http://example.com/schema2.json", "type": "number"})

      # Compile both schemas
      {:ok, validator1} = ExJsonschema.compile(schema1)
      {:ok, _validator2} = ExJsonschema.compile(schema2)

      # Both should be cached
      assert {:ok, _} = ExJsonschema.Cache.Test.get("http://example.com/schema1.json")
      assert {:ok, _} = ExJsonschema.Cache.Test.get("http://example.com/schema2.json")

      # Recompile first schema - should reuse cache
      {:ok, validator1_cached} = ExJsonschema.compile(schema1)
      assert validator1 == validator1_cached
    end

    test "schemas without IDs bypass cache" do
      schema_no_id = ~s({"type": "object", "properties": {"name": {"type": "string"}}})

      # Compile schema multiple times - should never use cache
      {:ok, validator1} = ExJsonschema.compile(schema_no_id)
      {:ok, validator2} = ExJsonschema.compile(schema_no_id)
      {:ok, validator3} = ExJsonschema.compile(schema_no_id)

      # Each should be a different reference since they're not cached
      assert validator1 != validator2
      assert validator2 != validator3
    end

    test "uses $schema as fallback ID when no $id present" do
      schema_with_schema = ~s({
        "$schema": "http://json-schema.org/draft-07/schema#",
        "type": "string",
        "minLength": 1
      })

      # First compilation
      {:ok, validator1} = ExJsonschema.compile(schema_with_schema)

      # Should be cached using $schema as key
      assert {:ok, _} = ExJsonschema.Cache.Test.get("http://json-schema.org/draft-07/schema#")

      # Second compilation - should hit cache using $schema as key
      {:ok, validator2} = ExJsonschema.compile(schema_with_schema)
      assert validator1 == validator2
    end

    test "cache operations work correctly" do
      # Compile a schema to get a proper reference for testing
      schema = ~s({"$id": "http://example.com/cache-test.json", "type": "string"})
      {:ok, compiled_ref} = ExJsonschema.compile(schema)

      # Test direct cache operations
      assert :ok = ExJsonschema.Cache.Test.put("test-key", compiled_ref)
      assert {:ok, ^compiled_ref} = ExJsonschema.Cache.Test.get("test-key")

      # Delete specific key
      assert :ok = ExJsonschema.Cache.Test.delete("test-key")
      assert {:error, :not_found} = ExJsonschema.Cache.Test.get("test-key")

      # Clear all
      ExJsonschema.Cache.Test.put("key1", "value1")
      ExJsonschema.Cache.Test.put("key2", "value2")
      assert :ok = ExJsonschema.Cache.Test.clear()
      assert {:error, :not_found} = ExJsonschema.Cache.Test.get("key1")
      assert {:error, :not_found} = ExJsonschema.Cache.Test.get("key2")
    end
  end

  describe "cache configuration" do
    test "NoopCache disables caching" do
      # Temporarily switch to NoopCache
      Application.put_env(:ex_jsonschema, :cache, ExJsonschema.Cache.Noop)

      schema = ~s({"$id": "http://example.com/noop-test.json", "type": "string"})

      # Compile multiple times - should get different references each time  
      {:ok, validator1} = ExJsonschema.compile(schema)
      {:ok, validator2} = ExJsonschema.compile(schema)

      # With NoopCache, each compilation creates a new validator
      assert validator1 != validator2
    end
  end
end
