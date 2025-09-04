defmodule ExJsonschema.EdgeCasesTest do
  use ExUnit.Case, async: true
  
  alias ExJsonschema.{CompilationError, ValidationError}

  describe "compile!/1" do
    test "returns compiled schema on success" do
      schema = ~s({"type": "string"})
      compiled = ExJsonschema.compile!(schema)
      assert is_reference(compiled)
    end

    test "raises ArgumentError on compilation failure" do
      invalid_schema = ~s({"type": "invalid_type"})
      
      assert_raise ArgumentError, ~r/Failed to compile schema/, fn ->
        ExJsonschema.compile!(invalid_schema)
      end
    end

    test "raises ArgumentError on JSON parse error" do
      invalid_json = ~s({"type": "string)  # Missing closing quote
      
      assert_raise ArgumentError, ~r/Failed to compile schema/, fn ->
        ExJsonschema.compile!(invalid_json)
      end
    end
  end

  describe "validate!/2" do
    setup do
      schema = ~s({
        "type": "object",
        "properties": {"name": {"type": "string"}},
        "required": ["name"]
      })
      {:ok, validator} = ExJsonschema.compile(schema)
      %{validator: validator}
    end

    test "returns :ok for valid JSON", %{validator: validator} do
      valid_json = ~s({"name": "John"})
      assert :ok = ExJsonschema.validate!(validator, valid_json)
    end

    test "raises ValidationError.Exception on validation failure", %{validator: validator} do
      invalid_json = ~s({"name": 123})
      
      assert_raise ExJsonschema.ValidationError.Exception, fn ->
        ExJsonschema.validate!(validator, invalid_json)
      end
    end
  end

  describe "validate_once/2 edge cases" do
    test "handles compilation errors" do
      invalid_schema = ~s({"type": "invalid_type"})
      instance = ~s("test")
      
      result = ExJsonschema.validate_once(invalid_schema, instance)
      assert {:error, %CompilationError{}} = result
    end

    test "handles JSON parse errors in schema" do
      invalid_json_schema = ~s({"type": "string)  # Missing quote
      instance = ~s("test")
      
      result = ExJsonschema.validate_once(invalid_json_schema, instance)
      assert {:error, %CompilationError{}} = result
    end

    test "successful validation" do
      schema = ~s({"type": "string"})
      instance = ~s("test")
      
      result = ExJsonschema.validate_once(schema, instance)
      assert :ok = result
    end

    test "failed validation" do
      schema = ~s({"type": "string"})
      instance = ~s(123)
      
      result = ExJsonschema.validate_once(schema, instance)
      assert {:error, [%ValidationError{} | _]} = result
    end
  end

  describe "compilation option validation edge cases" do
    test "draft mismatch error when schema specifies different draft" do
      # Schema explicitly specifies draft-07
      schema = ~s({
        "$schema": "http://json-schema.org/draft-07/schema#",
        "type": "string"
      })
      
      # Try to compile with draft4 options - should fail
      result = ExJsonschema.compile(schema, draft: :draft4)
      assert {:error, %CompilationError{}} = result
      error = elem(result, 1)
      # Error message should indicate validation failed due to draft mismatch
      assert String.contains?(error.message, "validation") or String.contains?(error.message, "draft")
    end

    test "no draft mismatch when schema has no $schema" do
      # Schema without explicit $schema
      schema = ~s({"type": "string"})
      
      # Should succeed with any draft option
      result = ExJsonschema.compile(schema, draft: :draft4)
      assert {:ok, compiled} = result
      assert is_reference(compiled)
    end

    test "auto draft detection works correctly" do
      schema = ~s({
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "type": "string"
      })
      
      result = ExJsonschema.compile(schema, draft: :auto)
      assert {:ok, compiled} = result
      assert is_reference(compiled)
    end
  end

  describe "validation with different output formats" do
    setup do
      schema = ~s({"type": "string"})
      {:ok, validator} = ExJsonschema.compile(schema)
      %{validator: validator}
    end

    test "basic format with valid input", %{validator: validator} do
      result = ExJsonschema.validate(validator, ~s("hello"), output: :basic)
      assert :ok = result
    end

    test "basic format with invalid input", %{validator: validator} do
      result = ExJsonschema.validate(validator, ~s(123), output: :basic)
      assert {:error, :validation_failed} = result
    end

    test "detailed format with valid input", %{validator: validator} do
      result = ExJsonschema.validate(validator, ~s("hello"), output: :detailed)
      assert :ok = result
    end

    test "detailed format with invalid input", %{validator: validator} do
      result = ExJsonschema.validate(validator, ~s(123), output: :detailed)
      assert {:error, [%ValidationError{} | _]} = result
    end

    test "verbose format with valid input", %{validator: validator} do
      result = ExJsonschema.validate(validator, ~s("hello"), output: :verbose)
      assert :ok = result
    end

    test "verbose format with invalid input", %{validator: validator} do
      result = ExJsonschema.validate(validator, ~s(123), output: :verbose)
      assert {:error, [%ValidationError{} | _]} = result
    end

    test "invalid output format raises ArgumentError", %{validator: validator} do
      assert_raise ArgumentError, ~r/Invalid output format/, fn ->
        ExJsonschema.validate(validator, ~s("hello"), output: :invalid)
      end
    end
  end

  describe "draft detection edge cases" do
    test "detect_draft with invalid JSON returns error" do
      invalid_json = ~s({"type": "string)  # Missing quote
      
      result = ExJsonschema.detect_draft(invalid_json)
      assert {:error, _reason} = result
    end

    test "detect_draft with map input" do
      schema_map = %{"type" => "string"}
      
      result = ExJsonschema.detect_draft(schema_map)
      assert {:ok, :draft202012} = result
    end

    test "detect_draft with map containing $schema" do
      schema_map = %{
        "$schema" => "http://json-schema.org/draft-07/schema#",
        "type" => "string"
      }
      
      result = ExJsonschema.detect_draft(schema_map)
      assert {:ok, :draft7} = result
    end
  end

  describe "error handling edge cases" do
    test "native validation errors are handled gracefully" do
      schema = ~s({"type": "string"})
      {:ok, validator} = ExJsonschema.compile(schema)
      
      # Test with various invalid inputs that might cause different error types
      test_cases = [
        ~s(123),           # Type error
        ~s(null),          # Null value
        ~s([]),            # Array instead of string
        ~s({})             # Object instead of string
      ]
      
      for invalid_input <- test_cases do
        result = ExJsonschema.validate(validator, invalid_input)
        assert {:error, [%ValidationError{} | _]} = result
      end
    end
  end

  describe "Options struct validation edge cases" do
    test "validate Options struct is properly handled" do
      schema = ~s({"type": "string"})
      {:ok, validator} = ExJsonschema.compile(schema)
      
      opts = ExJsonschema.Options.new(output_format: :basic)
      result = ExJsonschema.validate(validator, ~s("hello"), opts)
      assert :ok = result
    end

    test "valid?/3 with Options struct" do
      schema = ~s({"type": "string"})
      {:ok, validator} = ExJsonschema.compile(schema)
      
      opts = ExJsonschema.Options.new()
      result = ExJsonschema.valid?(validator, ~s("hello"), opts)
      assert true = result
    end
  end
end