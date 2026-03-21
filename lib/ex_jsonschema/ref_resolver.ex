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
  """

  @doc """
  Resolve a list of external `$ref` URIs to their JSON Schema strings.

  Receives a list of URI strings and must return either:
  - `{:ok, %{uri => json_string}}` — a map from each URI to its JSON content
  - `{:error, term()}` — if resolution fails

  The resolver may return schemas for a subset of the requested URIs; any
  missing URIs will be treated as permissive empty schemas (`{}`).
  """
  @callback resolve(uris :: [String.t()]) :: {:ok, %{String.t() => String.t()}} | {:error, term()}
end
