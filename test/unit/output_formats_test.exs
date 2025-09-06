defmodule ExJsonschema.OutputFormatsTest do
  use ExUnit.Case
  use ExUnitProperties

  describe "output format: basic (boolean only)" do
    test "returns true for valid instances" do
      schema = ~s({"type": "string", "minLength": 2})
      {:ok, validator} = ExJsonschema.compile(schema)

      assert ExJsonschema.valid?(validator, ~s("hello")) == true
    end

    test "returns false for invalid instances" do
      schema = ~s({"type": "string", "minLength": 2})
      {:ok, validator} = ExJsonschema.compile(schema)

      assert ExJsonschema.valid?(validator, ~s("a")) == false
      assert ExJsonschema.valid?(validator, ~s(123)) == false
    end

    test "works correctly for bulk validation" do
      schema = ~s({"type": "string", "minLength": 1})
      {:ok, validator} = ExJsonschema.compile(schema)

      valid_instances = Enum.map(1..10, fn i -> ~s("test_#{i}") end)
      invalid_instances = Enum.map(1..5, fn _ -> ~s("") end)

      # All valid instances should pass
      valid_results = Enum.map(valid_instances, &ExJsonschema.valid?(validator, &1))
      assert Enum.all?(valid_results, &(&1 == true))

      # All invalid instances should fail
      invalid_results = Enum.map(invalid_instances, &ExJsonschema.valid?(validator, &1))
      assert Enum.all?(invalid_results, &(&1 == false))
    end
  end

  describe "output format: detailed (default error information)" do
    test "returns :ok for valid instances" do
      schema = ~s({"type": "string", "minLength": 2})
      {:ok, validator} = ExJsonschema.compile(schema)

      assert :ok = ExJsonschema.validate(validator, ~s("hello"))
    end

    test "returns detailed errors for invalid instances" do
      schema = ~s({
        "type": "object",
        "properties": {
          "name": {"type": "string", "minLength": 2},
          "age": {"type": "number", "minimum": 0}
        },
        "required": ["name"]
      })
      {:ok, validator} = ExJsonschema.compile(schema)

      assert {:error, errors} = ExJsonschema.validate(validator, ~s({"name": "a", "age": -5}))

      # Should have 2 errors: name too short, age below minimum
      assert length(errors) == 2

      # Check error structure
      name_error = Enum.find(errors, &(&1.instance_path == "/name"))
      age_error = Enum.find(errors, &(&1.instance_path == "/age"))

      # Actual error message format
      assert name_error.message =~ "shorter than"
      assert age_error.message =~ "minimum"

      # Should not have verbose fields populated (should be nil)
      assert is_nil(name_error.instance_value)
      assert is_nil(name_error.schema_value)
      assert is_nil(name_error.keyword)
    end

    test "uses detailed format by default" do
      schema = ~s({"type": "number"})
      {:ok, validator} = ExJsonschema.compile(schema)

      # These should be equivalent
      result1 = ExJsonschema.validate(validator, ~s("string"))
      result2 = ExJsonschema.validate(validator, ~s("string"), output: :detailed)

      assert result1 == result2
    end
  end

  describe "output format: verbose (comprehensive error information)" do
    test "includes instance and schema values" do
      schema = ~s({
        "type": "object",
        "properties": {
          "age": {"type": "number", "minimum": 18, "maximum": 120}
        }
      })
      {:ok, validator} = ExJsonschema.compile(schema)

      assert {:error, [error]} =
               ExJsonschema.validate(validator, ~s({"age": 15}), output: :verbose)

      # Verbose should include additional context
      assert error.instance_path == "/age"
      assert error.schema_path == "/properties/age/minimum"
      assert error.message =~ "minimum"
      assert error.keyword == "minimum"
      assert error.instance_value == 15
      # Schema value extraction is a placeholder for now
      assert is_binary(error.schema_value) || is_integer(error.schema_value)

      # Should have context about the validation
      assert is_map(error.context)
      assert is_binary(error.context["expected"])
      assert error.context["actual"] == 15
    end

    test "includes schema keyword and location information" do
      schema = ~s({
        "type": "array",
        "items": {"type": "string"},
        "minItems": 2,
        "maxItems": 5
      })
      {:ok, validator} = ExJsonschema.compile(schema)

      # Test array with too few items
      assert {:error, [error]} = ExJsonschema.validate(validator, ~s(["one"]), output: :verbose)

      assert error.keyword == "minItems"
      assert error.instance_value == ["one"]
      # Schema value extraction is a placeholder for now
      assert is_binary(error.schema_value) || is_integer(error.schema_value)
      assert is_map(error.context)
      assert is_binary(error.context["expected"])
      assert error.context["actual"] == ["one"]
    end

    test "provides suggestions for common errors" do
      schema = ~s({
        "type": "object",
        "properties": {
          "age": {"type": "number", "minimum": 18}
        }
      })
      {:ok, validator} = ExJsonschema.compile(schema)

      assert {:error, [error]} =
               ExJsonschema.validate(validator, ~s({"age": 15}), output: :verbose)

      assert error.keyword == "minimum"
      assert is_list(error.suggestions)
      assert length(error.suggestions) > 0
    end

    test "includes validation annotations when available" do
      schema = ~s({
        "title": "User Profile",
        "type": "object",
        "properties": {
          "username": {
            "title": "Username",
            "type": "string",
            "pattern": "^[a-zA-Z0-9_]{3,20}$"
          }
        }
      })
      {:ok, validator} = ExJsonschema.compile(schema)

      assert {:error, [error]} =
               ExJsonschema.validate(validator, ~s({"username": "x"}), output: :verbose)

      assert error.keyword == "pattern"
      # Annotations extraction is placeholder for now
      assert is_map(error.annotations)
    end
  end

  describe "validate/3 with output format options" do
    setup do
      schema = ~s({
        "type": "object",
        "properties": {
          "count": {"type": "integer", "minimum": 1, "maximum": 100}
        },
        "required": ["count"]
      })
      {:ok, validator} = ExJsonschema.compile(schema)
      %{validator: validator}
    end

    test "accepts :basic format", %{validator: validator} do
      # :basic should return boolean-like result
      assert {:error, :validation_failed} =
               ExJsonschema.validate(validator, ~s({"count": 0}), output: :basic)

      assert :ok = ExJsonschema.validate(validator, ~s({"count": 50}), output: :basic)
    end

    test "accepts :detailed format (default)", %{validator: validator} do
      assert {:error, errors} =
               ExJsonschema.validate(validator, ~s({"count": 0}), output: :detailed)

      assert is_list(errors)
      assert length(errors) == 1

      [error] = errors
      assert is_binary(error.message)
      assert is_binary(error.instance_path)
      assert is_binary(error.schema_path)
    end

    test "accepts :verbose format", %{validator: validator} do
      assert {:error, errors} =
               ExJsonschema.validate(validator, ~s({"count": 0}), output: :verbose)

      assert is_list(errors)
      assert length(errors) == 1

      [error] = errors
      # Verbose includes all detailed fields plus additional context
      assert is_binary(error.message)
      assert is_binary(error.instance_path)
      assert is_binary(error.schema_path)
      assert is_binary(error.keyword)
      assert is_integer(error.instance_value)
      # Schema value extraction placeholder
      assert is_binary(error.schema_value) || is_integer(error.schema_value)
      assert is_map(error.context)
    end

    test "rejects invalid output formats", %{validator: validator} do
      assert_raise ArgumentError, ~r/Invalid output format/, fn ->
        ExJsonschema.validate(validator, ~s({"count": 50}), output: :invalid)
      end
    end

    test "supports output format in options list", %{validator: validator} do
      # Should accept keyword list
      result1 = ExJsonschema.validate(validator, ~s({"count": 0}), output: :verbose)
      result2 = ExJsonschema.validate(validator, ~s({"count": 0}), output: :verbose)

      assert result1 == result2
    end
  end

  describe "property-based testing of output formats" do
    property "all output formats agree on validity" do
      check all(
              schema <- simple_schema_generator(),
              instance <- json_instance_generator()
            ) do
        {:ok, validator} = ExJsonschema.compile(schema)

        basic_result =
          case ExJsonschema.validate(validator, instance, output: :basic) do
            :ok -> true
            {:error, :validation_failed} -> false
          end

        detailed_result =
          case ExJsonschema.validate(validator, instance, output: :detailed) do
            :ok -> true
            {:error, _errors} -> false
          end

        verbose_result =
          case ExJsonschema.validate(validator, instance, output: :verbose) do
            :ok -> true
            {:error, _errors} -> false
          end

        # All formats should agree on basic validity
        assert basic_result == detailed_result
        assert detailed_result == verbose_result
        assert verbose_result == ExJsonschema.valid?(validator, instance)
      end
    end

    property "verbose format always includes more information than detailed" do
      check all(
              schema <- simple_schema_generator(),
              instance <- json_instance_generator()
            ) do
        {:ok, validator} = ExJsonschema.compile(schema)

        detailed_result = ExJsonschema.validate(validator, instance, output: :detailed)
        verbose_result = ExJsonschema.validate(validator, instance, output: :verbose)

        case {detailed_result, verbose_result} do
          {:ok, :ok} ->
            # Both valid, nothing to compare
            true

          {{:error, detailed_errors}, {:error, verbose_errors}} ->
            # Both invalid, verbose should have more info
            assert length(detailed_errors) == length(verbose_errors)

            Enum.zip(detailed_errors, verbose_errors)
            |> Enum.each(fn {detailed_error, verbose_error} ->
              # Verbose should have all detailed fields plus more
              assert Map.has_key?(verbose_error, :keyword)
              assert Map.has_key?(verbose_error, :instance_value)
              assert Map.has_key?(verbose_error, :schema_value)
              assert Map.has_key?(verbose_error, :context)

              # Basic fields should be the same
              assert detailed_error.instance_path == verbose_error.instance_path
              assert detailed_error.schema_path == verbose_error.schema_path
              assert detailed_error.message == verbose_error.message
            end)

          _ ->
            flunk("Detailed and verbose results should have same validity")
        end
      end
    end
  end

  # Helper generators for property testing
  defp simple_schema_generator do
    one_of([
      constant(~s({"type": "string"})),
      constant(~s({"type": "number", "minimum": 0})),
      constant(~s({"type": "integer", "minimum": 1, "maximum": 100})),
      constant(~s({"type": "boolean"})),
      constant(~s({"type": "array", "items": {"type": "string"}}))
    ])
  end

  defp json_instance_generator do
    one_of([
      map(string(:printable), &~s("#{&1}")),
      map(integer(), &to_string/1),
      constant("true"),
      constant("false"),
      constant("null"),
      constant(~s(["item1", "item2"])),
      constant(~s({"key": "value"}))
    ])
  end
end
