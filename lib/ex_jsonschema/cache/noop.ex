defmodule ExJsonschema.Cache.Noop do
  @moduledoc """
  A no-operation cache implementation that disables caching.

  This is the default cache used when no cache is configured. All operations
  are no-ops, effectively disabling schema caching.

  ## Usage

  This cache is used by default, or can be explicitly configured:

      config :ex_jsonschema, cache: ExJsonschema.Cache.Noop
  """

  @behaviour ExJsonschema.Cache

  @impl ExJsonschema.Cache
  def get(_key) do
    {:error, :not_found}
  end

  @impl ExJsonschema.Cache
  def put(_key, _value) do
    :ok
  end

  @impl ExJsonschema.Cache
  def delete(_key) do
    :ok
  end

  @impl ExJsonschema.Cache
  def clear do
    :ok
  end
end
