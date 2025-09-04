defmodule ExJsonschema.ErrorFormattingIntegrationTest do
  use ExUnit.Case, async: true

  describe "error formatting integration with real validation errors" do
    test "formats real validation errors in all formats" do
      # Create a schema that will generate multiple validation errors
      schema = ~s({
        "type": "object",
        "properties": {
          "name": {
            "type": "string",
            "minLength": 2
          },
          "age": {
            "type": "number",
            "minimum": 18,
            "maximum": 99
          },
          "email": {
            "type": "string",
            "format": "email"
          }
        },
        "required": ["name", "age", "email"]
      })

      # Compile the schema
      {:ok, validator} = ExJsonschema.compile(schema)
      
      # Create JSON that will fail validation in multiple ways
      invalid_json = ~s({
        "name": "x",
        "age": 15,
        "email": "not-an-email"
      })

      # Validate and get errors  
      {:error, errors} = ExJsonschema.validate(validator, invalid_json, output: :verbose)
      
      # Should have multiple errors
      assert length(errors) >= 2
      
      # Test human format
      human_result = ExJsonschema.format_errors(errors, :human)
      assert is_binary(human_result)
      assert human_result =~ "Validation Error" 
      assert human_result =~ "/name"
      assert human_result =~ "/age"
      
      # Test JSON format
      json_result = ExJsonschema.format_errors(errors, :json)
      assert is_binary(json_result)
      parsed = Jason.decode!(json_result)
      assert is_list(parsed)
      assert length(parsed) >= 2
      
      # Test table format
      table_result = ExJsonschema.format_errors(errors, :table)
      assert is_binary(table_result)
      assert table_result =~ "Path"
      assert table_result =~ "Error"
      assert table_result =~ "/name"
      assert table_result =~ "/age"
      
      # Test markdown format
      markdown_result = ExJsonschema.format_errors(errors, :markdown)
      assert is_binary(markdown_result)
      assert markdown_result =~ "## Validation Errors"
      assert markdown_result =~ "### Error"
      assert markdown_result =~ "**Location:**"
      
      # Test LLM format
      llm_result = ExJsonschema.format_errors(errors, :llm)
      assert is_binary(llm_result)
      assert llm_result =~ "failed validation"
      assert llm_result =~ "At location"
    end

    test "convenience function works identically to direct module usage" do
      schema = ~s({"type": "string", "minLength": 5})
      {:ok, validator} = ExJsonschema.compile(schema)
      {:error, errors} = ExJsonschema.validate(validator, ~s("hi"))
      
      # Both should produce identical results
      direct_result = ExJsonschema.ErrorFormatter.format(errors, :human)
      convenience_result = ExJsonschema.format_errors(errors, :human)
      
      assert direct_result == convenience_result
    end

    test "formatting handles empty error lists gracefully" do
      assert ExJsonschema.format_errors([], :human) == "No validation errors found."
      assert ExJsonschema.format_errors([], :json) == "[]"
      assert ExJsonschema.format_errors([], :table) == "No validation errors found."
      assert ExJsonschema.format_errors([], :markdown) == "## Validation Results\n\nNo validation errors found."
      assert ExJsonschema.format_errors([], :llm) == "VALIDATION_STATUS: SUCCESS\nNo validation errors detected in the JSON document."
    end

    test "formatting with options works in integration" do
      schema = ~s({"type": "number", "minimum": 10})
      {:ok, validator} = ExJsonschema.compile(schema)
      {:error, errors} = ExJsonschema.validate(validator, ~s("not_a_number"), output: :verbose)
      
      # Test with various options
      human_no_color = ExJsonschema.format_errors(errors, :human, color: false)
      refute human_no_color =~ "\e["
      
      json_pretty = ExJsonschema.format_errors(errors, :json, pretty: true)
      assert json_pretty =~ "\n"
      
      table_compact = ExJsonschema.format_errors(errors, :table, compact: true)
      assert is_binary(table_compact)
      
      # Test new format options
      markdown_with_toc = ExJsonschema.format_errors(errors, :markdown, include_toc: true, heading_level: 1)
      assert markdown_with_toc =~ "# Validation Errors"
      assert markdown_with_toc =~ "## Table of Contents"
      
      llm_structured = ExJsonschema.format_errors(errors, :llm, structured: true, include_schema_context: false)
      assert llm_structured =~ "VALIDATION_STATUS: FAILED"
      refute llm_structured =~ "SCHEMA_PATH:"
    end
    
    test "handles complex nested schema errors" do
      schema = ~s({
        "type": "object",
        "properties": {
          "users": {
            "type": "array",
            "items": {
              "type": "object",
              "properties": {
                "profile": {
                  "type": "object",
                  "properties": {
                    "settings": {
                      "type": "object",
                      "properties": {
                        "theme": {"type": "string", "enum": ["light", "dark"]}
                      },
                      "required": ["theme"]
                    }
                  },
                  "required": ["settings"]
                }
              },
              "required": ["profile"]
            }
          }
        },
        "required": ["users"]
      })

      invalid_json = ~s({
        "users": [
          {"profile": {"settings": {"theme": "invalid"}}},
          {"profile": {}}
        ]
      })

      {:ok, validator} = ExJsonschema.compile(schema)
      {:error, errors} = ExJsonschema.validate(validator, invalid_json, output: :verbose)
      
      # Should handle deep nesting gracefully
      result = ExJsonschema.format_errors(errors, :human)
      assert result =~ "users"
      
      json_result = ExJsonschema.format_errors(errors, :json)
      parsed = Jason.decode!(json_result) 
      assert is_list(parsed)
      assert length(parsed) > 0
    end
  end
end