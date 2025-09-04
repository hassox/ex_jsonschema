# ExJsonschema Testing Strategy

## 🎯 Overview

A comprehensive testing strategy for the ExJsonschema upgrade that ensures reliability, performance, and correctness across all 8 functional surfaces. Our goal is **>95% test coverage** with multiple types of testing at every level.

---

## 🧪 Testing Philosophy

### Test-Driven Development
- **Write tests first** for every new feature
- **Behavior-driven testing** - test the contracts, not the implementation
- **Fail fast** - tests should catch issues immediately
- **Comprehensive coverage** - unit, integration, property, and performance tests

### Testing Pyramid
```
    🔺 E2E Tests (Few)
   🔺🔺 Integration Tests (Some)  
  🔺🔺🔺 Unit Tests (Many)
 🔺🔺🔺🔺 Property Tests (Comprehensive)
```

---

## 🏗️ Test Categories

### 1. Unit Tests
**Target**: Individual functions and modules  
**Coverage**: >95% line coverage  
**Location**: `test/unit/`

### 2. Integration Tests  
**Target**: Behavior contracts and surface interactions  
**Coverage**: All behavior implementations  
**Location**: `test/integration/`

### 3. Property Tests (StreamData)
**Target**: Correctness across input variations  
**Coverage**: All validation functions  
**Location**: `test/property/`

### 4. Performance Tests  
**Target**: Speed, memory usage, throughput  
**Coverage**: All performance claims  
**Location**: `test/performance/`

### 5. Compliance Tests
**Target**: JSON Schema specification compliance  
**Coverage**: All supported drafts and keywords  
**Location**: `test/compliance/`

### 6. Example Tests
**Target**: Documentation examples work correctly  
**Coverage**: All code examples in docs  
**Location**: `test/examples/`

---

## 📋 Testing Requirements by Surface

### Surface 1: Core Validation Engine

#### Unit Tests
```elixir
defmodule ExJsonschema.CoreTest do
  use ExUnit.Case
  use ExUnitProperties

  describe "compile/2" do
    test "compiles valid schema successfully" do
      schema = ~s({"type": "string"})
      assert {:ok, validator} = ExJsonschema.compile(schema)
      assert is_reference(validator)
    end

    test "rejects invalid schema with clear error" do
      schema = ~s({"type": "invalid_type"})
      assert {:error, %ExJsonschema.CompilationError{}} = ExJsonschema.compile(schema)
    end

    test "handles draft selection" do
      schema = ~s({"$schema": "https://json-schema.org/draft/2020-12/schema", "type": "string"})
      assert {:ok, validator} = ExJsonschema.compile(schema, draft: :auto)
    end
  end

  describe "validate/2" do
    setup do
      {:ok, validator} = ExJsonschema.compile(~s({"type": "string", "minLength": 2}))
      %{validator: validator}
    end

    test "validates correct instance", %{validator: validator} do
      assert :ok = ExJsonschema.validate(validator, ~s("hello"))
    end

    test "rejects invalid instance with detailed errors", %{validator: validator} do
      assert {:error, [error]} = ExJsonschema.validate(validator, ~s("a"))
      assert error.keyword == "minLength"
      assert error.instance_path == ""
      assert error.message =~ "minimum length"
    end
  end

  describe "valid?/2" do
    test "returns boolean for validity check" do
      {:ok, validator} = ExJsonschema.compile(~s({"type": "number"}))
      assert ExJsonschema.valid?(validator, ~s(42)) == true
      assert ExJsonschema.valid?(validator, ~s("string")) == false
    end
  end
end
```

#### Property Tests
```elixir
defmodule ExJsonschema.CorePropertyTest do
  use ExUnit.Case
  use ExUnitProperties

  property "any valid JSON Schema compiles without error" do
    check all schema <- valid_json_schema() do
      case ExJsonschema.compile(schema) do
        {:ok, _validator} -> true
        {:error, _error} -> false
      end
    end
  end

  property "validation is consistent between valid? and validate" do
    check all schema <- simple_json_schema(),
              instance <- json_instance() do
      {:ok, validator} = ExJsonschema.compile(schema)
      
      is_valid = ExJsonschema.valid?(validator, instance)
      validation_result = ExJsonschema.validate(validator, instance)
      
      case validation_result do
        :ok -> assert is_valid == true
        {:error, _} -> assert is_valid == false
      end
    end
  end
end
```

### Surface 2: Configuration & Options

#### Unit Tests
```elixir
defmodule ExJsonschema.OptionsTest do
  use ExUnit.Case

  describe "Options struct" do
    test "creates default options" do
      opts = ExJsonschema.Options.new()
      assert opts.draft == :auto
      assert opts.validate_formats == false
    end

    test "creates draft-specific options" do
      opts = ExJsonschema.Options.draft7(validate_formats: true)
      assert opts.draft == :draft7
      assert opts.validate_formats == true
    end

    test "validates option combinations" do
      assert_raise ArgumentError, fn ->
        ExJsonschema.Options.new(draft: :invalid_draft)
      end
    end
  end

  describe "configuration profiles" do
    test "strict profile enables comprehensive validation" do
      opts = ExJsonschema.Profiles.strict()
      assert opts.validate_formats == true
      assert opts.ignore_unknown_formats == false
      assert opts.resolve_external_refs == true
    end

    test "performance profile optimizes for speed" do
      opts = ExJsonschema.Profiles.performance()
      assert opts.regex_engine == :regex
      assert opts.collect_annotations == false
    end
  end
end
```

### Surface 3: Schema Drafts & Meta-validation

#### Compliance Tests
```elixir
defmodule ExJsonschema.DraftComplianceTest do
  use ExUnit.Case

  # Test against official JSON Schema test suites
  @official_test_suites [
    "draft4/",
    "draft6/", 
    "draft7/",
    "draft2019-09/",
    "draft2020-12/"
  ]

  for draft_dir <- @official_test_suites do
    @draft_dir draft_dir
    
    test_files = Path.wildcard("test/fixtures/json_schema_test_suite/tests/#{draft_dir}*.json")
    
    for test_file <- test_files do
      @test_file test_file
      test_name = Path.basename(test_file, ".json")
      
      test "#{@draft_dir}#{test_name} compliance" do
        run_official_test_suite(@test_file)
      end
    end
  end

  defp run_official_test_suite(test_file) do
    test_file
    |> File.read!()
    |> Jason.decode!()
    |> Enum.each(&run_test_case/1)
  end
end
```

#### Meta-validation Tests
```elixir
defmodule ExJsonschema.MetaValidationTest do
  use ExUnit.Case

  describe "schema meta-validation" do
    test "validates valid schemas" do
      valid_schema = ~s({
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "type": "object",
        "properties": {
          "name": {"type": "string"}
        }
      })
      
      assert :ok = ExJsonschema.Meta.validate_schema(valid_schema)
    end

    test "rejects invalid schemas with specific errors" do
      invalid_schema = ~s({
        "$schema": "https://json-schema.org/draft/2020-12/schema", 
        "type": "invalid_type"
      })
      
      assert {:error, [error]} = ExJsonschema.Meta.validate_schema(invalid_schema)
      assert error.keyword == "enum"
      assert error.message =~ "not valid under any of the schemas"
    end

    test "detects draft version correctly" do
      schema_with_draft = ~s({"$schema": "https://json-schema.org/draft/2019-09/schema"})
      assert {:ok, :draft201909} = ExJsonschema.Draft.detect(schema_with_draft)
      
      schema_without_draft = ~s({"type": "string"})
      assert {:ok, :auto} = ExJsonschema.Draft.detect(schema_without_draft)
    end
  end
end
```

### Surface 4: External References & Resolution

#### Behavior Tests
```elixir
defmodule ExJsonschema.RetrieverBehaviorTest do
  use ExUnit.Case

  defmodule MockRetriever do
    @behaviour ExJsonschema.Retriever
    
    @impl true
    def retrieve(uri, _opts) do
      case uri do
        "https://example.com/user.json" -> 
          {:ok, ~s({"type": "object", "properties": {"name": {"type": "string"}}})}
        "https://example.com/notfound.json" ->
          {:error, :not_found}
        _ ->
          {:error, :timeout}
      end
    end
  end

  describe "retriever behavior" do
    test "successful retrieval" do
      result = MockRetriever.retrieve("https://example.com/user.json", [])
      assert {:ok, schema_json} = result
      assert String.contains?(schema_json, "type")
    end

    test "handles not found" do
      result = MockRetriever.retrieve("https://example.com/notfound.json", [])
      assert {:error, :not_found} = result
    end

    test "handles network errors" do
      result = MockRetriever.retrieve("https://invalid.com/schema.json", [])
      assert {:error, :timeout} = result
    end
  end

  describe "reference resolution integration" do
    test "resolves external references successfully" do
      schema = ~s({
        "type": "object",
        "properties": {
          "user": {"$ref": "https://example.com/user.json"}
        }
      })
      
      {:ok, validator} = ExJsonschema.compile(schema, 
        resolve_external_refs: true,
        retriever: MockRetriever
      )
      
      instance = ~s({"user": {"name": "Alice"}})
      assert :ok = ExJsonschema.validate(validator, instance)
    end
  end
end
```

### Surface 5: Custom Validation

#### Custom Keyword Tests
```elixir
defmodule ExJsonschema.CustomValidationTest do
  use ExUnit.Case

  defmodule TestKeyword do
    @behaviour ExJsonschema.CustomKeyword
    
    @impl true
    def keyword, do: "divisibleBy"
    
    @impl true
    def validate(context) do
      divisor = context.schema["divisibleBy"] 
      value = context.instance
      
      if is_number(value) and is_number(divisor) and rem(value, divisor) == 0 do
        :ok
      else
        {:error, "#{value} is not divisible by #{divisor}"}
      end
    end
  end

  defmodule TestFormat do
    @behaviour ExJsonschema.CustomFormat
    
    @impl true
    def format, do: "even-number"
    
    @impl true
    def validate(value) do
      case Integer.parse(value) do
        {num, ""} -> rem(num, 2) == 0
        _ -> false
      end
    end
  end

  describe "custom keywords" do
    test "keyword behavior works correctly" do
      context = %{
        instance: 10,
        schema: %{"divisibleBy" => 5},
        instance_path: "/value",
        schema_path: "/properties/value/divisibleBy"
      }
      
      assert :ok = TestKeyword.validate(context)
      
      context = %{context | instance: 7}
      assert {:error, message} = TestKeyword.validate(context)
      assert message =~ "not divisible by"
    end

    test "integration with validation" do
      schema = ~s({
        "type": "number",
        "divisibleBy": 3
      })
      
      {:ok, validator} = ExJsonschema.compile(schema, 
        custom_keywords: [TestKeyword]
      )
      
      assert :ok = ExJsonschema.validate(validator, "9")
      assert {:error, [error]} = ExJsonschema.validate(validator, "10")
      assert error.keyword == "divisibleBy"
    end
  end

  describe "custom formats" do
    test "format validation works" do
      assert TestFormat.validate("42") == true
      assert TestFormat.validate("41") == false
      assert TestFormat.validate("not_number") == false
    end

    test "integration with schema validation" do
      schema = ~s({
        "type": "string",
        "format": "even-number"
      })
      
      {:ok, validator} = ExJsonschema.compile(schema,
        custom_formats: [TestFormat]
      )
      
      assert :ok = ExJsonschema.validate(validator, ~s("24"))
      assert {:error, [error]} = ExJsonschema.validate(validator, ~s("25"))
      assert error.keyword == "format"
    end
  end
end
```

### Surface 6: Error Handling & Output

#### Error Format Tests
```elixir
defmodule ExJsonschema.ErrorHandlingTest do
  use ExUnit.Case

  describe "error structures" do
    test "validation errors have complete context" do
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
      
      {:ok, validator} = ExJsonschema.compile(schema)
      instance = ~s({"user": {"age": -5}})
      
      assert {:error, [error]} = ExJsonschema.validate(validator, instance)
      assert error.instance_path == "/user/age"
      assert error.schema_path == "/properties/user/properties/age/minimum"
      assert error.keyword == "minimum"
      assert error.instance_value == -5
      assert error.schema_value == 0
    end

    test "error formatting produces readable output" do
      errors = [
        %ExJsonschema.ValidationError{
          message: "Value is less than minimum",
          instance_path: "/user/age", 
          keyword: "minimum"
        }
      ]
      
      formatted = ExJsonschema.ErrorFormatter.format(errors, :human)
      assert formatted =~ "user/age"
      assert formatted =~ "less than minimum"
      
      json_formatted = ExJsonschema.ErrorFormatter.format(errors, :json)
      assert String.contains?(json_formatted, "instance_path")
    end
  end
end
```

### Surface 7: Performance & Caching

#### Performance Tests
```elixir
defmodule ExJsonschema.PerformanceTest do
  use ExUnit.Case

  defmodule MockCache do
    @behaviour ExJsonschema.Cache
    use Agent
    
    def start_link, do: Agent.start_link(fn -> %{} end, name: __MODULE__)
    
    @impl true
    def get(key, _opts) do
      case Agent.get(__MODULE__, &Map.get(&1, key)) do
        nil -> {:error, :not_found}
        value -> {:ok, value}
      end
    end
    
    @impl true
    def put(key, value, _opts) do
      Agent.update(__MODULE__, &Map.put(&1, key, value))
    end
    
    @impl true
    def delete(key, _opts) do
      Agent.update(__MODULE__, &Map.delete(&1, key))
    end
    
    @impl true
    def clear(_opts) do
      Agent.update(__MODULE__, fn _ -> %{} end)
    end
  end

  setup do
    {:ok, _} = MockCache.start_link()
    :ok
  end

  describe "caching behavior" do
    test "cache stores and retrieves validators" do
      schema = ~s({"type": "string"})
      
      # First compilation should cache
      time1 = :timer.tc(fn ->
        ExJsonschema.SchemaCache.compile_cached(schema, 
          ExJsonschema.Options.new(),
          cache_adapter: MockCache
        )
      end)
      
      # Second compilation should be faster (cached)
      time2 = :timer.tc(fn ->
        ExJsonschema.SchemaCache.compile_cached(schema, 
          ExJsonschema.Options.new(),
          cache_adapter: MockCache
        )
      end)
      
      assert elem(time2, 0) < elem(time1, 0)
    end
  end

  describe "performance benchmarks" do
    test "validation throughput meets requirements" do
      schema = ~s({"type": "string", "minLength": 1})
      {:ok, validator} = ExJsonschema.compile(schema)
      
      instances = Enum.map(1..1000, fn i -> ~s("test_string_#{i}") end)
      
      {time_microseconds, results} = :timer.tc(fn ->
        Enum.map(instances, &ExJsonschema.validate(validator, &1))
      end)
      
      validations_per_second = 1_000_000 * length(instances) / time_microseconds
      
      # Should validate at least 10,000 simple instances per second
      assert validations_per_second > 10_000
      assert Enum.all?(results, &(&1 == :ok))
    end

    test "memory usage stays reasonable" do
      large_schema = generate_complex_schema(100) # 100 properties
      {:ok, validator} = ExJsonschema.compile(large_schema)
      
      memory_before = :erlang.memory(:total)
      
      # Validate 1000 instances  
      Enum.each(1..1000, fn _ ->
        instance = generate_matching_instance(large_schema)
        ExJsonschema.validate(validator, instance)
      end)
      
      :erlang.garbage_collect()
      memory_after = :erlang.memory(:total)
      
      # Memory growth should be minimal (< 10MB)
      assert (memory_after - memory_before) < 10 * 1024 * 1024
    end
  end
end
```

---

## 🛠️ Test Infrastructure

### Test Data Management
```elixir
defmodule ExJsonschema.TestFixtures do
  @moduledoc "Centralized test data and fixtures"
  
  def valid_schemas do
    [
      ~s({"type": "string"}),
      ~s({"type": "number", "minimum": 0}),
      ~s({"type": "object", "properties": {"name": {"type": "string"}}}),
      # ... more schemas
    ]
  end
  
  def invalid_schemas do
    [
      ~s({"type": "invalid_type"}),
      ~s({"type": "string", "minimum": "not_a_number"}),
      # ... more invalid schemas
    ]
  end
  
  def property_generators do
    # StreamData generators for property testing
  end
end
```

### Test Helpers
```elixir
defmodule ExJsonschema.TestHelpers do
  @moduledoc "Helper functions for testing"
  
  def assert_valid_validation(validator, instance) do
    case ExJsonschema.validate(validator, instance) do
      :ok -> :ok
      {:error, errors} -> 
        flunk("Expected validation to succeed, got errors: #{inspect(errors)}")
    end
  end
  
  def assert_invalid_validation(validator, instance, expected_keyword \\ nil) do
    case ExJsonschema.validate(validator, instance) do
      :ok -> 
        flunk("Expected validation to fail")
      {:error, errors} -> 
        if expected_keyword do
          assert Enum.any?(errors, &(&1.keyword == expected_keyword))
        end
        errors
    end
  end
  
  def benchmark_validation(validator, instances, opts \\ []) do
    min_throughput = Keyword.get(opts, :min_throughput, 1000)
    
    {time_us, results} = :timer.tc(fn ->
      Enum.map(instances, &ExJsonschema.validate(validator, &1))
    end)
    
    throughput = 1_000_000 * length(instances) / time_us
    
    if throughput < min_throughput do
      flunk("Throughput #{throughput} below minimum #{min_throughput} validations/second")
    end
    
    {throughput, results}
  end
end
```

---

## 📋 Test Organization

### Directory Structure
```
test/
├── unit/                    # Unit tests for individual modules
│   ├── core_test.exs
│   ├── options_test.exs
│   ├── draft_test.exs
│   └── ...
├── integration/             # Integration tests for behaviors
│   ├── retriever_test.exs
│   ├── cache_test.exs
│   ├── custom_validation_test.exs
│   └── ...
├── property/                # Property-based tests
│   ├── core_property_test.exs
│   ├── schema_property_test.exs
│   └── ...
├── performance/             # Performance and benchmark tests
│   ├── validation_performance_test.exs
│   ├── caching_performance_test.exs
│   └── ...
├── compliance/              # JSON Schema spec compliance tests  
│   ├── draft4_compliance_test.exs
│   ├── draft7_compliance_test.exs
│   ├── draft202012_compliance_test.exs
│   └── ...
├── examples/                # Tests for documentation examples
│   ├── readme_examples_test.exs
│   ├── api_examples_test.exs
│   └── ...
├── fixtures/                # Test data and fixtures
│   ├── json_schema_test_suite/  # Official JSON Schema test suite
│   ├── schemas/
│   └── instances/
└── support/                 # Test helpers and utilities
    ├── test_helpers.ex
    ├── fixtures.ex
    └── generators.ex
```

### Test Configuration
```elixir
# test/test_helper.exs
ExUnit.start()

# Configure test environment
Application.put_env(:ex_jsonschema, :cache_adapter, ExJsonschema.Cache.Memory)
Application.put_env(:ex_jsonschema, :retriever, ExJsonschema.TestRetriever)

# Load test helpers
Code.require_file("support/test_helpers.ex", __DIR__)
Code.require_file("support/fixtures.ex", __DIR__)
Code.require_file("support/generators.ex", __DIR__)
```

---

## ⚡ Continuous Testing

### GitHub Actions CI
```yaml
# .github/workflows/test.yml
name: Test Suite

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        elixir: ['1.15', '1.16']
        otp: ['26', '27']
    steps:
      - uses: actions/checkout@v3
      - uses: erlef/setup-beam@v1
        with:
          elixir-version: ${{ matrix.elixir }}
          otp-version: ${{ matrix.otp }}
      - run: mix deps.get
      - run: mix compile --warnings-as-errors
      - run: mix test --cover
      - run: mix test --only property --max-failures 1
      - run: mix test --only performance
      - run: mix test --only compliance
```

### Coverage Requirements
- **Overall coverage**: >95%
- **Each module**: >90%
- **Critical paths**: 100% (validation, compilation)
- **Behaviors**: 100% (all callback combinations)

### Performance Regression Testing  
- Benchmark key operations in CI
- Fail CI if performance degrades >10%
- Track performance metrics over time

This comprehensive testing strategy ensures every aspect of the upgrade is thoroughly tested, from individual functions to full integration scenarios, performance characteristics, and JSON Schema specification compliance.