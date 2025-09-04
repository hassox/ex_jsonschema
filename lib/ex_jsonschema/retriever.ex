defmodule ExJsonschema.Retriever do
  @moduledoc """
  Behavior for implementing external schema retrieval.

  This behavior defines the interface for retriever adapters that can fetch
  external schemas referenced by `$ref` properties. The library supports
  different retrieval mechanisms including HTTP, file system, databases,
  cloud storage, and custom adapters.

  ## Examples

      # Implementing an HTTP retriever
      defmodule MyApp.HTTPRetriever do
        @behaviour ExJsonschema.Retriever

        @impl ExJsonschema.Retriever
        def retrieve(uri, opts) do
          timeout = Keyword.get(opts, :timeout, 5000)
          
          case HTTPoison.get(uri, [], timeout: timeout) do
            {:ok, %{status_code: 200, body: body}} ->
              {:ok, body}
            
            {:ok, %{status_code: code}} ->
              {:error, {:http_error, code}}
            
            {:error, reason} ->
              {:error, reason}
          end
        end

        @impl ExJsonschema.Retriever
        def retrieve_async(uri, opts) do
          Task.async(fn -> retrieve(uri, opts) end)
        end
      end

  ## Configuration

  By default, the Rust crate handles HTTP retrieval automatically. This behavior
  is only needed if you want custom retrieval logic (e.g., authentication,
  different protocols, database storage).

      # Configure a custom retriever adapter
      config :ex_jsonschema,
        retriever: MyApp.CustomRetriever,
        retriever_opts: [timeout: 10_000]

  """

  @type uri :: String.t()
  @type schema_content :: String.t()
  @type retriever_opts :: keyword()

  @doc """
  Retrieves a schema from the given URI.

  The URI may be an absolute URL, relative URL, or custom protocol URI
  depending on the retriever implementation. Returns the raw schema
  content as a string.

  ## Options

  Common options that retrievers may support:
  - `:timeout` - Request timeout in milliseconds
  - `:retries` - Number of retry attempts
  - `:headers` - HTTP headers (for HTTP retrievers)
  - `:base_uri` - Base URI for resolving relative references

  """
  @callback retrieve(uri(), retriever_opts()) :: {:ok, schema_content()} | {:error, term()}

  @doc """
  Asynchronously retrieves a schema from the given URI.

  Returns a `Task` that can be awaited for the result. This is useful
  for fetching multiple schemas concurrently.

  This callback is optional - synchronous-only retrievers may omit it.
  """
  @callback retrieve_async(uri(), retriever_opts()) :: Task.t()

  @optional_callbacks [retrieve_async: 2]
end
