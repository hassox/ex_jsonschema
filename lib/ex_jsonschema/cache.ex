defmodule ExJsonschema.Cache do
  @moduledoc """
  Behavior for implementing schema compilation caching.

  This behavior defines the interface for cache adapters that can be used
  to cache compiled schemas for improved performance. The library supports
  different cache implementations including in-memory, ETS, distributed caches,
  and custom adapters.

  ## Examples

      # Implementing a simple memory cache
      defmodule MyApp.MemoryCache do
        @behaviour ExJsonschema.Cache
        use GenServer

        def start_link(opts) do
          GenServer.start_link(__MODULE__, %{}, opts)
        end

        @impl ExJsonschema.Cache
        def get(key, opts) do
          case GenServer.call(cache_pid(opts), {:get, key}) do
            {:ok, value} -> {:ok, value}
            :error -> {:error, :not_found}
          end
        end

        @impl ExJsonschema.Cache
        def put(key, value, opts) do
          GenServer.cast(cache_pid(opts), {:put, key, value})
          :ok
        end

        # ... implement other callbacks
      end

  ## Configuration

  By default, the Rust crate handles schema caching internally. This behavior
  is only needed if you want to override the default caching with custom
  implementations (e.g., distributed caching, persistent caching).

      # Configure a custom cache adapter
      config :ex_jsonschema,
        cache_adapter: MyApp.RedisCache

  """

  @type cache_key :: String.t()
  @type cache_value :: ExJsonschema.compiled_schema()
  @type cache_opts :: keyword()

  @doc """
  Retrieves a cached compiled schema by key.

  Returns `{:ok, compiled_schema}` if the schema is found in the cache,
  or `{:error, :not_found}` if not found.
  """
  @callback get(cache_key(), cache_opts()) :: {:ok, cache_value()} | {:error, :not_found}

  @doc """
  Stores a compiled schema in the cache with the given key.

  Returns `:ok` on success or `{:error, reason}` on failure.
  """
  @callback put(cache_key(), cache_value(), cache_opts()) :: :ok | {:error, term()}

  @doc """
  Removes a cached schema by key.

  Returns `:ok` regardless of whether the key existed.
  """
  @callback delete(cache_key(), cache_opts()) :: :ok

  @doc """
  Clears all entries from the cache.

  Returns `:ok` when complete.
  """
  @callback clear(cache_opts()) :: :ok

  @doc """
  Returns the number of entries currently in the cache.

  This is optional - implementations may choose not to track size
  for performance reasons.
  """
  @callback size(cache_opts()) :: non_neg_integer()

  @doc """
  Returns cache statistics including hits, misses, size, etc.

  The returned map structure is implementation-specific but should
  include at least basic metrics like hit/miss ratios if available.

  This is optional - simple cache implementations may not track stats.
  """
  @callback stats(cache_opts()) :: map()

  @optional_callbacks [stats: 1, size: 1]
end
