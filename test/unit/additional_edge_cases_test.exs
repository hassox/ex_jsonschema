defmodule ExJsonschema.AdditionalEdgeCasesTest do
  use ExUnit.Case, async: true

  describe "additional edge cases for coverage" do
    test "supported_drafts/0 returns expected drafts" do
      drafts = ExJsonschema.supported_drafts()

      assert is_list(drafts)
      assert :draft4 in drafts
      assert :draft6 in drafts
      assert :draft7 in drafts
      assert :draft201909 in drafts
      assert :draft202012 in drafts
    end

    test "detect_draft handles all edge cases" do
      # Test with invalid JSON
      result = ExJsonschema.detect_draft(~s({"invalid": json}))
      assert {:error, _} = result

      # Test with valid JSON but no schema
      result = ExJsonschema.detect_draft(~s({"type": "string"}))
      assert {:ok, :draft202012} = result

      # Test with map input
      result = ExJsonschema.detect_draft(%{"type" => "string"})
      assert {:ok, :draft202012} = result
    end

    test "validate/3 with invalid options raises proper errors" do
      schema = ~s({"type": "string"})
      {:ok, validator} = ExJsonschema.compile(schema)

      # Test invalid validation option
      assert_raise ArgumentError, ~r/Invalid validation option/, fn ->
        ExJsonschema.validate(validator, ~s("test"), invalid_option: true)
      end

      # Test invalid boolean value
      assert_raise ArgumentError, ~r/must be a boolean/, fn ->
        ExJsonschema.validate(validator, ~s("test"), validate_formats: "not_boolean")
      end
    end

    test "compile with auto draft and various schemas" do
      # Test with schema that has $schema 
      schema_with_draft = ~s({
        "$schema": "http://json-schema.org/draft-07/schema#",
        "type": "string"
      })

      result = ExJsonschema.compile(schema_with_draft, draft: :auto)
      assert {:ok, compiled} = result
      assert is_reference(compiled)

      # Test without $schema
      schema_no_draft = ~s({"type": "number"})
      result = ExJsonschema.compile(schema_no_draft, draft: :auto)
      assert {:ok, compiled} = result
      assert is_reference(compiled)
    end

    test "Options validation edge cases" do
      opts =
        ExJsonschema.Options.new(
          draft: :draft4,
          regex_engine: :regex,
          output_format: :basic,
          collect_annotations: false,
          stop_on_first_error: true
        )

      assert {:ok, ^opts} = ExJsonschema.Options.validate(opts)
    end

    test "compilation with different option combinations" do
      schema = ~s({"type": "string"})

      # Test with various keyword options
      option_sets = [
        [draft: :draft4],
        [draft: :draft6],
        [draft: :draft7],
        [draft: :draft201909],
        [draft: :draft202012]
      ]

      for opts <- option_sets do
        result = ExJsonschema.compile(schema, opts)
        assert {:ok, compiled} = result
        assert is_reference(compiled)
      end
    end
  end
end
