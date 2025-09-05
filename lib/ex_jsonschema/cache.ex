defmodule ExJsonschema.Cache do
  @moduledoc """
  Behaviour for caching compiled JSON schemas.

  This behaviour defines the interface for caching compiled schemas by their ID.
  Implementations can be stateless modules, GenServers, or any other approach.

  ## Configuration

  Configure which cache module to use:

      config :ex_jsonschema, cache: MyApp.EtsCache

  ## Default

  By default, uses `ExJsonschema.Cache.Noop` which disables caching.

  ## Testing

  Use `ExJsonschema.Cache.Test` for isolated test caches:

      # Async tests (process-isolated)
      setup do
        test_cache = start_supervised!({Agent, fn -> %{} end})
        cleanup = ExJsonschema.Cache.Test.setup_process_mode(test_cache)
        on_exit(cleanup)
        :ok
      end

      # Non-async tests (global, works with spawns)
      setup do
        test_cache = start_supervised!({Agent, fn -> %{} end})
        cleanup = ExJsonschema.Cache.Test.setup_global_mode(test_cache)
        on_exit(cleanup)
        :ok
      end
  """

  @doc """
  Retrieves a compiled schema from the cache.

  Returns `{:ok, compiled_schema}` if found, `{:error, :not_found}` otherwise.
  """
  @callback get(key :: binary()) :: {:ok, term()} | {:error, :not_found}

  @doc """
  Stores a compiled schema in the cache.

  Returns `:ok` on success.
  """
  @callback put(key :: binary(), value :: term()) :: :ok

  @doc """
  Removes a specific entry from the cache.

  Returns `:ok` regardless of whether the key existed.
  """
  @callback delete(key :: binary()) :: :ok

  @doc """
  Clears all entries from the cache.

  Returns `:ok`.
  """
  @callback clear() :: :ok
end
