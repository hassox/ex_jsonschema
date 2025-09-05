defmodule ExJsonschema.Cache.Test do
  @moduledoc """
  Test cache implementation using process dictionary and Application environment.
  
  This cache is designed for testing and supports both async and non-async tests:
  
  - **Async tests**: Use process-local cache via `set_cache_for_process/1`
  - **Non-async tests**: Use Application environment via `set_global_cache/1` 
  
  ## Usage
  
  ### Async Tests (isolated per-process):
  
      setup do
        test_cache = start_supervised!({Agent, fn -> %{} end})
        ExJsonschema.Cache.Test.set_cache_for_process(test_cache)
        :ok
      end
      
  ### Non-async Tests (global, works with spawns):
  
      setup do
        test_cache = start_supervised!({Agent, fn -> %{} end})
        ExJsonschema.Cache.Test.set_global_cache(test_cache)
        
        on_exit(fn -> 
          ExJsonschema.Cache.Test.clear_global_cache()
        end)
        
        :ok
      end
  """
  
  @behaviour ExJsonschema.Cache
  
  @global_cache_key :ex_jsonschema_test_cache_global
  
  @doc """
  Sets the cache pid/name for the current process.
  
  This cache will only be available to the current process and any processes
  spawned from it that explicitly inherit the process dictionary.
  """
  def set_cache_for_process(pid_or_name) do
    Process.put(__MODULE__, pid_or_name)
  end
  
  @doc """
  Sets the global cache pid/name for non-async tests.
  
  This cache will be available to all processes, including spawned tasks.
  Should only be used in non-async tests to avoid conflicts.
  """
  def set_global_cache(pid_or_name) do
    Application.put_env(:ex_jsonschema, @global_cache_key, pid_or_name)
  end
  
  @doc """
  Clears the global cache reference.
  
  Should be called in test cleanup to avoid test pollution.
  """
  def clear_global_cache do
    Application.delete_env(:ex_jsonschema, @global_cache_key)
  end

  @doc """
  Sets up the test cache in global mode for non-async tests.
  
  Returns a cleanup function that should be called in test teardown.
  
  ## Usage
  
      setup do
        test_cache = start_supervised!({Agent, fn -> %{} end})
        cleanup = ExJsonschema.Cache.Test.setup_global_mode(test_cache)
        
        on_exit(cleanup)
        :ok
      end
  """
  def setup_global_mode(cache_pid) do
    # Store original config
    original_cache = Application.get_env(:ex_jsonschema, :cache)
    
    # Set up test cache globally
    set_global_cache(cache_pid)
    Application.put_env(:ex_jsonschema, :cache, __MODULE__)
    
    # Return cleanup function
    fn ->
      clear_global_cache()
      case original_cache do
        nil -> Application.delete_env(:ex_jsonschema, :cache)
        cache -> Application.put_env(:ex_jsonschema, :cache, cache)
      end
    end
  end

  @doc """
  Sets up the test cache in process-local mode for async tests.
  
  Returns a cleanup function that should be called in test teardown.
  
  ## Usage
  
      setup do
        test_cache = start_supervised!({Agent, fn -> %{} end})
        cleanup = ExJsonschema.Cache.Test.setup_process_mode(test_cache)
        
        on_exit(cleanup)
        :ok
      end
  """
  def setup_process_mode(cache_pid) do
    # Store original config
    original_cache = Application.get_env(:ex_jsonschema, :cache)
    
    # Set up test cache for current process
    set_cache_for_process(cache_pid)
    Application.put_env(:ex_jsonschema, :cache, __MODULE__)
    
    # Return cleanup function
    fn ->
      case original_cache do
        nil -> Application.delete_env(:ex_jsonschema, :cache)
        cache -> Application.put_env(:ex_jsonschema, :cache, cache)
      end
    end
  end
  
  @impl ExJsonschema.Cache
  def get(key) do
    case get_cache_pid() do
      nil -> 
        {:error, :no_test_cache_configured}
      pid_or_name ->
        try do
          case Agent.get(pid_or_name, &Map.get(&1, key)) do
            nil -> {:error, :not_found}
            value -> {:ok, value}
          end
        rescue
          _ -> {:error, :not_found}
        end
    end
  end
  
  @impl ExJsonschema.Cache
  def put(key, value) do
    case get_cache_pid() do
      nil -> 
        :ok  # Silently ignore if no cache configured
      pid_or_name ->
        try do
          Agent.update(pid_or_name, &Map.put(&1, key, value))
          :ok
        rescue
          _ -> :ok
        end
    end
  end
  
  @impl ExJsonschema.Cache
  def delete(key) do
    case get_cache_pid() do
      nil ->
        :ok
      pid_or_name ->
        try do
          Agent.update(pid_or_name, &Map.delete(&1, key))
          :ok
        rescue
          _ -> :ok
        end
    end
  end
  
  @impl ExJsonschema.Cache
  def clear do
    case get_cache_pid() do
      nil ->
        :ok
      pid_or_name ->
        try do
          Agent.update(pid_or_name, fn _ -> %{} end)
          :ok
        rescue
          _ -> :ok
        end
    end
  end
  
  defp get_cache_pid do
    # Try process dictionary first (async tests)
    case Process.get(__MODULE__) do
      nil -> 
        # Fall back to application environment (non-async tests)
        Application.get_env(:ex_jsonschema, @global_cache_key)
      pid_or_name -> 
        pid_or_name
    end
  end
end