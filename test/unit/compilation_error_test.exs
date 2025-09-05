defmodule ExJsonschema.CompilationErrorTest do
  use ExUnit.Case, async: true

  alias ExJsonschema.CompilationError

  describe "from_map/1" do
    test "creates error from complete map with details" do
      map = %{
        "type" => "json_parse_error",
        "message" => "Invalid JSON syntax",
        "details" => "Expected closing bracket at line 5"
      }

      error = CompilationError.from_map(map)

      assert %CompilationError{
               type: :json_parse_error,
               message: "Invalid JSON syntax",
               details: "Expected closing bracket at line 5"
             } = error
    end

    test "creates error from map without details" do
      map = %{
        "type" => "compilation_error",
        "message" => "Schema compilation failed"
      }

      error = CompilationError.from_map(map)

      assert %CompilationError{
               type: :compilation_error,
               message: "Schema compilation failed",
               details: nil
             } = error
    end

    test "maps all known error types correctly" do
      error_types = [
        {"json_parse_error", :json_parse_error},
        {"schema_validation_error", :schema_validation_error},
        {"compilation_error", :compilation_error},
        {"options_error", :options_error},
        {"detection_error", :detection_error},
        {"validation_error", :validation_error}
      ]

      for {string_type, atom_type} <- error_types do
        map = %{"type" => string_type, "message" => "test message"}
        error = CompilationError.from_map(map)
        assert error.type == atom_type
        assert error.message == "test message"
      end
    end

    test "defaults to :compilation_error for unknown types" do
      map = %{
        "type" => "unknown_error_type",
        "message" => "Some error"
      }

      error = CompilationError.from_map(map)

      assert %CompilationError{
               type: :compilation_error,
               message: "Some error",
               details: nil
             } = error
    end
  end

  describe "from_options_error/1" do
    test "creates options error with proper structure" do
      reason = "Invalid draft version: :invalid"

      error = CompilationError.from_options_error(reason)

      assert %CompilationError{
               type: :options_error,
               message: "Invalid compilation options",
               details: "Invalid draft version: :invalid"
             } = error
    end
  end

  describe "from_detection_error/1" do
    test "creates detection error with proper structure" do
      reason = "Failed to parse schema JSON"

      error = CompilationError.from_detection_error(reason)

      assert %CompilationError{
               type: :detection_error,
               message: "Draft detection failed",
               details: "Failed to parse schema JSON"
             } = error
    end
  end

  describe "from_validation_error/1" do
    test "creates validation error with proper structure" do
      reason = "Schema specifies draft7 but options specify draft4"

      error = CompilationError.from_validation_error(reason)

      assert %CompilationError{
               type: :validation_error,
               message: "Compilation validation failed",
               details: "Schema specifies draft7 but options specify draft4"
             } = error
    end
  end

  describe "String.Chars implementation" do
    test "formats error without details" do
      error = %CompilationError{
        type: :json_parse_error,
        message: "Invalid JSON",
        details: nil
      }

      string_result = to_string(error)
      assert string_result == "CompilationError(json_parse_error): Invalid JSON"
    end

    test "formats error with details" do
      error = %CompilationError{
        type: :compilation_error,
        message: "Schema compilation failed",
        details: "Invalid schema property 'unknownKeyword'"
      }

      string_result = to_string(error)

      expected =
        "CompilationError(compilation_error): Schema compilation failed\nDetails: Invalid schema property 'unknownKeyword'"

      assert string_result == expected
    end

    test "handles all error types in string formatting" do
      error_types = [
        :json_parse_error,
        :schema_validation_error,
        :compilation_error,
        :options_error,
        :detection_error,
        :validation_error
      ]

      for error_type <- error_types do
        error = %CompilationError{
          type: error_type,
          message: "Test message",
          details: nil
        }

        string_result = to_string(error)
        assert String.contains?(string_result, "CompilationError(#{error_type})")
        assert String.contains?(string_result, "Test message")
      end
    end
  end

  describe "Inspect implementation" do
    test "formats error for inspection" do
      error = %CompilationError{
        type: :json_parse_error,
        message: "Invalid JSON syntax",
        details: "Some details"
      }

      inspect_result = inspect(error)
      assert inspect_result == "#CompilationError<json_parse_error: Invalid JSON syntax>"
    end

    test "handles all error types in inspect formatting" do
      error_types = [
        :json_parse_error,
        :schema_validation_error,
        :compilation_error,
        :options_error,
        :detection_error,
        :validation_error
      ]

      for error_type <- error_types do
        error = %CompilationError{
          type: error_type,
          message: "Test message",
          details: "Some details"
        }

        inspect_result = inspect(error)
        assert String.contains?(inspect_result, "#CompilationError<#{error_type}")
        assert String.contains?(inspect_result, "Test message>")
      end
    end
  end

  describe "error type validation" do
    test "struct has correct type definition" do
      error = %CompilationError{
        type: :json_parse_error,
        message: "test",
        details: "test details"
      }

      assert is_struct(error, CompilationError)

      assert error.type in [
               :json_parse_error,
               :schema_validation_error,
               :compilation_error,
               :options_error,
               :detection_error,
               :validation_error
             ]

      assert is_binary(error.message)
      assert error.details == nil or is_binary(error.details)
    end
  end
end
