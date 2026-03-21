defmodule ExJsonschema.RefResolverTest do
  use ExUnit.Case
  use ExUnit.CaseHelpers

  defmodule TestResolver do
    @behaviour ExJsonschema.RefResolver

    @schemas %{
      "https://example.com/name.json" => ~s({"type": "string", "minLength": 1}),
      "https://example.com/age.json" => ~s({"type": "integer", "minimum": 0})
    }

    @impl true
    def resolve(uris) do
      resolved = Map.new(uris, fn uri -> {uri, Map.get(@schemas, uri, ~s({}))} end)
      {:ok, resolved}
    end
  end

  defmodule TransitiveResolver do
    @behaviour ExJsonschema.RefResolver

    @schemas %{
      "https://example.com/person.json" =>
        Jason.encode!(%{
          "type" => "object",
          "properties" => %{
            "address" => %{"$ref" => "https://example.com/address.json"}
          }
        }),
      "https://example.com/address.json" =>
        Jason.encode!(%{
          "type" => "object",
          "properties" => %{
            "street" => %{"type" => "string"}
          },
          "required" => ["street"]
        })
    }

    @impl true
    def resolve(uris) do
      resolved = Map.new(uris, fn uri -> {uri, Map.get(@schemas, uri, ~s({}))} end)
      {:ok, resolved}
    end
  end

  defmodule FailingResolver do
    @behaviour ExJsonschema.RefResolver

    @impl true
    def resolve(_uris) do
      {:error, "network unavailable"}
    end
  end

  describe "behaviour contract" do
    test "resolver module implements the behaviour" do
      assert function_exported?(TestResolver, :resolve, 1)
    end
  end

  describe "compile with ref_resolver" do
    test "resolves external refs via behaviour" do
      schema =
        Jason.encode!(%{
          "type" => "object",
          "properties" => %{
            "name" => %{"$ref" => "https://example.com/name.json"}
          }
        })

      {:ok, compiled} = ExJsonschema.compile(schema, ref_resolver: TestResolver)

      # Valid: name is a non-empty string
      assert :ok = ExJsonschema.validate(compiled, ~s({"name": "Alice"}))

      # Invalid: name is not a string
      assert {:error, _errors} = ExJsonschema.validate(compiled, ~s({"name": 123}))
    end

    test "handles transitive refs" do
      schema =
        Jason.encode!(%{
          "type" => "object",
          "properties" => %{
            "person" => %{"$ref" => "https://example.com/person.json"}
          }
        })

      {:ok, compiled} = ExJsonschema.compile(schema, ref_resolver: TransitiveResolver)

      # Valid: person has address with street
      valid = Jason.encode!(%{"person" => %{"address" => %{"street" => "123 Main St"}}})
      assert :ok = ExJsonschema.validate(compiled, valid)

      # Invalid: person's address missing required "street"
      invalid = Jason.encode!(%{"person" => %{"address" => %{}}})
      assert {:error, _errors} = ExJsonschema.validate(compiled, invalid)
    end

    test "resolver failure produces compilation error" do
      schema = ~s({"$ref": "https://example.com/whatever.json"})

      assert {:error, %ExJsonschema.CompilationError{type: :ref_resolution_error}} =
               ExJsonschema.compile(schema, ref_resolver: FailingResolver)
    end

    test "circular refs do not loop forever" do
      # A refs B, B refs A — the seen set should break the cycle
      defmodule CircularResolver do
        @behaviour ExJsonschema.RefResolver

        @impl true
        def resolve(uris) do
          schemas = %{
            "https://example.com/a.json" =>
              Jason.encode!(%{
                "type" => "object",
                "properties" => %{
                  "b" => %{"$ref" => "https://example.com/b.json"}
                }
              }),
            "https://example.com/b.json" =>
              Jason.encode!(%{
                "type" => "object",
                "properties" => %{
                  "a" => %{"$ref" => "https://example.com/a.json"}
                }
              })
          }

          resolved = Map.new(uris, fn uri -> {uri, Map.get(schemas, uri, ~s({}))} end)
          {:ok, resolved}
        end
      end

      schema =
        Jason.encode!(%{
          "type" => "object",
          "properties" => %{
            "root" => %{"$ref" => "https://example.com/a.json"}
          }
        })

      # Must terminate — not hang
      assert {:ok, _compiled} = ExJsonschema.compile(schema, ref_resolver: CircularResolver)
    end

    test "schema with no external refs skips resolver entirely" do
      # The resolver should never be called if there are no external refs
      defmodule NeverCalledResolver do
        @behaviour ExJsonschema.RefResolver

        @impl true
        def resolve(_uris) do
          raise "resolver should not be called"
        end
      end

      schema = ~s({"type": "string", "minLength": 1})
      assert {:ok, _compiled} = ExJsonschema.compile(schema, ref_resolver: NeverCalledResolver)
    end
  end
end
