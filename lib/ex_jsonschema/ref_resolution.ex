defmodule ExJsonschema.RefResolution do
  @moduledoc false

  # Transitive `$ref` resolution through an `ExJsonschema.RefResolver`.
  #
  # The Rust validator decides which external documents a schema needs: it
  # resolves each `$ref` against its base URI, drops the fragment, follows only
  # real subschema locations, and serves the official meta-schemas itself.
  # Rather than re-implement that crawl, each round builds the validator
  # against the documents resolved so far, asks it which URIs it was missing
  # (`Native.unresolved_refs/3`), and resolves those, until nothing new is
  # missing. That is one resolver call per dependency depth. URIs outside
  # `allowed_refs` fail resolution before the resolver sees them.

  alias ExJsonschema.{CompilationError, Native, Options}

  @typedoc "Resolved documents keyed by the absolute, fragment-less URI the validator asked for."
  @type resolved :: %{String.t() => String.t()}

  @doc """
  Resolves every external document `schema_json` depends on, transitively,
  through the options' `ref_resolver`, limited to its `allowed_refs`.

  Returns the merged map of everything the resolver returned. Fails with a
  reason string naming any needed URI outside `allowed_refs`, with the
  resolver's `{:error, reason}`, with a reason string when the resolver returns
  something other than a map of JSON strings, or with a `CompilationError` when
  the schema itself cannot be parsed.
  """
  @spec resolve_all(String.t(), map(), Options.t()) ::
          {:ok, resolved()} | {:error, CompilationError.t() | term()}
  def resolve_all(schema_json, native_options, %Options{ref_resolver: resolver} = options)
      when is_binary(schema_json) and is_atom(resolver) and not is_nil(resolver) do
    allowed = normalize_allowed(options.allowed_refs)
    resolve_missing(schema_json, native_options, {resolver, allowed}, %{}, MapSet.new())
  end

  defp resolve_missing(schema_json, native_options, policy, resolved, requested) do
    with {:ok, missing} <- unresolved_refs(schema_json, native_options, resolved) do
      case Enum.reject(missing, &MapSet.member?(requested, &1)) do
        [] ->
          {:ok, resolved}

        uris ->
          with {:ok, documents} <- resolve(policy, uris) do
            resolve_missing(
              schema_json,
              native_options,
              policy,
              Map.merge(resolved, documents),
              MapSet.union(requested, MapSet.new(uris))
            )
          end
      end
    end
  end

  defp unresolved_refs(schema_json, native_options, resolved) do
    case Native.unresolved_refs(schema_json, native_options, resolved) do
      {:ok, uris} -> {:ok, uris}
      {:error, error_map} -> {:error, CompilationError.from_map(error_map)}
    end
  end

  defp resolve({resolver, allowed}, uris) do
    case Enum.reject(uris, &allowed?(&1, allowed)) do
      [] -> call_resolver(resolver, uris)
      not_allowed -> {:error, "$ref not in allowed_refs: #{Enum.join(not_allowed, ", ")}"}
    end
  end

  defp call_resolver(resolver, uris) do
    case resolver.resolve(uris) do
      {:ok, %{} = documents} -> validate_documents(documents)
      {:error, reason} -> {:error, reason}
      other -> {:error, "#{inspect(resolver)}.resolve/1 returned #{inspect(other)}"}
    end
  end

  defp validate_documents(documents) do
    Enum.reduce_while(documents, {:ok, documents}, fn
      {uri, json}, acc when is_binary(uri) and is_binary(json) ->
        case Jason.decode(json) do
          {:ok, _document} ->
            {:cont, acc}

          {:error, %Jason.DecodeError{} = e} ->
            {:halt,
             {:error, "Invalid JSON in resolved schema for '#{uri}': #{Exception.message(e)}"}}
        end

      {uri, json}, _acc ->
        {:halt, {:error, "Expected a JSON string for #{inspect(uri)}, got: #{inspect(json)}"}}
    end)
  end

  # Domains are compared by lowercased host; URI entries are normalized the
  # same way as requested URIs (lowercased scheme and host, no fragment).
  defp normalize_allowed(:all), do: :all

  defp normalize_allowed(entries) do
    Enum.map(entries, fn entry ->
      if String.contains?(entry, "://"),
        do: {:uri, normalize_uri(entry)},
        else: {:domain, String.downcase(entry)}
    end)
  end

  defp allowed?(_uri, :all), do: true

  defp allowed?(uri, entries) do
    %URI{scheme: scheme, host: host} = URI.parse(uri)
    normalized = normalize_uri(uri)

    Enum.any?(entries, fn
      {:uri, allowed_uri} ->
        allowed_uri == normalized

      {:domain, domain} ->
        scheme in ["http", "https"] and is_binary(host) and String.downcase(host) == domain
    end)
  end

  defp normalize_uri(uri) do
    parsed = URI.parse(uri)

    %URI{
      parsed
      | scheme: parsed.scheme && String.downcase(parsed.scheme),
        host: parsed.host && String.downcase(parsed.host),
        fragment: nil
    }
    |> URI.to_string()
  end
end
