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

  defmodule RecordingResolver do
    @moduledoc """
    Serves the documents stored under `:ref_resolver_documents` in the calling
    process and reports every batch of requested URIs as `{:resolve, uris}`.
    `compile/2` runs the resolver in the caller's process.
    """
    @behaviour ExJsonschema.RefResolver

    @impl true
    def resolve(uris) do
      send(self(), {:resolve, Enum.sort(uris)})
      documents = Process.get(:ref_resolver_documents, %{})
      {:ok, Map.take(documents, uris)}
    end
  end

  defp compile_recording(schema, documents) do
    Process.put(
      :ref_resolver_documents,
      Map.new(documents, fn {uri, doc} -> {uri, Jason.encode!(doc)} end)
    )

    ExJsonschema.compile(Jason.encode!(schema), ref_resolver: RecordingResolver)
  end

  defp requested_uris do
    receive do
      {:resolve, uris} -> uris ++ requested_uris()
    after
      0 -> []
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

  describe "URIs passed to the resolver" do
    test "relative refs inside a resolved document resolve against its $id" do
      schema = %{"$ref" => "https://example.com/schemas/person.json"}

      documents = %{
        "https://example.com/schemas/person.json" => %{
          "$id" => "https://example.com/schemas/person.json",
          "properties" => %{"age" => %{"$ref" => "defs/age.json"}}
        },
        "https://example.com/schemas/defs/age.json" => %{"type" => "integer", "minimum" => 0}
      }

      assert {:ok, compiled} = compile_recording(schema, documents)

      assert requested_uris() == [
               "https://example.com/schemas/person.json",
               "https://example.com/schemas/defs/age.json"
             ]

      assert :ok = ExJsonschema.validate(compiled, ~s({"age": 30}))
      assert {:error, _} = ExJsonschema.validate(compiled, ~s({"age": -1}))
    end

    test "relative refs inside a resolved document without $id resolve against its URI" do
      schema = %{"$ref" => "https://example.com/schemas/person.json"}

      documents = %{
        "https://example.com/schemas/person.json" => %{
          "properties" => %{"age" => %{"$ref" => "../shared/age.json"}}
        },
        "https://example.com/shared/age.json" => %{"type" => "integer"}
      }

      assert {:ok, compiled} = compile_recording(schema, documents)
      assert "https://example.com/shared/age.json" in requested_uris()
      assert {:error, _} = ExJsonschema.validate(compiled, ~s({"age": "old"}))
    end

    test "a nested $id changes the base for refs beneath it" do
      schema = %{
        "$id" => "https://example.com/root.json",
        "properties" => %{
          "a" => %{"$ref" => "a.json"},
          "b" => %{"$id" => "https://other.example.com/dir/b.json", "$ref" => "c.json"}
        }
      }

      assert {:ok, _compiled} = compile_recording(schema, %{})

      assert requested_uris() == [
               "https://example.com/a.json",
               "https://other.example.com/dir/c.json"
             ]
    end

    test "fragments are stripped so the document is retrieved once and the fragment applied" do
      schema = %{
        "properties" => %{
          "name" => %{"$ref" => "https://example.com/defs.json#/$defs/name"},
          "age" => %{"$ref" => "https://example.com/defs.json#/$defs/age"}
        }
      }

      documents = %{
        "https://example.com/defs.json" => %{
          "$defs" => %{"name" => %{"type" => "string"}, "age" => %{"type" => "integer"}}
        }
      }

      assert {:ok, compiled} = compile_recording(schema, documents)
      assert requested_uris() == ["https://example.com/defs.json"]
      assert :ok = ExJsonschema.validate(compiled, ~s({"name": "Ann", "age": 3}))
      assert {:error, _} = ExJsonschema.validate(compiled, ~s({"name": 3}))
      assert {:error, _} = ExJsonschema.validate(compiled, ~s({"age": "three"}))
    end

    test "relative refs in a root schema without $id use the json-schema:/// base" do
      schema = %{"$ref" => "age.json"}
      documents = %{"json-schema:///age.json" => %{"type" => "integer"}}

      assert {:ok, compiled} = compile_recording(schema, documents)
      assert requested_uris() == ["json-schema:///age.json"]
      assert {:error, _} = ExJsonschema.validate(compiled, ~s("old"))
    end

    test "only refs the validator follows are requested" do
      schema = %{
        "$ref" => "#/x-reused/pet",
        "x-reused" => %{"pet" => %{"$ref" => "https://example.com/pet.json"}},
        "links" => [%{"$ref" => "https://example.com/link-target.json"}],
        "properties" => %{
          "default" => %{"$ref" => "https://example.com/real.json"},
          "config" => %{
            "default" => %{"$ref" => "https://example.com/default-data.json"},
            "examples" => [%{"$ref" => "https://example.com/example-data.json"}],
            "const" => %{"$ref" => "https://example.com/const-data.json"},
            "enum" => [%{"$ref" => "https://example.com/enum-data.json"}]
          }
        }
      }

      assert {:ok, _compiled} = compile_recording(schema, %{})

      # The local "#/x-reused/pet" ref makes that subschema's ref live; refs in
      # annotations and instance data are never resolved by the validator
      assert requested_uris() == ["https://example.com/pet.json", "https://example.com/real.json"]
    end

    test "resolves each dependency level in one resolver call" do
      schema = %{
        "properties" => %{
          "a" => %{"$ref" => "https://example.com/a.json"},
          "b" => %{"$ref" => "https://example.com/b.json"}
        }
      }

      documents = %{
        "https://example.com/a.json" => %{"$ref" => "https://example.com/shared.json"},
        "https://example.com/b.json" => %{"$ref" => "https://example.com/shared.json"},
        "https://example.com/shared.json" => %{"type" => "string"}
      }

      assert {:ok, _compiled} = compile_recording(schema, documents)
      assert_received {:resolve, ["https://example.com/a.json", "https://example.com/b.json"]}
      assert_received {:resolve, ["https://example.com/shared.json"]}
      refute_received {:resolve, _}
    end

    test "external refs under a urn: base are a compilation error, not a resolver call" do
      # The validator does not resolve external refs beneath a urn: base
      schema = %{
        "$id" => "urn:example:root",
        "properties" => %{"b" => %{"$ref" => "https://example.com/b.json"}}
      }

      assert {:error, %ExJsonschema.CompilationError{type: :compilation_error}} =
               compile_recording(schema, %{})

      assert requested_uris() == []
    end

    test "a fragment-only $id is an anchor and does not change the base" do
      schema = %{
        "$schema" => "http://json-schema.org/draft-07/schema#",
        "$id" => "https://example.com/root.json",
        "definitions" => %{"a" => %{"$id" => "#a", "$ref" => "a.json"}}
      }

      assert {:ok, _compiled} = compile_recording(schema, %{})
      assert requested_uris() == ["https://example.com/a.json"]
    end

    test "a non-string document from the resolver is a ref resolution error" do
      defmodule DecodedMapResolver do
        @behaviour ExJsonschema.RefResolver

        @impl true
        def resolve(uris), do: {:ok, Map.new(uris, &{&1, %{"type" => "string"}})}
      end

      assert {:error, %ExJsonschema.CompilationError{type: :ref_resolution_error}} =
               ExJsonschema.compile(~s({"$ref": "https://example.com/x.json"}),
                 ref_resolver: DecodedMapResolver
               )
    end

    test "invalid JSON from the resolver is a ref resolution error" do
      defmodule InvalidJsonResolver do
        @behaviour ExJsonschema.RefResolver

        @impl true
        def resolve(uris), do: {:ok, Map.new(uris, &{&1, "not json"})}
      end

      assert {:error, %ExJsonschema.CompilationError{type: :ref_resolution_error}} =
               ExJsonschema.compile(~s({"$ref": "https://example.com/x.json"}),
                 ref_resolver: InvalidJsonResolver
               )
    end
  end

  describe "official meta-schema refs" do
    defmodule MetaSchemaNeverResolver do
      @behaviour ExJsonschema.RefResolver

      @impl true
      def resolve(uris), do: flunk("resolver asked for #{inspect(uris)}")
    end

    for {root_draft, root_meta} <- [
          {"2020-12", "https://json-schema.org/draft/2020-12/schema"},
          {"draft-07", "http://json-schema.org/draft-07/schema#"}
        ],
        {ref_draft, ref_meta} <- [
          {"2020-12", "https://json-schema.org/draft/2020-12/schema"},
          {"2019-09", "https://json-schema.org/draft/2019-09/schema"},
          {"draft-07", "http://json-schema.org/draft-07/schema#"},
          {"draft-04", "http://json-schema.org/draft-04/schema#"}
        ] do
      test "a #{root_draft} schema can $ref the #{ref_draft} meta-schema without retrieving it" do
        schema =
          Jason.encode!(%{
            "$schema" => unquote(root_meta),
            "properties" => %{"inputSchema" => %{"$ref" => unquote(ref_meta)}}
          })

        assert {:ok, compiled} =
                 ExJsonschema.compile(schema, ref_resolver: MetaSchemaNeverResolver)

        assert :ok = ExJsonschema.validate(compiled, ~s({"inputSchema": {"type": "object"}}))
        assert {:error, _} = ExJsonschema.validate(compiled, ~s({"inputSchema": {"type": 5}}))
      end
    end
  end

  describe "allowed_refs" do
    defp compile_allowed(schema, documents, allowed_refs) do
      Process.put(
        :ref_resolver_documents,
        Map.new(documents, fn {uri, doc} -> {uri, Jason.encode!(doc)} end)
      )

      ExJsonschema.compile(Jason.encode!(schema),
        ref_resolver: RecordingResolver,
        allowed_refs: allowed_refs
      )
    end

    test "a domain entry allows any http(s) document on that host, case-insensitively" do
      schema = %{"$ref" => "https://Schemas.Example.com/a.json"}

      documents = %{
        "https://schemas.example.com/a.json" => %{"$ref" => "nested/b.json"},
        "https://schemas.example.com/nested/b.json" => %{"type" => "integer"}
      }

      assert {:ok, compiled} = compile_allowed(schema, documents, ["schemas.example.com"])
      assert {:error, _} = ExJsonschema.validate(compiled, ~s("x"))
    end

    test "a URI entry allows exactly that document" do
      schema = %{
        "properties" => %{
          "a" => %{"$ref" => "https://example.com/a.json#/$defs/x"},
          "b" => %{"$ref" => "https://example.com/b.json"}
        }
      }

      assert {:error, %ExJsonschema.CompilationError{type: :ref_resolution_error} = error} =
               compile_allowed(schema, %{}, ["https://example.com/a.json#ignored"])

      assert error.details == "$ref not in allowed_refs: https://example.com/b.json"
      refute_received {:resolve, _}
    end

    test "transitive refs outside the allow list fail before the resolver is asked for them" do
      schema = %{"$ref" => "https://allowed.example.com/a.json"}

      documents = %{
        "https://allowed.example.com/a.json" => %{"$ref" => "https://evil.example.com/b.json"}
      }

      assert {:error, %ExJsonschema.CompilationError{type: :ref_resolution_error} = error} =
               compile_allowed(schema, documents, ["allowed.example.com"])

      assert error.details == "$ref not in allowed_refs: https://evil.example.com/b.json"
      assert requested_uris() == ["https://allowed.example.com/a.json"]
    end

    test "domain entries only match http(s) URIs" do
      schema = %{"$ref" => "other.json"}

      assert {:error, %ExJsonschema.CompilationError{type: :ref_resolution_error} = error} =
               compile_allowed(schema, %{}, ["example.com"])

      assert error.details == "$ref not in allowed_refs: json-schema:///other.json"
    end

    test "an empty allow list allows no external documents, only the bundled meta-schemas" do
      schema = %{
        "properties" => %{
          "inputSchema" => %{"$ref" => "https://json-schema.org/draft/2020-12/schema"}
        }
      }

      assert {:ok, compiled} = compile_allowed(schema, %{}, [])
      assert {:error, _} = ExJsonschema.validate(compiled, ~s({"inputSchema": {"type": 5}}))

      assert {:error, %ExJsonschema.CompilationError{type: :ref_resolution_error}} =
               compile_allowed(%{"$ref" => "https://example.com/a.json"}, %{}, [])
    end

    test "requires a ref_resolver and string entries" do
      assert {:error, %ExJsonschema.CompilationError{type: :options_error} = error} =
               ExJsonschema.compile(~s({}), allowed_refs: ["example.com"])

      assert error.details =~ "only applies together with a ref_resolver"

      for bad_entry <- [:bad, ""] do
        assert {:error, %ExJsonschema.CompilationError{type: :options_error}} =
                 ExJsonschema.compile(~s({}),
                   ref_resolver: RecordingResolver,
                   allowed_refs: [bad_entry]
                 )
      end

      assert {:error, %ExJsonschema.CompilationError{type: :options_error}} =
               ExJsonschema.compile(~s({}), ref_resolver: RecordingResolver, allowed_refs: "x")
    end
  end
end
