defmodule ExJsonschema.BestPracticesTest do
  use ExUnit.Case, async: true

  describe "M4.5: Best Practices Validation Features" do
    test "strict format validation enforces format constraints" do
      schema = ~s({
        "type": "string",
        "format": "email"
      })

      {:ok, validator} = ExJsonschema.compile(schema, validate_formats: true)

      # Should reject invalid email format
      assert {:error, _errors} = ExJsonschema.validate(validator, ~s("not-an-email"))

      # Should accept valid email format
      assert :ok = ExJsonschema.validate(validator, ~s("test@example.com"))
    end

    test "lenient format validation (default) ignores format constraints" do
      schema = ~s({
        "type": "string",
        "format": "email"
      })

      {:ok, validator} = ExJsonschema.compile(schema, validate_formats: false)

      # Should accept invalid email when format validation disabled
      assert :ok = ExJsonschema.validate(validator, ~s("not-an-email"))
    end

    test "regex engine selection affects pattern validation" do
      schema = """
      {
        "type": "string",
        "pattern": "^[a-zA-Z0-9]+$"
      }
      """

      # Test with fancy_regex (default)
      {:ok, fancy_validator} = ExJsonschema.compile(schema, regex_engine: :fancy_regex)
      assert :ok = ExJsonschema.validate(fancy_validator, ~s("abc123"))
      assert {:error, _} = ExJsonschema.validate(fancy_validator, ~s("abc-123"))

      # Test with safer regex engine
      {:ok, safe_validator} = ExJsonschema.compile(schema, regex_engine: :regex)
      assert :ok = ExJsonschema.validate(safe_validator, ~s("abc123"))
      assert {:error, _} = ExJsonschema.validate(safe_validator, ~s("abc-123"))
    end

    test "draft-specific compilation works through options builder" do
      schema = ~s({
        "type": "string",
        "format": "email"
      })

      # Compile with specific draft and strict validation
      {:ok, validator} =
        ExJsonschema.compile(schema,
          draft: :draft7,
          validate_formats: true,
          regex_engine: :regex
        )

      assert :ok = ExJsonschema.validate(validator, ~s("test@example.com"))
      assert {:error, _} = ExJsonschema.validate(validator, ~s("invalid-email"))
    end

    test "all validation options pass through correctly" do
      schema = """
      {
        "type": "object",
        "properties": {
          "email": {"type": "string", "format": "email"},
          "pattern": {"type": "string", "pattern": "^test"}
        }
      }
      """

      {:ok, validator} =
        ExJsonschema.compile(schema,
          draft: :draft202012,
          validate_formats: true,
          ignore_unknown_formats: false,
          collect_annotations: true,
          regex_engine: :fancy_regex,
          resolve_external_refs: false,
          stop_on_first_error: false
        )

      # Valid data should pass
      valid_data = ~s({
        "email": "user@example.com",
        "pattern": "test123"
      })
      assert :ok = ExJsonschema.validate(validator, valid_data)

      # Invalid data should fail format validation
      invalid_data = ~s({
        "email": "not-an-email",
        "pattern": "fail123"
      })
      assert {:error, errors} = ExJsonschema.validate(validator, invalid_data)
      assert length(errors) >= 1
    end

    test "security-focused regex configuration" do
      # Pattern that could potentially cause backtracking issues
      schema = """
      {
        "type": "string",
        "pattern": "^(a+)+$"
      }
      """

      # Both engines should handle this, but regex engine provides better DoS protection
      {:ok, safe_validator} = ExJsonschema.compile(schema, regex_engine: :regex)
      assert {:error, _} = ExJsonschema.validate(safe_validator, ~s("aaaaaaaaaaaaaaaaaX"))

      {:ok, fancy_validator} = ExJsonschema.compile(schema, regex_engine: :fancy_regex)
      assert {:error, _} = ExJsonschema.validate(fancy_validator, ~s("aaaaaaaaaaaaaaaaaX"))
    end

    test "options builder provides single transformation point" do
      # Verify that all compilation goes through the options builder
      schema = ~s({"type": "string"})

      # Different option combinations should all work
      option_combinations = [
        [draft: :draft4],
        [draft: :draft7, validate_formats: true],
        [draft: :draft202012, regex_engine: :regex],
        [validate_formats: true, regex_engine: :fancy_regex, stop_on_first_error: true]
      ]

      for options <- option_combinations do
        assert {:ok, _validator} = ExJsonschema.compile(schema, options)
      end
    end
  end
end
