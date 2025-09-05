defmodule ExJsonschema.ErrorFormatterTest do
  use ExUnit.Case, async: true

  alias ExJsonschema.{ErrorFormatter, ValidationError}

  # Test data setup
  defp sample_error do
    %ValidationError{
      instance_path: "/user/age",
      schema_path: "/properties/user/properties/age/minimum",
      message: "15 is less than the minimum of 18",
      keyword: "minimum",
      instance_value: 15,
      schema_value: 18,
      context: %{
        "instance_path" => "/user/age",
        "schema_path" => "/properties/user/properties/age/minimum",
        "minimum_value" => 18,
        "actual_value" => 15,
        "expected" => "value >= 18",
        "actual" => 15
      },
      annotations: %{
        "error_keyword" => "minimum",
        "validation_failed_at" => "/user/age"
      },
      suggestions: ["Value must be >= 18", "Consider using a larger number"]
    }
  end

  defp simple_error do
    %ValidationError{
      instance_path: "/name",
      schema_path: "/properties/name/type",
      message: "123 is not of type string",
      keyword: "type",
      instance_value: 123,
      schema_value: "string",
      context: nil,
      annotations: nil,
      suggestions: nil
    }
  end

  defp nested_error do
    %ValidationError{
      instance_path: "/data/items/0/value",
      schema_path: "/properties/data/properties/items/items/properties/value/type",
      message: "null is not of type number",
      keyword: "type",
      instance_value: nil,
      schema_value: "number",
      context: %{
        "expected_type" => "number",
        "actual_type" => "null"
      },
      annotations: %{
        "schema_location" => "deeply nested"
      },
      suggestions: ["Provide a numeric value instead of null"]
    }
  end

  describe "format/2" do
    test "requires errors list" do
      assert_raise ArgumentError, ~r/errors must be a list/, fn ->
        ErrorFormatter.format(nil, :human)
      end

      assert_raise ArgumentError, ~r/errors must be a list/, fn ->
        ErrorFormatter.format("not a list", :human)
      end
    end

    test "requires valid format" do
      assert_raise ArgumentError, ~r/Invalid format/, fn ->
        ErrorFormatter.format([], :invalid_format)
      end
    end

    test "handles empty errors list" do
      assert ErrorFormatter.format([], :human) == "No validation errors found."
      assert ErrorFormatter.format([], :json) == "[]"
      assert ErrorFormatter.format([], :table) == "No validation errors found."

      assert ErrorFormatter.format([], :markdown) ==
               "## Validation Results\n\nNo validation errors found."

      assert ErrorFormatter.format([], :llm) ==
               "VALIDATION_STATUS: SUCCESS\nNo validation errors detected in the JSON document."
    end

    test "supports all format options" do
      errors = [simple_error()]

      # Should not raise for all available formats
      assert is_binary(ErrorFormatter.format(errors, :human))
      assert is_binary(ErrorFormatter.format(errors, :json))
      assert is_binary(ErrorFormatter.format(errors, :table))
      assert is_binary(ErrorFormatter.format(errors, :markdown))
      assert is_binary(ErrorFormatter.format(errors, :llm))
    end
  end

  describe "human format" do
    test "formats single error readably" do
      error = sample_error()
      result = ErrorFormatter.format([error], :human)

      assert result =~ "Validation Error"
      assert result =~ "/user/age"
      assert result =~ "15 is less than the minimum of 18"
      assert result =~ "Value must be >= 18"
    end

    test "formats multiple errors with numbering" do
      errors = [sample_error(), simple_error()]
      result = ErrorFormatter.format(errors, :human)

      assert result =~ "2 Validation Errors Found"
      assert result =~ "Error 1:"
      assert result =~ "Error 2:"
      assert result =~ "/user/age"
      assert result =~ "/name"
    end

    test "includes context information when available" do
      error = sample_error()
      result = ErrorFormatter.format([error], :human)

      assert result =~ "expected:"
      assert result =~ "value >= 18"
      assert result =~ "actual:"
      assert result =~ "15"
    end

    test "includes suggestions when available" do
      error = sample_error()
      result = ErrorFormatter.format([error], :human)

      assert result =~ "Suggestions:"
      assert result =~ "Value must be >= 18"
      assert result =~ "Consider using a larger number"
    end

    test "handles errors without context gracefully" do
      error = simple_error()
      result = ErrorFormatter.format([error], :human)

      assert result =~ "Validation Error"
      assert result =~ "/name"
      assert result =~ "123 is not of type string"
      refute result =~ "Context:"
      refute result =~ "Suggestions:"
    end

    test "handles deeply nested paths" do
      error = nested_error()
      result = ErrorFormatter.format([error], :human)

      assert result =~ "/data/items/0/value"
      assert result =~ "null is not of type number"
    end

    test "truncates very long error lists" do
      many_errors =
        Enum.map(1..25, fn i ->
          %ValidationError{
            instance_path: "/item_#{i}",
            schema_path: "/properties/item_#{i}/type",
            message: "invalid value #{i}",
            keyword: "type"
          }
        end)

      result = ErrorFormatter.format(many_errors, :human)
      # Default max_errors is 20, so should truncate at 20 and show "... and 5 more errors"
      assert result =~ "20 Validation Errors Found"
      assert result =~ "... and 5 more errors"
    end
  end

  describe "json format" do
    test "produces valid JSON for single error" do
      error = sample_error()
      result = ErrorFormatter.format([error], :json)

      parsed = Jason.decode!(result)
      assert is_list(parsed)
      assert length(parsed) == 1

      [error_json] = parsed
      assert error_json["instance_path"] == "/user/age"
      assert error_json["message"] == "15 is less than the minimum of 18"
      assert error_json["keyword"] == "minimum"
    end

    test "includes all fields when present" do
      error = sample_error()
      result = ErrorFormatter.format([error], :json)

      [error_json] = Jason.decode!(result)
      assert error_json["instance_value"] == 15
      assert error_json["schema_value"] == 18
      assert is_map(error_json["context"])
      assert is_map(error_json["annotations"])
      assert is_list(error_json["suggestions"])
    end

    test "omits null fields for cleaner output" do
      error = simple_error()
      result = ErrorFormatter.format([error], :json)

      [error_json] = Jason.decode!(result)
      refute Map.has_key?(error_json, "context")
      refute Map.has_key?(error_json, "annotations")
      refute Map.has_key?(error_json, "suggestions")
    end

    test "formats multiple errors as JSON array" do
      errors = [sample_error(), simple_error()]
      result = ErrorFormatter.format(errors, :json)

      parsed = Jason.decode!(result)
      assert length(parsed) == 2
      assert is_map(hd(parsed))
    end

    test "handles complex context data structures" do
      error = %ValidationError{
        instance_path: "/complex",
        schema_path: "/complex",
        message: "complex validation failed",
        context: %{
          "nested" => %{"array" => [1, 2, 3]},
          "boolean" => true,
          "null_value" => nil
        }
      }

      result = ErrorFormatter.format([error], :json)
      [error_json] = Jason.decode!(result)
      assert error_json["context"]["nested"]["array"] == [1, 2, 3]
      assert error_json["context"]["boolean"] == true
      assert error_json["context"]["null_value"] == nil
    end
  end

  describe "table format" do
    test "creates readable table for single error" do
      error = sample_error()
      result = ErrorFormatter.format([error], :table)

      assert result =~ "Path"
      assert result =~ "Error"
      assert result =~ "Keyword"
      assert result =~ "/user/age"
      assert result =~ "minimum"
      assert result =~ "15 is less than the minimum of 18"
    end

    test "aligns columns properly for multiple errors" do
      errors = [
        %ValidationError{
          instance_path: "/short",
          schema_path: "/short",
          message: "short message",
          keyword: "type"
        },
        %ValidationError{
          instance_path: "/very/long/nested/path/here",
          schema_path: "/very/long/schema/path",
          message: "this is a much longer error message for testing alignment",
          keyword: "minimum"
        }
      ]

      result = ErrorFormatter.format(errors, :table)
      lines = String.split(result, "\n")

      # Check that we have header and separator lines
      assert length(lines) >= 4

      # Check for proper table structure
      assert Enum.any?(lines, &String.contains?(&1, "|"))
      assert result =~ "/short"
      assert result =~ "/very/long/nested/path/here"
    end

    test "truncates long messages in table format" do
      error = %ValidationError{
        instance_path: "/test",
        schema_path: "/test",
        message: String.duplicate("very long error message ", 20),
        keyword: "pattern"
      }

      result = ErrorFormatter.format([error], :table)
      lines = String.split(result, "\n")

      # No line should be excessively long
      max_line_length = lines |> Enum.map(&String.length/1) |> Enum.max()
      assert max_line_length < 150
    end

    test "handles missing optional fields in table" do
      error = %ValidationError{
        instance_path: "/test",
        schema_path: "/test",
        message: "test message",
        keyword: nil,
        instance_value: nil,
        schema_value: nil
      }

      result = ErrorFormatter.format([error], :table)
      assert result =~ "/test"
      assert result =~ "test message"
      # Should handle nil keyword gracefully
      assert result =~ "-" || result =~ "N/A" || result =~ ""
    end

    test "shows summary for many errors" do
      many_errors =
        Enum.map(1..15, fn i ->
          %ValidationError{
            instance_path: "/item#{i}",
            schema_path: "/item#{i}",
            message: "error #{i}",
            keyword: "type"
          }
        end)

      result = ErrorFormatter.format(many_errors, :table)
      # Should show all 15 errors in table format since it's within the default limit
      assert result =~ "/item1"
      assert result =~ "/item15"
      assert result =~ "error 1"
      assert result =~ "error 15"
    end
  end

  describe "format/3 with options" do
    test "supports color option for human format" do
      error = simple_error()

      with_color = ErrorFormatter.format([error], :human, color: true)
      without_color = ErrorFormatter.format([error], :human, color: false)

      # With color should contain ANSI escape codes
      assert with_color =~ "\e["
      # Without color should not
      refute without_color =~ "\e["
    end

    test "supports max_errors option" do
      errors =
        Enum.map(1..10, fn i ->
          %ValidationError{
            instance_path: "/item#{i}",
            message: "error #{i}",
            keyword: "type"
          }
        end)

      result = ErrorFormatter.format(errors, :human, max_errors: 3)
      assert result =~ "Error 1:"
      assert result =~ "Error 2:"
      assert result =~ "Error 3:"
      assert result =~ "... and 7 more errors"
    end

    test "supports compact option for table format" do
      errors = [sample_error(), simple_error()]

      compact = ErrorFormatter.format(errors, :table, compact: true)
      normal = ErrorFormatter.format(errors, :table, compact: false)

      # Compact should have fewer lines
      compact_lines = length(String.split(compact, "\n"))
      normal_lines = length(String.split(normal, "\n"))
      assert compact_lines <= normal_lines
    end

    test "supports pretty option for JSON format" do
      error = sample_error()

      pretty = ErrorFormatter.format([error], :json, pretty: true)
      compact = ErrorFormatter.format([error], :json, pretty: false)

      # Pretty should have more whitespace/newlines
      assert String.length(pretty) > String.length(compact)
      assert pretty =~ "\n"
    end

    test "validates option values" do
      error = simple_error()

      assert_raise ArgumentError, fn ->
        ErrorFormatter.format([error], :human, max_errors: -1)
      end

      assert_raise ArgumentError, fn ->
        ErrorFormatter.format([error], :human, color: "not_boolean")
      end
    end

    test "ignores unknown options gracefully" do
      error = simple_error()

      # Should not raise, should ignore unknown options
      result = ErrorFormatter.format([error], :human, unknown_option: true)
      assert is_binary(result)
    end
  end

  describe "integration with ValidationError fields" do
    test "handles all ValidationError field types correctly" do
      error = %ValidationError{
        instance_path: "/test",
        schema_path: "/test/schema",
        message: "test message",
        keyword: "pattern",
        instance_value: %{"nested" => ["array", "data"]},
        schema_value: %{"complex" => true},
        context: %{"key" => "value"},
        annotations: %{"meta" => "data"},
        suggestions: ["suggestion 1", "suggestion 2"]
      }

      # Should handle complex data types in all formats
      human_result = ErrorFormatter.format([error], :human)
      json_result = ErrorFormatter.format([error], :json)
      table_result = ErrorFormatter.format([error], :table)

      assert is_binary(human_result)
      assert is_binary(json_result)
      assert is_binary(table_result)

      # JSON should be parseable
      assert {:ok, _} = Jason.decode(json_result)
    end

    test "preserves unicode and special characters" do
      error = %ValidationError{
        instance_path: "/测试",
        schema_path: "/测试/schema",
        message: "Special chars: éñü, emoji: 🔥",
        keyword: "format",
        suggestions: ["Use ASCII characters", "Consider encoding issues"]
      }

      human_result = ErrorFormatter.format([error], :human)
      json_result = ErrorFormatter.format([error], :json)
      table_result = ErrorFormatter.format([error], :table)

      assert human_result =~ "测试"
      assert human_result =~ "🔥"
      assert json_result =~ "测试"
      assert table_result =~ "测试"
    end
  end

  describe "markdown format" do
    test "creates valid markdown structure" do
      error = sample_error()
      result = ErrorFormatter.format([error], :markdown)

      assert result =~ "## Validation Errors"
      assert result =~ "Found **1** validation error"
      assert result =~ "### Error 1"
      assert result =~ "**Location:** `/user/age`"
      assert result =~ "**Message:** 15 is less than the minimum of 18"
      assert result =~ "**Validation Rule:** `minimum`"
    end

    test "handles multiple errors with proper structure" do
      errors = [sample_error(), simple_error()]
      result = ErrorFormatter.format(errors, :markdown)

      assert result =~ "Found **2** validation errors"
      assert result =~ "### Error 1"
      assert result =~ "### Error 2"
      assert result =~ "/user/age"
      assert result =~ "/name"
    end

    test "includes table of contents when requested" do
      errors = [sample_error(), simple_error()]
      result = ErrorFormatter.format(errors, :markdown, include_toc: true)

      assert result =~ "### Table of Contents"
      assert result =~ "- [Error 1: /user/age (minimum)](#error-1)"
      assert result =~ "- [Error 2: /name (type)](#error-2)"
    end

    test "respects heading level option" do
      error = simple_error()

      result_h1 = ErrorFormatter.format([error], :markdown, heading_level: 1)
      assert result_h1 =~ "# Validation Errors"
      assert result_h1 =~ "## Error 1"

      result_h4 = ErrorFormatter.format([error], :markdown, heading_level: 4)
      assert result_h4 =~ "#### Validation Errors"
      assert result_h4 =~ "##### Error 1"
    end

    test "includes context as JSON code block" do
      error = sample_error()
      result = ErrorFormatter.format([error], :markdown)

      assert result =~ "**Context:**"
      assert result =~ "```json"
      assert result =~ "\"minimum_value\": 18"
      assert result =~ "```"
    end

    test "includes suggestions as bullet list" do
      error = sample_error()
      result = ErrorFormatter.format([error], :markdown)

      assert result =~ "**Suggestions:**"
      assert result =~ "- Value must be >= 18"
      assert result =~ "- Consider using a larger number"
    end

    test "escapes markdown special characters" do
      error = %ValidationError{
        instance_path: "/test",
        message: "Value `*bold*` and _italic_ and [link] failed",
        keyword: "pattern"
      }

      result = ErrorFormatter.format([error], :markdown)
      assert result =~ "Value \\`\\*bold\\*\\` and \\_italic\\_ and \\[link\\] failed"
    end

    test "handles max_errors truncation" do
      many_errors =
        Enum.map(1..10, fn i ->
          %ValidationError{instance_path: "/item#{i}", message: "error #{i}", keyword: "type"}
        end)

      result = ErrorFormatter.format(many_errors, :markdown, max_errors: 3)
      assert result =~ "Found **10** validation errors (showing first 3)"
      assert result =~ "### Error 1"
      assert result =~ "### Error 3"
      refute result =~ "### Error 4"
    end
  end

  describe "llm format" do
    test "creates structured format by default" do
      error = sample_error()
      result = ErrorFormatter.format([error], :llm)

      assert result =~ "The JSON document failed validation with 1 error:"
      assert result =~ "1. At location `/user/age`:"
      assert result =~ "15 is less than the minimum of 18"
      assert result =~ "Suggestions: Value must be >= 18"
    end

    test "supports structured format option" do
      error = sample_error()
      result = ErrorFormatter.format([error], :llm, structured: true)

      assert result =~ "VALIDATION_STATUS: FAILED"
      assert result =~ "ERROR_COUNT: 1"
      assert result =~ "ERROR_1:"
      assert result =~ "  LOCATION: /user/age"
      assert result =~ "  MESSAGE: 15 is less than the minimum of 18"
      assert result =~ "  KEYWORD: minimum"
    end

    test "includes schema context by default" do
      error = sample_error()
      result = ErrorFormatter.format([error], :llm)

      assert result =~ "Schema path: `/properties/user/properties/age/minimum`"
    end

    test "can exclude schema context" do
      error = sample_error()
      result = ErrorFormatter.format([error], :llm, include_schema_context: false)

      refute result =~ "Schema path:"
      refute result =~ "/properties/user/properties/age/minimum"
    end

    test "structured format includes all available fields" do
      error = sample_error()
      result = ErrorFormatter.format([error], :llm, structured: true)

      assert result =~ "SCHEMA_PATH: /properties/user/properties/age/minimum"
      assert result =~ "INVALID_VALUE: 15"
      assert result =~ "EXPECTED_VALUE: 18"
      assert result =~ "SUGGESTIONS:"
      assert result =~ "    - Value must be >= 18"
      assert result =~ "    - Consider using a larger number"
    end

    test "handles multiple errors in prose format" do
      errors = [sample_error(), simple_error()]
      result = ErrorFormatter.format(errors, :llm)

      assert result =~ "failed validation with 2 errors:"
      assert result =~ "1. At location `/user/age`:"
      assert result =~ "2. At location `/name`:"
    end

    test "handles multiple errors in structured format" do
      errors = [sample_error(), simple_error()]
      result = ErrorFormatter.format(errors, :llm, structured: true)

      assert result =~ "ERROR_COUNT: 2"
      assert result =~ "ERROR_1:"
      assert result =~ "ERROR_2:"
    end

    test "shows truncation notice" do
      many_errors =
        Enum.map(1..25, fn i ->
          %ValidationError{instance_path: "/item#{i}", message: "error #{i}", keyword: "type"}
        end)

      prose_result = ErrorFormatter.format(many_errors, :llm, max_errors: 5)
      assert prose_result =~ "failed validation with 25 errors:"
      assert prose_result =~ "Note: 20 additional errors were truncated"

      structured_result =
        ErrorFormatter.format(many_errors, :llm, structured: true, max_errors: 5)

      assert structured_result =~ "ERROR_COUNT: 25"
      assert structured_result =~ "ERRORS_SHOWN: 5"
      assert structured_result =~ "TRUNCATED: 20 additional errors not shown"
    end

    test "handles missing optional fields gracefully" do
      minimal_error = %ValidationError{
        instance_path: "/test",
        message: "validation failed",
        keyword: nil,
        suggestions: nil,
        context: nil
      }

      prose_result = ErrorFormatter.format([minimal_error], :llm)
      assert prose_result =~ "1. At location `/test`: validation failed"

      structured_result = ErrorFormatter.format([minimal_error], :llm, structured: true)
      assert structured_result =~ "KEYWORD: unknown"
      refute structured_result =~ "SUGGESTIONS:"
    end
  end

  describe "available_formats/0" do
    test "returns all available formats" do
      formats = ErrorFormatter.available_formats()

      assert :human in formats
      assert :json in formats
      assert :table in formats
      assert :markdown in formats
      assert :llm in formats
      assert length(formats) == 5
    end

    test "returned formats work with format/2" do
      error = simple_error()

      # All returned formats should be usable
      for format <- ErrorFormatter.available_formats() do
        result = ErrorFormatter.format([error], format)
        assert is_binary(result)
        assert String.length(result) > 0
      end
    end
  end

  describe "format option validation for new formats" do
    test "validates markdown format options" do
      error = simple_error()

      assert_raise ArgumentError, ~r/heading_level must be an integer between 1 and 6/, fn ->
        ErrorFormatter.format([error], :markdown, heading_level: 0)
      end

      assert_raise ArgumentError, ~r/heading_level must be an integer between 1 and 6/, fn ->
        ErrorFormatter.format([error], :markdown, heading_level: 7)
      end

      assert_raise ArgumentError, ~r/include_toc option must be boolean/, fn ->
        ErrorFormatter.format([error], :markdown, include_toc: "yes")
      end
    end

    test "validates llm format options" do
      error = simple_error()

      assert_raise ArgumentError, ~r/include_schema_context option must be boolean/, fn ->
        ErrorFormatter.format([error], :llm, include_schema_context: "yes")
      end

      assert_raise ArgumentError, ~r/structured option must be boolean/, fn ->
        ErrorFormatter.format([error], :llm, structured: "no")
      end
    end

    test "accepts valid options for new formats" do
      error = simple_error()

      # Should not raise
      result1 = ErrorFormatter.format([error], :markdown, heading_level: 3, include_toc: true)
      assert is_binary(result1)

      result2 =
        ErrorFormatter.format([error], :llm, structured: true, include_schema_context: false)

      assert is_binary(result2)
    end
  end
end
