defmodule ExJsonschema.DraftDetectionPropertyTest do
  use ExUnit.Case
  use ExUnitProperties

  alias ExJsonschema.DraftDetector

  describe "property tests for draft detection" do
    property "detect_draft always returns a valid draft or error" do
      check all schema <- schema_generator() do
        case DraftDetector.detect_draft(schema) do
          {:ok, draft} -> assert draft in DraftDetector.supported_drafts()
          {:error, _reason} -> :ok
        end
      end
    end

    property "draft detection is deterministic" do
      check all schema <- schema_with_draft_generator() do
        result1 = DraftDetector.detect_draft(schema)
        result2 = DraftDetector.detect_draft(schema)
        assert result1 == result2
      end
    end

    property "schema_has_draft? is consistent with detect_draft" do
      check all schema <- schema_generator() do
        has_draft = DraftDetector.schema_has_draft?(schema)
        default_draft = DraftDetector.default_draft()
        
        case DraftDetector.detect_draft(schema) do
          {:ok, draft} when draft != default_draft ->
            # If a specific draft was detected (not default), schema should have $schema
            assert has_draft == true
          {:ok, _default_draft} ->
            # Default draft can be detected with or without $schema
            :ok
          {:error, _} ->
            # Error case, skip check
            :ok
        end
      end
    end

    property "all supported drafts have valid URLs" do
      check all draft <- one_of(DraftDetector.supported_drafts()) do
        url = DraftDetector.draft_url(draft)
        assert is_binary(url)
        assert String.starts_with?(url, "http")
      end
    end

    property "draft_url roundtrip via detect_draft_from_url" do
      check all draft <- one_of(DraftDetector.supported_drafts()) do
        url = DraftDetector.draft_url(draft)
        {:ok, detected_draft} = DraftDetector.detect_draft_from_url(url)
        assert detected_draft == draft
      end
    end

    property "JSON encoding preserves draft detection" do
      check all schema <- schema_with_draft_generator() do
        # Detect draft from original schema
        original_result = DraftDetector.detect_draft(schema)
        
        # Convert to JSON and back, then detect again
        json_string = Jason.encode!(schema)
        json_result = DraftDetector.detect_draft(json_string)
        
        assert original_result == json_result
      end
    end
  end

  # Generators

  defp schema_generator do
    frequency([
      {5, valid_schema_generator()},
      {2, schema_with_draft_generator()},
      {1, invalid_schema_generator()}
    ])
  end

  defp valid_schema_generator do
    gen all type <- one_of([
              constant("string"), 
              constant("number"), 
              constant("object"), 
              constant("array"), 
              constant("boolean"), 
              constant("null")
            ]),
            additional_props <- map_of(string(:alphanumeric), simple_value()) do
      Map.merge(%{"type" => type}, additional_props)
    end
  end

  defp schema_with_draft_generator do
    gen all base_schema <- valid_schema_generator(),
            draft_url <- draft_url_generator() do
      Map.put(base_schema, "$schema", draft_url)
    end
  end

  defp draft_url_generator do
    one_of([
      constant("http://json-schema.org/draft-04/schema#"),
      constant("http://json-schema.org/draft-06/schema#"),
      constant("http://json-schema.org/draft-07/schema#"),
      constant("https://json-schema.org/draft/2019-09/schema"),
      constant("https://json-schema.org/draft/2020-12/schema"),
      # Alternative formats
      constant("https://json-schema.org/draft/2020-12/meta/core"),
      constant("https://json-schema.org/draft/2019-09/meta/applicator")
    ])
  end

  defp invalid_schema_generator do
    one_of([
      # Invalid $schema values
      gen(all(base <- valid_schema_generator()) do
        Map.put(base, "$schema", :not_a_string)
      end),
      gen(all(base <- valid_schema_generator()) do
        Map.put(base, "$schema", 123)
      end),
      # Invalid schema structure
      constant("not valid json"),
      constant(nil),
      constant([]),
      constant(42)
    ])
  end

  defp simple_value do
    one_of([
      string(:alphanumeric),
      integer(),
      boolean(),
      constant(nil)
    ])
  end
end