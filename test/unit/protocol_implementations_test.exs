defmodule ExJsonschema.ProtocolImplementationsTest do
  use ExUnit.Case, async: true

  alias ExJsonschema.{ValidationError, CompilationError}

  describe "ValidationError protocol implementations" do
    setup do
      error = %ValidationError{
        instance_path: "/user/age",
        schema_path: "/properties/user/properties/age/minimum",
        message: "15 is less than the minimum of 18",
        keyword: "minimum",
        instance_value: 15,
        schema_value: 18,
        context: %{"expected" => "value >= 18", "actual" => 15},
        annotations: %{"annotation" => "test"},
        suggestions: ["Ensure age is at least 18"]
      }

      %{error: error}
    end

    test "String.Chars implementation", %{error: error} do
      string_result = to_string(error)
      assert is_binary(string_result)
      assert String.contains?(string_result, error.message)
      assert String.contains?(string_result, error.instance_path)
    end

    test "Inspect implementation", %{error: error} do
      inspect_result = inspect(error)
      assert is_binary(inspect_result)
      assert String.starts_with?(inspect_result, "#ValidationError<")
    end

    test "String.Chars handles minimal error" do
      minimal_error = %ValidationError{
        instance_path: "",
        schema_path: "/type",
        message: "Value is not a string"
      }

      string_result = to_string(minimal_error)
      assert is_binary(string_result)
      assert String.contains?(string_result, "Value is not a string")
    end
  end

  describe "CompilationError protocol implementations" do
    test "String.Chars implementation with details" do
      error = %CompilationError{
        type: :json_parse_error,
        message: "Invalid JSON syntax",
        details: "Missing closing bracket at line 5"
      }

      string_result = to_string(error)
      assert String.contains?(string_result, "CompilationError(json_parse_error)")
      assert String.contains?(string_result, "Invalid JSON syntax")
      assert String.contains?(string_result, "Missing closing bracket at line 5")
    end

    test "String.Chars implementation without details" do
      error = %CompilationError{
        type: :compilation_error,
        message: "Schema validation failed",
        details: nil
      }

      string_result = to_string(error)
      assert String.contains?(string_result, "CompilationError(compilation_error)")
      assert String.contains?(string_result, "Schema validation failed")
      refute String.contains?(string_result, "\nDetails:")
    end

    test "Inspect implementation" do
      error = %CompilationError{
        type: :options_error,
        message: "Invalid options provided",
        details: "Unknown option 'invalid_key'"
      }

      inspect_result = inspect(error)
      assert String.contains?(inspect_result, "#CompilationError<options_error:")
      assert String.contains?(inspect_result, "Invalid options provided>")
    end
  end

  describe "ValidationError.Exception" do
    test "exception creation from single error" do
      error = %ValidationError{
        instance_path: "/name",
        schema_path: "/properties/name/type",
        message: "Expected string but got number"
      }

      exception = ExJsonschema.ValidationError.Exception.exception(errors: [error])

      assert exception.__struct__ == ExJsonschema.ValidationError.Exception
      assert exception.errors == [error]
    end

    test "exception creation from multiple errors" do
      errors = [
        %ValidationError{
          instance_path: "/name",
          schema_path: "/properties/name/type",
          message: "Type error"
        },
        %ValidationError{
          instance_path: "/age",
          schema_path: "/properties/age/minimum",
          message: "Minimum error"
        }
      ]

      exception = ExJsonschema.ValidationError.Exception.exception(errors: errors)

      assert exception.errors == errors
      assert length(exception.errors) == 2
    end

    test "exception message formatting" do
      errors = [
        %ValidationError{
          instance_path: "/name",
          schema_path: "/properties/name/type",
          message: "Type error"
        },
        %ValidationError{
          instance_path: "/age",
          schema_path: "/properties/age/minimum",
          message: "Minimum error"
        }
      ]

      exception = ExJsonschema.ValidationError.Exception.exception(errors: errors)
      message = Exception.message(exception)

      assert is_binary(message)
      assert String.contains?(message, "JSON Schema validation failed")
      # Should contain information about the number of errors  
      assert String.contains?(message, "2")
    end
  end
end
