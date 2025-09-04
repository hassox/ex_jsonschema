defmodule ExJsonschema.DraftDetectorTest do
  use ExUnit.Case
  use ExUnit.CaseHelpers

  alias ExJsonschema.DraftDetector

  describe "detect_draft/1" do
    test "detects Draft 2020-12 from $schema" do
      schema = %{
        "$schema" => "https://json-schema.org/draft/2020-12/schema",
        "type" => "object"
      }

      assert {:ok, :draft202012} = DraftDetector.detect_draft(schema)
    end

    test "detects Draft 2019-09 from $schema" do
      schema = %{
        "$schema" => "https://json-schema.org/draft/2019-09/schema",
        "type" => "string"
      }

      assert {:ok, :draft201909} = DraftDetector.detect_draft(schema)
    end

    test "detects Draft 7 from $schema" do
      schema = %{
        "$schema" => "http://json-schema.org/draft-07/schema#",
        "type" => "number"
      }

      assert {:ok, :draft7} = DraftDetector.detect_draft(schema)
    end

    test "detects Draft 6 from $schema" do
      schema = %{
        "$schema" => "http://json-schema.org/draft-06/schema#",
        "properties" => %{"name" => %{"type" => "string"}}
      }

      assert {:ok, :draft6} = DraftDetector.detect_draft(schema)
    end

    test "detects Draft 4 from $schema" do
      schema = %{
        "$schema" => "http://json-schema.org/draft-04/schema#",
        "additionalProperties" => false
      }

      assert {:ok, :draft4} = DraftDetector.detect_draft(schema)
    end

    test "detects Draft 2020-12 from alternative URL format" do
      schema = %{
        "$schema" => "https://json-schema.org/draft/2020-12/meta/core",
        "type" => "boolean"
      }

      assert {:ok, :draft202012} = DraftDetector.detect_draft(schema)
    end

    test "returns default draft when no $schema present" do
      schema = %{
        "type" => "object",
        "properties" => %{
          "name" => %{"type" => "string"}
        }
      }

      assert {:ok, :draft202012} = DraftDetector.detect_draft(schema)
    end

    test "handles invalid $schema URLs gracefully" do
      schema = %{
        "$schema" => "https://invalid-schema-url.com/schema",
        "type" => "string"
      }

      assert {:ok, :draft202012} = DraftDetector.detect_draft(schema)
    end

    test "handles non-string $schema values" do
      schema = %{
        "$schema" => 123,
        "type" => "array"
      }

      assert {:error, "Invalid $schema value: must be a string, got 123"} = 
        DraftDetector.detect_draft(schema)
    end

    test "detects draft from JSON string input" do
      json = """
      {
        "$schema": "http://json-schema.org/draft-07/schema#",
        "type": "object"
      }
      """

      assert {:ok, :draft7} = DraftDetector.detect_draft(json)
    end

    test "handles malformed JSON gracefully" do
      invalid_json = """
      {
        "$schema": "http://json-schema.org/draft-07/schema#",
        "type": "object"
        // missing comma
        "properties": {}
      }
      """

      assert {:error, "Invalid JSON: " <> _reason} = DraftDetector.detect_draft(invalid_json)
    end
  end

  describe "detect_draft_from_url/1" do
    test "extracts draft from standard URLs" do
      url = "https://json-schema.org/draft/2020-12/schema"
      assert {:ok, :draft202012} = DraftDetector.detect_draft_from_url(url)
    end

    test "extracts draft from meta schema URLs" do
      url = "https://json-schema.org/draft/2019-09/meta/applicator"
      assert {:ok, :draft201909} = DraftDetector.detect_draft_from_url(url)
    end

    test "extracts draft from hash-based URLs" do
      url = "http://json-schema.org/draft-04/schema#"
      assert {:ok, :draft4} = DraftDetector.detect_draft_from_url(url)
    end

    test "handles unknown URLs" do
      url = "https://example.com/my-custom-schema"
      assert {:ok, :draft202012} = DraftDetector.detect_draft_from_url(url)
    end

    test "handles empty or nil URLs" do
      assert {:error, "Invalid URL: cannot be empty"} = DraftDetector.detect_draft_from_url("")
      assert {:error, "Invalid URL: cannot be nil"} = DraftDetector.detect_draft_from_url(nil)
    end
  end

  describe "supported_drafts/0" do
    test "returns all supported draft versions" do
      supported = DraftDetector.supported_drafts()

      assert is_list(supported)
      assert :draft4 in supported
      assert :draft6 in supported  
      assert :draft7 in supported
      assert :draft201909 in supported
      assert :draft202012 in supported
      assert length(supported) == 5
    end
  end

  describe "supports_draft?/1" do
    test "returns true for supported drafts" do
      assert DraftDetector.supports_draft?(:draft4) == true
      assert DraftDetector.supports_draft?(:draft6) == true
      assert DraftDetector.supports_draft?(:draft7) == true
      assert DraftDetector.supports_draft?(:draft201909) == true
      assert DraftDetector.supports_draft?(:draft202012) == true
    end

    test "returns false for unsupported drafts" do
      assert DraftDetector.supports_draft?(:draft3) == false
      assert DraftDetector.supports_draft?(:invalid) == false
      assert DraftDetector.supports_draft?(nil) == false
    end
  end

  describe "default_draft/0" do
    test "returns the default draft version" do
      assert DraftDetector.default_draft() == :draft202012
    end
  end

  describe "schema_has_draft?/1" do
    test "returns true when schema has $schema property" do
      schema = %{"$schema" => "http://json-schema.org/draft-07/schema#"}
      assert DraftDetector.schema_has_draft?(schema) == true
    end

    test "returns false when schema has no $schema property" do
      schema = %{"type" => "string"}
      assert DraftDetector.schema_has_draft?(schema) == false
    end

    test "returns false for empty schema" do
      schema = %{}
      assert DraftDetector.schema_has_draft?(schema) == false
    end

    test "handles JSON string input" do
      json_with_schema = ~s({"$schema": "http://json-schema.org/draft-07/schema#"})
      json_without_schema = ~s({"type": "string"})

      assert DraftDetector.schema_has_draft?(json_with_schema) == true
      assert DraftDetector.schema_has_draft?(json_without_schema) == false
    end
  end

  describe "draft_url/1" do
    test "returns canonical URL for each draft" do
      assert DraftDetector.draft_url(:draft4) == "http://json-schema.org/draft-04/schema#"
      assert DraftDetector.draft_url(:draft6) == "http://json-schema.org/draft-06/schema#"
      assert DraftDetector.draft_url(:draft7) == "http://json-schema.org/draft-07/schema#"
      assert DraftDetector.draft_url(:draft201909) == "https://json-schema.org/draft/2019-09/schema"
      assert DraftDetector.draft_url(:draft202012) == "https://json-schema.org/draft/2020-12/schema"
    end

    test "returns error for unsupported draft" do
      assert {:error, "Unsupported draft: :invalid"} = DraftDetector.draft_url(:invalid)
    end
  end

  describe "integration with Options" do
    test "can detect draft from schema and apply to options" do
      schema = %{
        "$schema" => "http://json-schema.org/draft-07/schema#",
        "type" => "object"
      }

      {:ok, detected_draft} = DraftDetector.detect_draft(schema)
      options = ExJsonschema.Options.new(draft: detected_draft)

      assert options.draft == :draft7
    end

    test "auto detection overrides explicit draft when :auto specified" do
      schema = %{
        "$schema" => "http://json-schema.org/draft-06/schema#",
        "type" => "string"
      }

      _options = ExJsonschema.Options.new(draft: :auto)
      {:ok, auto_detected} = DraftDetector.detect_draft(schema)

      # When using :auto, detection should find draft6
      assert auto_detected == :draft6
    end
  end

  describe "error handling" do
    test "handles schema as different data types" do
      # Map input (valid)
      map_schema = %{"type" => "string"}
      assert {:ok, :draft202012} = DraftDetector.detect_draft(map_schema)

      # String input (valid JSON)
      string_schema = ~s({"type": "number"})
      assert {:ok, :draft202012} = DraftDetector.detect_draft(string_schema)

      # Invalid inputs
      assert {:error, _} = DraftDetector.detect_draft(123)
      assert {:error, _} = DraftDetector.detect_draft([])
      assert {:error, _} = DraftDetector.detect_draft(nil)
    end

    test "provides helpful error messages" do
      {:error, message} = DraftDetector.detect_draft(nil)
      assert message =~ "Invalid schema input"

      {:error, message} = DraftDetector.detect_draft("invalid json")
      assert message =~ "Invalid JSON"
    end
  end
end