defmodule ExJsonschema.CoreTest do
  use ExUnit.Case
  use ExUnit.CaseHelpers

  alias ExJsonschema.{CompilationError, ValidationError}

  describe "compile/1" do
    test "compiles valid schema successfully" do
      schema = ~s({"type": "string"})
      assert {:ok, validator} = ExJsonschema.compile(schema)
      assert is_reference(validator)
    end

    test "rejects invalid JSON with clear error" do
      invalid_json = ~s({"type": "string)

      assert {:error, %CompilationError{type: :detection_error}} =
               ExJsonschema.compile(invalid_json)
    end

    test "rejects invalid schema with clear error" do
      invalid_schema = ~s({"type": "invalid_type"})

      assert {:error, %CompilationError{type: :compilation_error}} =
               ExJsonschema.compile(invalid_schema)
    end
  end

  describe "compile/2" do
    test "compiles schema with empty options" do
      schema = ~s({"type": "string"})
      assert {:ok, validator} = ExJsonschema.compile(schema, [])
      assert is_reference(validator)
    end
  end

  describe "compile!/1" do
    test "compiles valid schema successfully" do
      schema = ~s({"type": "string"})
      validator = ExJsonschema.compile!(schema)
      assert is_reference(validator)
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
      schema = ~s({"type": "string"})
      {:ok, validator} = ExJsonschema.compile(schema)
      %{validator: validator}
    end

    test "validates correct instance", %{validator: validator} do
      valid_json = ~s("hello")
      assert :ok = ExJsonschema.validate(validator, valid_json)
    end

    test "rejects invalid instance", %{validator: validator} do
      invalid_json = ~s(123)
      assert {:error, errors} = ExJsonschema.validate(validator, invalid_json)

      assert is_list(errors)
      assert length(errors) > 0

      error = hd(errors)
      assert %ValidationError{} = error
    end
  end

  describe "validate!/2" do
    setup do
      schema = ~s({"type": "string"})
      {:ok, validator} = ExJsonschema.compile(schema)
      %{validator: validator}
    end

    test "returns :ok for valid instance", %{validator: validator} do
      assert :ok = ExJsonschema.validate!(validator, ~s("hello"))
    end

    test "raises exception for invalid instance", %{validator: validator} do
      assert_raise ValidationError.Exception, ~r/JSON Schema validation failed/, fn ->
        ExJsonschema.validate!(validator, ~s(123))
      end
    end
  end

  describe "valid?/2" do
    setup do
      schema = ~s({"type": "string"})
      {:ok, validator} = ExJsonschema.compile(schema)
      %{validator: validator}
    end

    test "returns true for valid instance", %{validator: validator} do
      assert ExJsonschema.valid?(validator, ~s("hello")) == true
    end

    test "returns false for invalid instance", %{validator: validator} do
      assert ExJsonschema.valid?(validator, ~s(123)) == false
    end
  end

  describe "validate_once/2" do
    test "validates with schema compilation" do
      schema = ~s({"type": "string"})
      assert :ok = ExJsonschema.validate_once(schema, ~s("hello"))
    end

    test "returns errors for invalid instance" do
      schema = ~s({"type": "string"})
      assert {:error, errors} = ExJsonschema.validate_once(schema, ~s(123))
      assert is_list(errors) and length(errors) > 0
    end

    test "returns error for invalid schema" do
      invalid_schema = ~s({"type": "invalid_type"})

      assert {:error, %CompilationError{type: :compilation_error}} =
               ExJsonschema.validate_once(invalid_schema, ~s("hello"))
    end
  end
end
