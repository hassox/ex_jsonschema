defmodule ExJsonschemaTest do
  use ExUnit.Case
  doctest ExJsonschema

  alias ExJsonschema.{ValidationError, CompilationError}

  describe "compile/1" do
    test "compiles a valid schema" do
      schema = ~s({"type": "string"})
      assert {:ok, compiled} = ExJsonschema.compile(schema)
      assert is_reference(compiled)
    end

    test "returns error for invalid JSON" do
      invalid_json = ~s({"type": "string)
      assert {:error, %CompilationError{type: :json_parse_error}} = ExJsonschema.compile(invalid_json)
    end

    test "returns error for invalid schema" do
      invalid_schema = ~s({"type": "invalid_type"})
      assert {:error, %CompilationError{type: :compilation_error}} = ExJsonschema.compile(invalid_schema)
    end
  end

  describe "compile!/1" do
    test "compiles a valid schema" do
      schema = ~s({"type": "string"})
      compiled = ExJsonschema.compile!(schema)
      assert is_reference(compiled)
    end

    test "raises on invalid schema" do
      invalid_schema = ~s({"type": "invalid_type"})
      assert_raise ArgumentError, ~r/Failed to compile schema.*CompilationError/, fn ->
        ExJsonschema.compile!(invalid_schema)
      end
    end
  end

  describe "validate/2" do
    setup do
      schema = ~s({
        "type": "object",
        "properties": {
          "name": {"type": "string"},
          "age": {"type": "number", "minimum": 0}
        },
        "required": ["name"]
      })
      {:ok, compiled} = ExJsonschema.compile(schema)
      %{compiled: compiled}
    end

    test "validates correct JSON", %{compiled: compiled} do
      valid_json = ~s({"name": "John", "age": 30})
      assert :ok = ExJsonschema.validate(compiled, valid_json)
    end

    test "returns errors for invalid JSON", %{compiled: compiled} do
      invalid_json = ~s({"age": 30})
      assert {:error, errors} = ExJsonschema.validate(compiled, invalid_json)
      assert is_list(errors)
      assert length(errors) > 0
      assert %ValidationError{} = hd(errors)
    end

    test "handles type mismatch", %{compiled: compiled} do
      invalid_json = ~s({"name": 123})
      assert {:error, errors} = ExJsonschema.validate(compiled, invalid_json)
      assert is_list(errors)
      error = hd(errors)
      assert error.instance_path =~ "name"
      assert error.message =~ "string"
    end

    test "handles minimum constraint violation", %{compiled: compiled} do
      invalid_json = ~s({"name": "John", "age": -5})
      assert {:error, errors} = ExJsonschema.validate(compiled, invalid_json)
      assert is_list(errors)
      error = hd(errors)
      assert error.instance_path =~ "age"
      assert error.message =~ "minimum"
    end
  end

  describe "validate!/2" do
    setup do
      schema = ~s({"type": "string"})
      {:ok, compiled} = ExJsonschema.compile(schema)
      %{compiled: compiled}
    end

    test "returns :ok for valid JSON", %{compiled: compiled} do
      assert :ok = ExJsonschema.validate!(compiled, ~s("hello"))
    end

    test "raises exception for invalid JSON", %{compiled: compiled} do
      assert_raise ValidationError.Exception, ~r/JSON Schema validation failed/, fn ->
        ExJsonschema.validate!(compiled, ~s(123))
      end
    end
  end

  describe "valid?/2" do
    setup do
      schema = ~s({"type": "string"})
      {:ok, compiled} = ExJsonschema.compile(schema)
      %{compiled: compiled}
    end

    test "returns true for valid JSON", %{compiled: compiled} do
      assert ExJsonschema.valid?(compiled, ~s("hello"))
    end

    test "returns false for invalid JSON", %{compiled: compiled} do
      refute ExJsonschema.valid?(compiled, ~s(123))
    end
  end

  describe "validate_once/2" do
    test "validates with schema compilation" do
      schema = ~s({"type": "string"})
      assert :ok = ExJsonschema.validate_once(schema, ~s("hello"))
    end

    test "returns errors for invalid JSON" do
      schema = ~s({"type": "string"})
      assert {:error, errors} = ExJsonschema.validate_once(schema, ~s(123))
      assert is_list(errors)
    end

    test "returns error for invalid schema" do
      invalid_schema = ~s({"type": "invalid_type"})
      assert {:error, %CompilationError{type: :compilation_error}} = ExJsonschema.validate_once(invalid_schema, ~s("hello"))
    end
  end

  describe "draft support" do
    test "supports object validation" do
      schema = ~s({
        "type": "object",
        "properties": {
          "foo": {"type": "string"}
        },
        "additionalProperties": false
      })

      {:ok, compiled} = ExJsonschema.compile(schema)
      
      # Valid object
      assert :ok = ExJsonschema.validate(compiled, ~s({"foo": "bar"}))
      
      # Invalid: additional property
      assert {:error, _} = ExJsonschema.validate(compiled, ~s({"foo": "bar", "baz": "qux"}))
    end

    test "supports array validation" do
      schema = ~s({
        "type": "array",
        "items": {"type": "number"},
        "minItems": 1
      })

      {:ok, compiled} = ExJsonschema.compile(schema)
      
      # Valid array
      assert :ok = ExJsonschema.validate(compiled, ~s([1, 2, 3]))
      
      # Invalid: empty array
      assert {:error, _} = ExJsonschema.validate(compiled, ~s([]))
      
      # Invalid: wrong item type
      assert {:error, _} = ExJsonschema.validate(compiled, ~s([1, "two", 3]))
    end

    test "supports nested schemas" do
      schema = ~s({
        "type": "object",
        "properties": {
          "person": {
            "type": "object",
            "properties": {
              "name": {"type": "string"},
              "contacts": {
                "type": "array",
                "items": {"type": "string"}
              }
            }
          }
        }
      })

      {:ok, compiled} = ExJsonschema.compile(schema)
      
      valid_json = ~s({
        "person": {
          "name": "John",
          "contacts": ["email@example.com", "123-456-7890"]
        }
      })
      
      assert :ok = ExJsonschema.validate(compiled, valid_json)
    end
  end

  describe "error details" do
    test "provides detailed error information" do
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

      {:ok, compiled} = ExJsonschema.compile(schema)
      invalid_json = ~s({"user": {"age": -5}})
      
      assert {:error, [error]} = ExJsonschema.validate(compiled, invalid_json)
      assert %ValidationError{} = error
      assert error.instance_path != ""
      assert error.schema_path != ""
      assert error.message != ""
    end
  end
end
