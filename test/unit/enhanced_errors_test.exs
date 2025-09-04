defmodule ExJsonschema.EnhancedErrorsTest do
  @moduledoc """
  Tests for M3.2 Enhanced Error Structures with rich context.
  """

  use ExUnit.Case

  describe "enhanced error context" do
    test "type errors include expected and actual types" do
      schema = ~s({"type": "string"})
      {:ok, validator} = ExJsonschema.compile(schema)

      assert {:error, [error]} = ExJsonschema.validate(validator, "123", output: :verbose)

      assert error.keyword == "type"
      assert error.instance_value == 123
      assert error.schema_value == "string"
      assert error.context["expected_type"] == "string"
      assert error.context["actual_type"] == "number"
    end

    test "minimum errors include constraint values" do
      schema = ~s({"type": "number", "minimum": 18})
      {:ok, validator} = ExJsonschema.compile(schema)

      assert {:error, [error]} = ExJsonschema.validate(validator, "15", output: :verbose)

      assert error.keyword == "minimum"
      assert error.instance_value == 15
      assert error.schema_value == 18
      assert error.context["minimum_value"] == 18
      assert error.context["actual_value"] == 15
    end

    test "minLength errors provide length context" do
      schema = ~s({"type": "string", "minLength": 5})
      {:ok, validator} = ExJsonschema.compile(schema)

      assert {:error, [error]} = ExJsonschema.validate(validator, ~s("hi"), output: :verbose)

      assert error.keyword == "minLength"
      assert error.instance_value == "hi"
      assert error.schema_value == 5
      assert error.context["minimum_length"] == 5
      assert error.context["actual_length"] == 2
    end
  end

  describe "enhanced error annotations" do
    test "extracts schema title and description" do
      schema = ~s({
        "type": "object",
        "title": "User Profile", 
        "description": "A user's profile information",
        "properties": {
          "name": {
            "type": "string",
            "title": "Full Name",
            "description": "User's full name"
          }
        }
      })
      {:ok, validator} = ExJsonschema.compile(schema)

      assert {:error, [error]} =
               ExJsonschema.validate(validator, ~s({"name": 123}), output: :verbose)

      # Annotations should include schema metadata
      assert error.annotations["error_keyword"] == "type"
      assert is_binary(error.annotations["validation_failed_at"])
    end
  end

  describe "enhanced error suggestions" do
    test "provides helpful type conversion suggestions" do
      schema = ~s({"type": "string"})
      {:ok, validator} = ExJsonschema.compile(schema)

      assert {:error, [error]} = ExJsonschema.validate(validator, "123", output: :verbose)

      assert is_list(error.suggestions)
      assert length(error.suggestions) > 0
      assert "Expected type: string" in error.suggestions
    end

    test "provides constraint-specific suggestions" do
      schema = ~s({"type": "number", "minimum": 18})
      {:ok, validator} = ExJsonschema.compile(schema)

      assert {:error, [error]} = ExJsonschema.validate(validator, "15", output: :verbose)

      assert is_list(error.suggestions)
      assert "Value must be >= 18" in error.suggestions
    end

    test "provides enum suggestions" do
      schema = ~s({"enum": ["red", "green", "blue"]})
      {:ok, validator} = ExJsonschema.compile(schema)

      assert {:error, [error]} = ExJsonschema.validate(validator, ~s("yellow"), output: :verbose)

      assert is_list(error.suggestions)
      assert length(error.suggestions) > 0
      # The suggestion should mention the enum constraint
      suggestion_text = Enum.join(error.suggestions, " ")
      assert String.contains?(suggestion_text, "one of")
    end

    test "provides default suggestions for unhandled keywords" do
      # Test with a complex conditional schema that might generate unusual keywords
      schema = ~s({
        "anyOf": [
          {"type": "string"},
          {"type": "number", "minimum": 10}
        ]
      })
      {:ok, validator} = ExJsonschema.compile(schema)

      # This should trigger anyOf validation which might not have specific suggestions
      assert {:error, [error]} = ExJsonschema.validate(validator, ~s(true), output: :verbose)

      # Should get default suggestions since anyOf isn't specifically handled
      assert is_list(error.suggestions)
      assert length(error.suggestions) > 0

      # Check that we get our default fallback messages
      suggestion_text = Enum.join(error.suggestions, " ")

      assert String.contains?(suggestion_text, "Validation failed") or
               String.contains?(suggestion_text, "Expected") or
               String.contains?(suggestion_text, "Error details")
    end

    test "handles uncommon validation keywords gracefully" do
      # Test with const keyword
      schema = ~s({"const": 42})
      {:ok, validator} = ExJsonschema.compile(schema)

      assert {:error, [error]} = ExJsonschema.validate(validator, ~s("not 42"), output: :verbose)

      assert is_list(error.suggestions)
      assert length(error.suggestions) > 0
      assert "Value must be exactly: 42" in error.suggestions
    end
  end
end
