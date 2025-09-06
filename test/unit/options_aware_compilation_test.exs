defmodule ExJsonschema.OptionsAwareCompilationTest do
  use ExUnit.Case
  use ExUnit.CaseHelpers

  alias ExJsonschema.{CompilationError, Options}

  describe "options-aware compilation" do
    test "compiles successfully when draft in options matches schema $schema" do
      schema = ~s({"$schema": "http://json-schema.org/draft-07/schema#", "type": "string"})
      options = Options.new(draft: :draft7)

      assert {:ok, compiled} = ExJsonschema.compile(schema, options)
      assert is_reference(compiled)
    end

    test "compiles successfully when no $schema in document and draft specified in options" do
      schema = ~s({"type": "number"})
      options = Options.new(draft: :draft6)

      assert {:ok, compiled} = ExJsonschema.compile(schema, options)
      assert is_reference(compiled)
    end

    test "compiles successfully with :auto draft detection" do
      schema = ~s({"$schema": "https://json-schema.org/draft/2020-12/schema", "type": "boolean"})
      options = Options.new(draft: :auto)

      assert {:ok, compiled} = ExJsonschema.compile(schema, options)
      assert is_reference(compiled)
    end

    test "returns error when draft in options conflicts with schema $schema" do
      schema = ~s({"$schema": "http://json-schema.org/draft-07/schema#", "type": "array"})
      options = Options.new(draft: :draft6)

      assert {:error, %CompilationError{type: :validation_error}} =
               ExJsonschema.compile(schema, options)
    end

    test "compiles successfully when using keyword options" do
      schema = ~s({"$schema": "http://json-schema.org/draft-07/schema#", "type": "object"})

      assert {:ok, compiled} = ExJsonschema.compile(schema, draft: :draft7)
      assert is_reference(compiled)
    end

    test "auto-detection works in compile/2 with Options struct" do
      schema_with_draft = ~s({
        "$schema": "https://json-schema.org/draft/2019-09/schema",
        "type": "string"
      })
      options = Options.new(draft: :auto)

      assert {:ok, compiled} = ExJsonschema.compile(schema_with_draft, options)
      assert is_reference(compiled)
    end

    test "handles invalid schema JSON during options validation" do
      # Use actual invalid JSON
      invalid_json = ~s({"type": "string", "invalid": })
      options = Options.new(draft: :draft7)

      assert {:error, %CompilationError{type: :validation_error}} =
               ExJsonschema.compile(invalid_json, options)
    end

    test "validates draft consistency during compilation" do
      # Schema explicitly says draft-04 but options say draft-07
      schema =
        %{
          "$schema" => "http://json-schema.org/draft-04/schema#",
          "type" => "string"
        }
        |> Jason.encode!()

      options = Options.new(draft: :draft7)

      assert {:error,
              %CompilationError{
                type: :validation_error,
                message: "Compilation validation failed",
                details: details
              }} = ExJsonschema.compile(schema, options)

      assert details =~ "Schema specifies draft4 but options specify draft7"
    end
  end

  describe "compilation error handling" do
    test "provides helpful error messages for draft conflicts" do
      schema = ~s({"$schema": "https://json-schema.org/draft/2020-12/schema", "type": "integer"})
      options = Options.new(draft: :draft4)

      assert {:error, error} = ExJsonschema.compile(schema, options)
      assert error.type == :validation_error
      assert error.message == "Compilation validation failed"
      assert error.details =~ "Schema specifies draft202012 but options specify draft4"
    end

    test "handles draft detection errors gracefully" do
      # This is tricky to trigger since detection is quite robust
      # The detection would need to fail, which happens with invalid JSON
      malformed_json = ~s({"$schema": "invalid", )
      options = Options.new(draft: :draft7)

      assert {:error, %CompilationError{type: :validation_error}} =
               ExJsonschema.compile(malformed_json, options)
    end
  end
end
