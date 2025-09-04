defmodule ExJsonschema.ReferenceCache do
  @moduledoc """
  Behavior for implementing external reference caching.

  This behavior defines the interface for caching external schema references
  that have been fetched via retrievers. This is separate from schema compilation
  caching (`ExJsonschema.Cache`) and focuses specifically on raw schema content
  from external sources.

  The reference cache helps avoid redundant network requests and provides
  better performance when schemas reference the same external schemas multiple times.

  ## Examples

      # Implementing a TTL-based reference cache
      defmodule MyApp.ReferenceCache do
        @behaviour ExJsonschema.ReferenceCache
        use GenServer

        def start_link(opts) do
          GenServer.start_link(__MODULE__, %{}, opts)
        end

        @impl ExJsonschema.ReferenceCache
        def get(key, opts) do
          case GenServer.call(cache_pid(opts), {:get, key}) do
            {:ok, {content, expires_at}} ->
              if System.monotonic_time(:second) < expires_at do
                {:ok, content}
              else
                {:error, :not_found}
              end
            :error ->
              {:error, :not_found}
          end
        end

        @impl ExJsonschema.ReferenceCache
        def put(key, content, opts) do
          ttl = Keyword.get(opts, :ttl, 3600) # 1 hour default
          expires_at = System.monotonic_time(:second) + ttl
          GenServer.cast(cache_pid(opts), {:put, key, {content, expires_at}})
          :ok
        end

        # ... implement other callbacks
      end

  ## Configuration

  By default, the Rust crate handles reference caching internally. This behavior
  is only needed if you want custom caching logic (e.g., persistent storage,
  distributed caching, custom TTL policies).

      # Configure a custom reference cache adapter
      config :ex_jsonschema,
        reference_cache: MyApp.ReferenceCache,
        reference_cache_opts: [ttl: 1800] # 30 minutes

  """

  @type cache_key :: String.t()
  @type schema_content :: String.t()
  @type cache_opts :: keyword()

  @doc """
  Retrieves cached schema content by URI key.

  Returns `{:ok, schema_content}` if the schema is found in the cache,
  or `{:error, :not_found}` if not found or expired.

  The cache key is typically the absolute URI of the external schema.
  """
  @callback get(cache_key(), cache_opts()) :: {:ok, schema_content()} | {:error, :not_found}

  @doc """
  Stores schema content in the cache with the given URI key.

  Returns `:ok` on success or `{:error, reason}` on failure.

  The cache implementation may apply TTL, size limits, or other
  eviction policies based on the provided options.
  """
  @callback put(cache_key(), schema_content(), cache_opts()) :: :ok | {:error, term()}

  @doc """
  Removes cached schema content by URI key.

  Returns `:ok` regardless of whether the key existed.
  """
  @callback delete(cache_key(), cache_opts()) :: :ok

  @doc """
  Clears all cached schema references.

  Returns `:ok` when complete. This is optional for implementations
  that don't support bulk clearing.
  """
  @callback clear(cache_opts()) :: :ok

  @optional_callbacks [clear: 1]
end