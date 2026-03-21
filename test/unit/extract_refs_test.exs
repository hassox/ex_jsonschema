defmodule ExJsonschema.ExtractRefsTest do
  use ExUnit.Case
  use ExUnit.CaseHelpers

  describe "extract_refs/1" do
    test "returns empty list when no refs" do
      schema = ~s({"type": "object", "properties": {"name": {"type": "string"}}})
      assert {:ok, []} = ExJsonschema.extract_refs(schema)
    end

    test "excludes local fragment refs" do
      schema = ~s({"$ref": "#/definitions/name", "definitions": {"name": {"type": "string"}}})
      assert {:ok, []} = ExJsonschema.extract_refs(schema)
    end

    test "collects external refs" do
      schema = ~s({"$ref": "https://example.com/person.json"})
      assert {:ok, ["https://example.com/person.json"]} = ExJsonschema.extract_refs(schema)
    end

    test "collects nested refs in properties" do
      schema =
        Jason.encode!(%{
          "type" => "object",
          "properties" => %{
            "address" => %{"$ref" => "https://example.com/address.json"},
            "employer" => %{"$ref" => "https://example.com/org.json"}
          }
        })

      {:ok, refs} = ExJsonschema.extract_refs(schema)
      assert length(refs) == 2
      assert "https://example.com/address.json" in refs
      assert "https://example.com/org.json" in refs
    end

    test "collects refs in items" do
      schema =
        Jason.encode!(%{
          "type" => "array",
          "items" => %{"$ref" => "https://example.com/item.json"}
        })

      assert {:ok, ["https://example.com/item.json"]} = ExJsonschema.extract_refs(schema)
    end

    test "collects refs in allOf/anyOf/oneOf" do
      schema =
        Jason.encode!(%{
          "allOf" => [
            %{"$ref" => "https://example.com/base.json"},
            %{"$ref" => "https://example.com/ext.json"}
          ]
        })

      {:ok, refs} = ExJsonschema.extract_refs(schema)
      assert length(refs) == 2
      assert "https://example.com/base.json" in refs
      assert "https://example.com/ext.json" in refs
    end

    test "deduplicates refs" do
      schema =
        Jason.encode!(%{
          "properties" => %{
            "a" => %{"$ref" => "https://example.com/shared.json"},
            "b" => %{"$ref" => "https://example.com/shared.json"}
          }
        })

      assert {:ok, ["https://example.com/shared.json"]} = ExJsonschema.extract_refs(schema)
    end

    test "invalid JSON returns error" do
      assert {:error, "Invalid JSON:" <> _} = ExJsonschema.extract_refs("not json")
    end

    test "mixes external and local refs" do
      schema =
        Jason.encode!(%{
          "properties" => %{
            "a" => %{"$ref" => "#/definitions/local"},
            "b" => %{"$ref" => "https://example.com/external.json"}
          }
        })

      assert {:ok, ["https://example.com/external.json"]} = ExJsonschema.extract_refs(schema)
    end
  end
end
