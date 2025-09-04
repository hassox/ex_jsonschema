defmodule ExJsonschema.MetaValidatorTest do
  use ExUnit.Case, async: true

  alias ExJsonschema.{MetaValidator, ValidationError}

  describe "valid?/1" do
    test "returns true for valid schemas" do
      # Simple valid schema
      schema = ~s({"type": "string"})
      assert MetaValidator.valid?(schema) == true

      # Complex valid schema
      complex_schema = ~s({
        "type": "object",
        "properties": {
          "name": {"type": "string", "minLength": 1},
          "age": {"type": "integer", "minimum": 0, "maximum": 200}
        },
        "required": ["name"],
        "additionalProperties": false
      })
      assert MetaValidator.valid?(complex_schema) == true

      # Schema without $schema (should always work)
      array_schema = ~s({
        "type": "array",
        "items": {"type": "string"}
      })
      assert MetaValidator.valid?(array_schema) == true
    end

    test "returns false for invalid schemas" do
      # Invalid type
      invalid_type = ~s({"type": "invalid_type"})
      assert MetaValidator.valid?(invalid_type) == false

      # Invalid structure - properties should be object
      invalid_structure = ~s({"properties": "should_be_object"})
      assert MetaValidator.valid?(invalid_structure) == false
    end

    test "raises ArgumentError for malformed JSON" do
      malformed_json = ~s({"type": "string)

      assert_raise ArgumentError, ~r/Invalid JSON/, fn ->
        MetaValidator.valid?(malformed_json)
      end
    end
  end

  describe "validate_simple/1" do
    test "returns :ok for valid schemas" do
      schema = ~s({"type": "string", "minLength": 5})
      assert MetaValidator.validate_simple(schema) == :ok

      # Array schema
      array_schema = ~s({
        "type": "array", 
        "items": {"type": "number"},
        "minItems": 1,
        "maxItems": 10
      })
      assert MetaValidator.validate_simple(array_schema) == :ok
    end

    test "returns error for invalid schemas" do
      invalid_schema = ~s({"type": "invalid_type"})

      assert {:error, reason} = MetaValidator.validate_simple(invalid_schema)
      assert is_binary(reason)
      assert String.length(reason) > 0
    end

    test "returns error for malformed JSON" do
      malformed_json = ~s({"type": "string)

      assert {:error, reason} = MetaValidator.validate_simple(malformed_json)
      assert String.contains?(reason, "Invalid JSON")
    end
  end

  describe "validate/1" do
    test "returns :ok for valid schemas" do
      # Basic valid schema
      schema = ~s({"type": "string"})
      assert MetaValidator.validate(schema) == :ok

      # Object schema with all valid constraints
      object_schema = ~s({
        "type": "object",
        "properties": {
          "email": {"type": "string", "format": "email"},
          "age": {"type": "integer", "minimum": 0}
        },
        "required": ["email"]
      })
      assert MetaValidator.validate(object_schema) == :ok

      # Schema with conditional logic
      conditional_schema = ~s({
        "type": "object",
        "properties": {
          "country": {"type": "string"}
        },
        "if": {"properties": {"country": {"const": "USA"}}},
        "then": {"required": ["zipCode"]},
        "else": {"required": ["postalCode"]}
      })
      assert MetaValidator.validate(conditional_schema) == :ok
    end

    test "returns detailed errors for invalid schemas" do
      invalid_schema = ~s({"type": "invalid_type"})

      assert {:error, errors} = MetaValidator.validate(invalid_schema)
      assert is_list(errors)
      assert length(errors) > 0

      # Check error structure
      error = hd(errors)
      assert %ValidationError{} = error
      assert is_binary(error.message)
      assert error.message != ""
      assert error.keyword in ["meta", "compilation"]
    end

    test "handles multiple validation errors" do
      # Schema with multiple issues
      multi_error_schema = ~s({
        "type": "invalid_type",
        "properties": "should_be_object",
        "minimum": "should_be_number"
      })

      case MetaValidator.validate(multi_error_schema) do
        {:error, errors} when is_list(errors) ->
          assert length(errors) >= 1

          Enum.each(errors, fn error ->
            assert %ValidationError{} = error
            assert is_binary(error.message)
          end)

        {:error, reason} when is_binary(reason) ->
          # Single error message is also acceptable
          assert String.length(reason) > 0
      end
    end

    test "returns error for malformed JSON" do
      malformed_json = ~s({"type": "string)

      assert {:error, reason} = MetaValidator.validate(malformed_json)
      assert is_binary(reason)
      assert String.contains?(reason, "Invalid JSON")
    end
  end

  describe "validate!/1" do
    test "returns :ok for valid schemas" do
      schema = ~s({"type": "string", "pattern": "^[a-z]+$"})
      assert MetaValidator.validate!(schema) == :ok
    end

    test "raises ValidationError for invalid schemas" do
      invalid_schema = ~s({"type": "invalid_type"})

      assert_raise ExJsonschema.ValidationError, fn ->
        MetaValidator.validate!(invalid_schema)
      end
    end

    test "raises ArgumentError for malformed JSON" do
      malformed_json = ~s({"type": "string)

      assert_raise ArgumentError, ~r/Invalid JSON/, fn ->
        MetaValidator.validate!(malformed_json)
      end
    end
  end

  describe "integration with main API" do
    test "main API delegates correctly" do
      schema = ~s({"type": "string"})

      # Test delegation works
      assert ExJsonschema.meta_valid?(schema) == true
      assert ExJsonschema.meta_validate(schema) == :ok
      assert ExJsonschema.meta_validate!(schema) == :ok
    end

    test "error formatting works with meta-validation errors" do
      invalid_schema = ~s({"type": "invalid_type"})

      case ExJsonschema.meta_validate(invalid_schema) do
        {:error, errors} when is_list(errors) ->
          # Test that errors can be formatted
          formatted = ExJsonschema.format_errors(errors, :human)
          assert is_binary(formatted)
          assert String.length(formatted) > 0

          # Test JSON format
          json_formatted = ExJsonschema.format_errors(errors, :json)
          assert is_binary(json_formatted)

        {:error, _reason} ->
          # Single error is also acceptable for meta-validation
          :ok
      end
    end

    test "error analysis works with meta-validation errors" do
      invalid_schema = ~s({"type": "invalid_type", "properties": "should_be_object"})

      case ExJsonschema.meta_validate(invalid_schema) do
        {:error, errors} when is_list(errors) ->
          analysis = ExJsonschema.analyze_errors(errors)

          assert is_map(analysis)
          assert Map.has_key?(analysis, :total_errors)
          assert analysis.total_errors > 0

        {:error, _reason} ->
          # Single error case
          :ok
      end
    end
  end

  describe "draft-specific meta-validation" do
    test "validates schemas without explicit $schema" do
      # Simple schema without $schema (should work)
      simple_schema = ~s({
        "type": "object",
        "properties": {
          "name": {"type": "string"}
        }
      })
      assert MetaValidator.valid?(simple_schema) == true
    end

    test "handles schemas without $schema URLs" do
      # Schema without $schema URL - should always work cleanly
      simple_schema = ~s({
        "type": "object",
        "properties": {"foo": {"type": "string"}}
      })

      # This should always work without panics
      result = MetaValidator.valid?(simple_schema)
      assert result == true
    end

    test "detects schema validation issues without problematic URLs" do
      # Schema with invalid structure - should be reliably detected
      invalid_schema = ~s({
        "type": "object",
        "properties": "this_should_be_an_object_not_string"
      })

      # This should be false due to invalid structure
      result = MetaValidator.valid?(invalid_schema)
      assert result == false
    end
  end

  describe "edge cases" do
    test "handles empty schema" do
      empty_schema = ~s({})
      assert MetaValidator.valid?(empty_schema) == true
    end

    test "handles boolean schemas" do
      true_schema = ~s(true)
      false_schema = ~s(false)

      # Boolean schemas are valid in newer drafts
      assert MetaValidator.valid?(true_schema) == true
      assert MetaValidator.valid?(false_schema) == true
    end

    test "handles large complex schemas" do
      large_schema = ~s({
        "type": "object",
        "properties": {
          "user": {
            "type": "object",
            "properties": {
              "id": {"type": "integer", "minimum": 1},
              "name": {"type": "string", "minLength": 1, "maxLength": 100},
              "email": {"type": "string", "format": "email"},
              "roles": {
                "type": "array",
                "items": {"type": "string", "enum": ["admin", "user", "guest"]},
                "uniqueItems": true
              },
              "profile": {
                "type": "object",
                "properties": {
                  "bio": {"type": "string", "maxLength": 500},
                  "website": {"type": "string", "format": "uri"},
                  "location": {"type": "string"}
                },
                "additionalProperties": false
              }
            },
            "required": ["id", "name", "email"],
            "additionalProperties": false
          }
        },
        "required": ["user"]
      })

      assert MetaValidator.valid?(large_schema) == true
    end
  end
end
