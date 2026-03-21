defmodule ExJsonschema.ExternalSchemasTest do
  use ExUnit.Case
  use ExUnit.CaseHelpers

  describe "external_schemas: :ignore (default)" do
    test "schema with unknown $ref compiles successfully" do
      schema = ~s({"$ref": "https://nonexistent.example.com/schema.json"})
      assert {:ok, _compiled} = ExJsonschema.compile(schema)
    end

    test "ignored refs validate permissively" do
      schema = ~s({"$ref": "https://nonexistent.example.com/schema.json"})
      {:ok, compiled} = ExJsonschema.compile(schema)

      # Should pass because the unknown ref is replaced by an empty schema {}
      assert :ok = ExJsonschema.validate(compiled, ~s("anything"))
      assert :ok = ExJsonschema.validate(compiled, ~s(42))
      assert :ok = ExJsonschema.validate(compiled, ~s({"any": "object"}))
    end

    test "explicit :ignore behaves same as default" do
      schema = ~s({"$ref": "https://nonexistent.example.com/schema.json"})
      assert {:ok, _compiled} = ExJsonschema.compile(schema, external_schemas: :ignore)
    end
  end

  describe "external_schemas: pre-resolved map" do
    test "schema with $ref resolves correctly from map" do
      schema =
        Jason.encode!(%{
          "type" => "object",
          "properties" => %{
            "email" => %{"$ref" => "https://example.com/email.json"}
          }
        })

      resolved = %{
        "https://example.com/email.json" => ~s({"type": "string", "format": "email"})
      }

      {:ok, compiled} = ExJsonschema.compile(schema, external_schemas: resolved)

      assert :ok = ExJsonschema.validate(compiled, ~s({"email": "test@example.com"}))
      # Type constraint from resolved schema is enforced
      assert {:error, _} = ExJsonschema.validate(compiled, ~s({"email": 42}))
    end

    test "missing refs in map are permissive" do
      schema =
        Jason.encode!(%{
          "properties" => %{
            "a" => %{"$ref" => "https://example.com/known.json"},
            "b" => %{"$ref" => "https://example.com/unknown.json"}
          }
        })

      resolved = %{
        "https://example.com/known.json" => ~s({"type": "string"})
      }

      {:ok, compiled} = ExJsonschema.compile(schema, external_schemas: resolved)

      # "a" is constrained by the resolved schema
      assert {:error, _} = ExJsonschema.validate(compiled, ~s({"a": 123}))
      # "b" is permissive because its ref wasn't in the map
      assert :ok = ExJsonschema.validate(compiled, ~s({"b": "anything"}))
      assert :ok = ExJsonschema.validate(compiled, ~s({"b": 999}))
    end

    test "invalid JSON in map values produces compilation error" do
      schema = ~s({"$ref": "https://example.com/broken.json"})

      resolved = %{
        "https://example.com/broken.json" => "not valid json"
      }

      assert {:error, %ExJsonschema.CompilationError{}} =
               ExJsonschema.compile(schema, external_schemas: resolved)
    end
  end

  describe "external_schemas: :http" do
    test ":http mode is accepted as an option" do
      # Just verify the option is accepted — we don't actually test HTTP fetching
      schema = ~s({"type": "string"})
      assert {:ok, _compiled} = ExJsonschema.compile(schema, external_schemas: :http)
    end
  end

  describe "options validation" do
    test "default external_schemas is :ignore" do
      opts = ExJsonschema.Options.new()
      assert opts.external_schemas == :ignore
    end

    test "default ref_resolver is nil" do
      opts = ExJsonschema.Options.new()
      assert opts.ref_resolver == nil
    end

    test "invalid external_schemas rejected" do
      opts = %ExJsonschema.Options{external_schemas: :invalid}
      assert {:error, _} = ExJsonschema.Options.validate(opts)
    end
  end
end
