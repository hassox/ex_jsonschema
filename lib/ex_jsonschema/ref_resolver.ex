defmodule ExJsonschema.RefResolver do
  @moduledoc """
  Behaviour for resolving external `$ref` URIs in JSON Schemas.

  Implement this behaviour to control how external schema references are
  fetched — via HTTP, database, filesystem, a hardcoded map, etc.

  ## Example

      defmodule MyApp.SchemaResolver do
        @behaviour ExJsonschema.RefResolver

        @impl true
        def resolve(uris) do
          resolved =
            Map.new(uris, fn uri ->
              {:ok, body} = fetch_schema(uri)
              {uri, body}
            end)

          {:ok, resolved}
        end

        defp fetch_schema(uri), do: {:ok, ~s({"type": "object"})}
      end

      {:ok, compiled} = ExJsonschema.compile(schema, ref_resolver: MyApp.SchemaResolver)

  ## Transitive resolution

  When a `ref_resolver` is used, ExJsonschema automatically handles transitive
  references: if a resolved schema itself contains `$ref`s, the resolver is
  called again for the new URIs until no unresolved external refs remain.

  ## URIs the resolver receives

  Every URI is absolute and has no fragment, because documents are retrieved
  whole and the fragment is applied after retrieval. A relative `$ref` is
  resolved against the base URI of the subschema it appears in: the nearest
  enclosing `$id`, else the URI its document was resolved under. A root schema
  without `$id` has the base URI `json-schema:///`, so a relative `$ref` in it
  arrives as e.g. `json-schema:///other.json`.

  The resolver is only asked for documents the validator actually needs:
  `$ref`s in annotations, instance data (`examples`, `default`, `const`,
  `enum`) or unknown keywords are not followed unless a local `$ref` points
  into them. The official `json-schema.org` meta-schemas (draft 4 through
  2020-12) are bundled with the validator, so the resolver is never asked for
  them.

  Pass `allowed_refs:` to `ExJsonschema.compile/2` to limit which URIs the
  resolver may be asked for (see `t:ExJsonschema.Options.allowed_refs/0`).
  """

  @doc """
  Resolve a list of external `$ref` URIs to their JSON Schema strings.

  Receives a list of absolute, fragment-less URI strings (see "URIs the
  resolver receives" above) and must return either:
  - `{:ok, %{uri => json_string}}` — a map from each URI to its JSON content
  - `{:error, term()}` — if resolution fails; compilation then fails with a
    `:ref_resolution_error`

  The resolver may return schemas for a subset of the requested URIs; any
  missing URIs will be treated as permissive empty schemas (`{}`).
  """
  @callback resolve(uris :: [String.t()]) :: {:ok, %{String.t() => String.t()}} | {:error, term()}
end
