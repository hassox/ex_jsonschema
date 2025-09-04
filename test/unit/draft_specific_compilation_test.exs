defmodule ExJsonschema.DraftSpecificCompilationTest do
  @moduledoc """
  Tests for draft-specific compilation shortcuts and optimizations.
  
  This module tests M3.5: Draft-specific compilation shortcuts.
  """
  
  use ExUnit.Case, async: true

  describe "compile_draft4/2" do
    test "compiles valid Draft 4 schema" do
      schema = ~s({"type": "string"})
      assert {:ok, compiled} = ExJsonschema.compile_draft4(schema)
      assert is_reference(compiled)
    end

    test "compiles Draft 4 schema with specific keywords" do
      schema = ~s({
        "type": "object",
        "properties": {
          "name": {"type": "string"},
          "age": {"type": "integer", "minimum": 0}
        },
        "required": ["name"]
      })
      assert {:ok, compiled} = ExJsonschema.compile_draft4(schema)
      assert is_reference(compiled)
    end

    test "compiles with additional options" do
      schema = ~s({"type": "string", "format": "email"})
      assert {:ok, compiled} = ExJsonschema.compile_draft4(schema, validate_formats: true)
      assert is_reference(compiled)
    end

    test "returns compilation error for invalid schema" do
      schema = ~s({"type": "invalid_type"})
      assert {:error, %ExJsonschema.CompilationError{}} = ExJsonschema.compile_draft4(schema)
    end

    test "returns compilation error for malformed JSON" do
      schema = ~s({"type": "string",})
      assert {:error, %ExJsonschema.CompilationError{}} = ExJsonschema.compile_draft4(schema)
    end
  end

  describe "compile_draft6/2" do
    test "compiles valid Draft 6 schema" do
      schema = ~s({"type": "string"})
      assert {:ok, compiled} = ExJsonschema.compile_draft6(schema)
      assert is_reference(compiled)
    end

    test "compiles Draft 6 schema with const keyword" do
      schema = ~s({"const": "hello"})
      assert {:ok, compiled} = ExJsonschema.compile_draft6(schema)
      assert is_reference(compiled)
    end

    test "compiles with additional options" do
      schema = ~s({"type": "array", "contains": {"type": "number"}})
      assert {:ok, compiled} = ExJsonschema.compile_draft6(schema, collect_annotations: false)
      assert is_reference(compiled)
    end
  end

  describe "compile_draft7/2" do
    test "compiles valid Draft 7 schema" do
      schema = ~s({"type": "string"})
      assert {:ok, compiled} = ExJsonschema.compile_draft7(schema)
      assert is_reference(compiled)
    end

    test "compiles Draft 7 schema with conditional keywords" do
      schema = ~s({
        "type": "object",
        "properties": {
          "country": {"type": "string"}
        },
        "if": {"properties": {"country": {"const": "US"}}},
        "then": {
          "properties": {
            "postal_code": {"pattern": "^[0-9]{5}$"}
          }
        },
        "else": {
          "properties": {
            "postal_code": {"type": "string"}
          }
        }
      })
      assert {:ok, compiled} = ExJsonschema.compile_draft7(schema)
      assert is_reference(compiled)
    end

    test "handles readOnly and writeOnly keywords" do
      schema = ~s({
        "type": "object", 
        "properties": {
          "id": {"type": "integer", "readOnly": true},
          "secret": {"type": "string", "writeOnly": true}
        }
      })
      assert {:ok, compiled} = ExJsonschema.compile_draft7(schema)
      assert is_reference(compiled)
    end
  end

  describe "compile_draft201909/2" do
    test "compiles valid Draft 2019-09 schema" do
      schema = ~s({"type": "string"})
      assert {:ok, compiled} = ExJsonschema.compile_draft201909(schema)
      assert is_reference(compiled)
    end

    test "compiles schema with unevaluatedProperties" do
      schema = ~s({
        "type": "object",
        "properties": {
          "name": {"type": "string"}
        },
        "unevaluatedProperties": false
      })
      assert {:ok, compiled} = ExJsonschema.compile_draft201909(schema)
      assert is_reference(compiled)
    end

    test "handles dependentSchemas keyword" do
      schema = ~s({
        "type": "object",
        "dependentSchemas": {
          "credit_card": {
            "required": ["billing_address"]
          }
        }
      })
      assert {:ok, compiled} = ExJsonschema.compile_draft201909(schema)
      assert is_reference(compiled)
    end
  end

  describe "compile_draft202012/2" do
    test "compiles valid Draft 2020-12 schema" do
      schema = ~s({"type": "string"})
      assert {:ok, compiled} = ExJsonschema.compile_draft202012(schema)
      assert is_reference(compiled)
    end

    test "compiles schema with prefixItems" do
      schema = ~s({
        "type": "array",
        "prefixItems": [
          {"type": "string"},
          {"type": "number"}
        ],
        "items": false
      })
      assert {:ok, compiled} = ExJsonschema.compile_draft202012(schema)
      assert is_reference(compiled)
    end

    test "handles dynamic references" do
      schema = ~s({
        "$id": "https://example.com/root",
        "$dynamicRef": "#meta",
        "$defs": {
          "meta": {
            "$dynamicAnchor": "meta",
            "type": "object"
          }
        }
      })
      assert {:ok, compiled} = ExJsonschema.compile_draft202012(schema)
      assert is_reference(compiled)
    end
  end

  describe "compile_auto_draft/2" do
    test "automatically detects Draft 7 from $schema" do
      schema = ~s({
        "$schema": "http://json-schema.org/draft-07/schema#",
        "type": "string"
      })
      assert {:ok, compiled} = ExJsonschema.compile_auto_draft(schema)
      assert is_reference(compiled)
    end

    test "automatically detects Draft 2020-12 from $schema" do
      schema = ~s({
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "type": "object"
      })
      assert {:ok, compiled} = ExJsonschema.compile_auto_draft(schema)
      assert is_reference(compiled)
    end

    test "defaults to latest draft when no $schema present" do
      schema = ~s({"type": "string"})
      assert {:ok, compiled} = ExJsonschema.compile_auto_draft(schema)
      assert is_reference(compiled)
    end

    test "works with additional options" do
      schema = ~s({
        "$schema": "http://json-schema.org/draft-07/schema#",
        "type": "string",
        "format": "email"
      })
      assert {:ok, compiled} = ExJsonschema.compile_auto_draft(schema, validate_formats: true)
      assert is_reference(compiled)
    end
  end

  describe "draft-specific compilation optimization verification" do
    test "all draft-specific compilation methods return compatible validators" do
      schema = ~s({"type": "string"})
      
      # Compile with each method
      {:ok, draft4} = ExJsonschema.compile_draft4(schema)
      {:ok, draft6} = ExJsonschema.compile_draft6(schema) 
      {:ok, draft7} = ExJsonschema.compile_draft7(schema)
      {:ok, draft201909} = ExJsonschema.compile_draft201909(schema)
      {:ok, draft202012} = ExJsonschema.compile_draft202012(schema)
      {:ok, auto} = ExJsonschema.compile_auto_draft(schema)
      {:ok, generic} = ExJsonschema.compile(schema)

      # All should be references
      validators = [draft4, draft6, draft7, draft201909, draft202012, auto, generic]
      assert Enum.all?(validators, &is_reference/1)

      # All should validate the same valid input
      valid_json = ~s("test")
      validation_results = Enum.map(validators, &ExJsonschema.validate(&1, valid_json))
      assert Enum.all?(validation_results, fn result -> result == :ok end)

      # All should reject the same invalid input
      invalid_json = ~s(123)
      rejection_results = Enum.map(validators, fn validator ->
        case ExJsonschema.validate(validator, invalid_json) do
          {:error, _} -> true
          _ -> false
        end
      end)
      assert Enum.all?(rejection_results, & &1)
    end

    test "draft-specific methods work with validation" do
      schema = ~s({
        "type": "object",
        "properties": {
          "name": {"type": "string", "minLength": 1},
          "age": {"type": "integer", "minimum": 0, "maximum": 150}
        },
        "required": ["name"]
      })
      
      {:ok, compiled} = ExJsonschema.compile_draft7(schema)
      
      # Valid data
      valid_json = ~s({"name": "John", "age": 30})
      assert :ok = ExJsonschema.validate(compiled, valid_json)
      assert true = ExJsonschema.valid?(compiled, valid_json)

      # Missing required field
      invalid_json1 = ~s({"age": 30})
      assert {:error, errors1} = ExJsonschema.validate(compiled, invalid_json1)
      assert false == ExJsonschema.valid?(compiled, invalid_json1)
      assert length(errors1) > 0

      # Type mismatch
      invalid_json2 = ~s({"name": 123, "age": 30})
      assert {:error, errors2} = ExJsonschema.validate(compiled, invalid_json2)
      assert false == ExJsonschema.valid?(compiled, invalid_json2)
      assert length(errors2) > 0
    end
  end

  describe "performance comparison" do
    # These tests don't assert performance differences but demonstrate usage
    @tag :performance
    test "draft-specific compilation can be benchmarked" do
      schema = ~s({
        "type": "object",
        "properties": {
          "items": {
            "type": "array",
            "items": {
              "type": "object",
              "properties": {
                "id": {"type": "string"},
                "value": {"type": "number"}
              }
            }
          }
        }
      })

      # Generic compilation
      start_time = System.monotonic_time(:microsecond)
      {:ok, generic} = ExJsonschema.compile(schema)
      generic_compile_time = System.monotonic_time(:microsecond) - start_time

      # Draft-specific compilation  
      start_time = System.monotonic_time(:microsecond)
      {:ok, draft7} = ExJsonschema.compile_draft7(schema)
      draft7_compile_time = System.monotonic_time(:microsecond) - start_time

      # Both should produce working validators
      test_json = ~s({"items": [{"id": "test", "value": 42}]})
      assert :ok = ExJsonschema.validate(generic, test_json)
      assert :ok = ExJsonschema.validate(draft7, test_json)

      # Record the times (for future benchmarking analysis)
      assert generic_compile_time > 0
      assert draft7_compile_time > 0
    end
  end

  describe "edge cases" do
    test "handles empty schema" do
      schema = ~s({})
      assert {:ok, compiled} = ExJsonschema.compile_draft7(schema)
      assert :ok = ExJsonschema.validate(compiled, ~s("anything"))
      assert :ok = ExJsonschema.validate(compiled, ~s(42))
      assert :ok = ExJsonschema.validate(compiled, ~s({}))
    end

    test "handles complex nested schema" do
      schema = ~s({
        "type": "object",
        "properties": {
          "user": {
            "type": "object",
            "properties": {
              "profile": {
                "type": "object", 
                "properties": {
                  "preferences": {
                    "type": "array",
                    "items": {
                      "type": "object",
                      "properties": {
                        "key": {"type": "string"},
                        "value": {"type": ["string", "number", "boolean"]}
                      }
                    }
                  }
                }
              }
            }
          }
        }
      })

      assert {:ok, compiled} = ExJsonschema.compile_draft7(schema)
      
      valid_json = ~s({
        "user": {
          "profile": {
            "preferences": [
              {"key": "theme", "value": "dark"},
              {"key": "notifications", "value": true},
              {"key": "refresh_rate", "value": 60}
            ]
          }
        }
      })
      
      assert :ok = ExJsonschema.validate(compiled, valid_json)
    end

    test "error handling is consistent across draft-specific methods" do
      invalid_schema = ~s({"type": "not_a_real_type"})
      
      assert {:error, error1} = ExJsonschema.compile_draft4(invalid_schema)
      assert {:error, error2} = ExJsonschema.compile_draft6(invalid_schema)
      assert {:error, error3} = ExJsonschema.compile_draft7(invalid_schema)
      assert {:error, error4} = ExJsonschema.compile_draft201909(invalid_schema)
      assert {:error, error5} = ExJsonschema.compile_draft202012(invalid_schema)

      # All should return CompilationError structs
      errors = [error1, error2, error3, error4, error5]
      assert Enum.all?(errors, fn error -> 
        match?(%ExJsonschema.CompilationError{}, error)
      end)
    end
  end
end