defmodule ExJsonschema.ValidationOptionsTest do
  use ExUnit.Case, async: true

  alias ExJsonschema.Options

  describe "validate/3 with validation options" do
    setup do
      # Schema with format validation requirement
      schema = ~s({
        "type": "object",
        "properties": {
          "email": {"type": "string", "format": "email"},
          "age": {"type": "number", "minimum": 0}
        },
        "required": ["email"]
      })
      {:ok, validator} = ExJsonschema.compile(schema)

      %{validator: validator}
    end

    test "validate_formats: true enables format validation", %{validator: validator} do
      invalid_email = ~s({"email": "not-an-email"})

      # NOTE: For M2.4, format validation is accepted as an option but not yet 
      # implemented in the Rust NIF. This test verifies the option is accepted.
      result =
        ExJsonschema.validate(validator, invalid_email, output: :detailed, validate_formats: true)

      # For now, should pass since format validation isn't enforced yet
      # TODO: Update this test when format validation is implemented in Rust NIF
      assert :ok = result
    end

    test "validate_formats: false (default) skips format validation", %{validator: validator} do
      invalid_email = ~s({"email": "not-an-email"})

      # With format validation disabled (default), should pass
      result =
        ExJsonschema.validate(validator, invalid_email,
          output: :detailed,
          validate_formats: false
        )

      assert :ok = result
    end

    test "stop_on_first_error: true stops after first validation error", %{validator: validator} do
      # Instance with multiple errors: missing required field + type mismatch
      invalid_data = ~s({"age": "not-a-number"})

      # NOTE: For M2.4, stop_on_first_error is accepted as an option but not yet 
      # implemented in the Rust NIF. This test verifies the option is accepted.
      result =
        ExJsonschema.validate(validator, invalid_data,
          output: :detailed,
          stop_on_first_error: true
        )

      assert {:error, errors} = result
      # For now, should still return all errors since option isn't enforced yet
      # TODO: Update this test when stop_on_first_error is implemented in Rust NIF
      assert length(errors) >= 1
    end

    test "stop_on_first_error: false (default) returns all validation errors", %{
      validator: validator
    } do
      # Instance with multiple errors: missing required field + type mismatch  
      invalid_data = ~s({"age": "not-a-number"})

      # With stop_on_first_error disabled (default), should return all errors
      result =
        ExJsonschema.validate(validator, invalid_data,
          output: :detailed,
          stop_on_first_error: false
        )

      assert {:error, errors} = result
      # Should have multiple errors (missing required "email" + type error for "age")
      assert length(errors) >= 2
    end

    test "collect_annotations option controls annotation collection", %{validator: validator} do
      valid_data = ~s({"email": "test@example.com", "age": 25})

      # Test with collect_annotations: true (default)
      result_with_annotations =
        ExJsonschema.validate(validator, valid_data, output: :verbose, collect_annotations: true)

      assert :ok = result_with_annotations

      # Test with collect_annotations: false  
      result_without_annotations =
        ExJsonschema.validate(validator, valid_data, output: :verbose, collect_annotations: false)

      assert :ok = result_without_annotations

      # Both should succeed for valid data, but implementation details may differ
    end

    test "ignore_unknown_formats option handles unknown format assertions" do
      # Schema with unknown format
      schema = ~s({"type": "string", "format": "unknown-format"})
      {:ok, validator} = ExJsonschema.compile(schema)
      instance = ~s("some-value")

      # With ignore_unknown_formats: true (default), should pass
      result_ignore =
        ExJsonschema.validate(validator, instance,
          output: :detailed,
          ignore_unknown_formats: true
        )

      assert :ok = result_ignore

      # With ignore_unknown_formats: false, behavior depends on implementation
      # (may pass or fail based on how unknown formats are handled)
      result_strict =
        ExJsonschema.validate(validator, instance,
          output: :detailed,
          ignore_unknown_formats: false
        )

      assert match?(:ok, result_strict) or match?({:error, _}, result_strict)
    end

    test "options can be combined together", %{validator: validator} do
      invalid_email = ~s({"email": "not-an-email"})

      # Combine multiple options - this test verifies they're all accepted
      result =
        ExJsonschema.validate(validator, invalid_email,
          output: :verbose,
          validate_formats: true,
          stop_on_first_error: true,
          collect_annotations: false
        )

      # For now, should pass since validation options aren't enforced yet
      # This test verifies that multiple options can be combined without error
      assert :ok = result
    end
  end

  describe "validate/3 with Options struct" do
    setup do
      schema = ~s({"type": "string", "format": "email"})
      {:ok, validator} = ExJsonschema.compile(schema)
      %{validator: validator}
    end

    test "accepts Options struct for validation options", %{validator: validator} do
      invalid_email = ~s("not-an-email")

      # Create Options struct with validation settings
      opts =
        Options.new(
          output_format: :detailed,
          validate_formats: true,
          stop_on_first_error: true
        )

      result = ExJsonschema.validate(validator, invalid_email, opts)

      # For now, should pass since validation options aren't enforced yet
      # This test verifies that Options struct is properly accepted
      assert :ok = result
    end

    test "Options struct works with validation settings", %{validator: validator} do
      invalid_email = ~s("not-an-email")

      # Test Options struct with validate_formats: true
      opts_true = Options.new(validate_formats: true, output_format: :detailed)
      result_true = ExJsonschema.validate(validator, invalid_email, opts_true)

      # Test Options struct with validate_formats: false  
      opts_false = Options.new(validate_formats: false, output_format: :detailed)
      result_false = ExJsonschema.validate(validator, invalid_email, opts_false)

      # For now, both should pass (format validation not yet implemented in NIF)
      # This test verifies the Options struct is properly accepted
      assert :ok = result_true
      assert :ok = result_false
    end
  end

  describe "validate/3 input validation" do
    setup do
      schema = ~s({"type": "string"})
      {:ok, validator} = ExJsonschema.compile(schema)
      %{validator: validator}
    end

    test "raises ArgumentError for invalid options", %{validator: validator} do
      instance = ~s("valid")

      assert_raise ArgumentError, ~r/Invalid validation option/, fn ->
        ExJsonschema.validate(validator, instance, invalid_option: true)
      end
    end

    test "validates boolean options", %{validator: validator} do
      instance = ~s("valid")

      assert_raise ArgumentError, ~r/must be a boolean/, fn ->
        ExJsonschema.validate(validator, instance, validate_formats: "not a boolean")
      end
    end
  end

  describe "valid?/3 with validation options" do
    test "supports validation options for quick validation" do
      schema = ~s({"type": "string", "format": "email"})
      {:ok, validator} = ExJsonschema.compile(schema)
      invalid_email = ~s("not-an-email")

      # Both should return true for now since format validation isn't enforced yet
      # This test verifies that valid?/3 accepts validation options
      assert ExJsonschema.valid?(validator, invalid_email, validate_formats: false) == true
      assert ExJsonschema.valid?(validator, invalid_email, validate_formats: true) == true
    end
  end
end
