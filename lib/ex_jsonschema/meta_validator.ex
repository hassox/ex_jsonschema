defmodule ExJsonschema.MetaValidator do
  @moduledoc """
  Meta-validation functionality for JSON Schema documents.

  Validates that a JSON Schema document is itself a valid schema by attempting
  to compile it. If compilation succeeds, the schema is structurally valid.

  All functions use `external_schemas: :ignore` internally so that external
  `$ref` URIs never trigger network requests. This prevents deadlocks when
  schemas reference the same server (e.g. `http://localhost:4000/...`).

  ## Usage

      # Check if a schema is valid (boolean result)
      schema = ~s({"type": "string", "minLength": 5})
      ExJsonschema.MetaValidator.valid?(schema)
      #=> true

      # Validate with detailed error information
      invalid_schema = ~s({"type": "invalid_type"})
      ExJsonschema.MetaValidator.validate(invalid_schema)
      #=> {:error, [%ExJsonschema.ValidationError{...}]}

      # Simple validation (ok/error result)
      ExJsonschema.MetaValidator.validate_simple(schema)
      #=> :ok

  ## Options

  All functions accept an optional keyword list:

    * `:external_schemas` - Override external schema resolution (default: `:ignore`)
    * `:draft` - Force a specific JSON Schema draft version

  ## Draft Support

  Meta-validation automatically detects the JSON Schema draft version from
  the `$schema` property and validates against the appropriate meta-schema.
  If no `$schema` is present, it defaults to the latest supported draft.

  ## Error Handling

  Meta-validation errors are returned in the same format as regular validation
  errors, making them compatible with all error formatting and analysis tools.
  """

  alias ExJsonschema.{CompilationError, ValidationError}

  @doc """
  Checks if a JSON Schema document is valid against its meta-schema.

  Returns a boolean indicating whether the schema is valid.

  ## Examples

      iex> schema = ~s({"type": "string", "minLength": 5})
      iex> ExJsonschema.MetaValidator.valid?(schema)
      true

      iex> invalid_schema = ~s({"type": "invalid_type"})
      iex> ExJsonschema.MetaValidator.valid?(invalid_schema)
      false

  """
  @spec valid?(binary(), keyword()) :: boolean()
  def valid?(schema_json, opts \\ []) when is_binary(schema_json) do
    case compile_for_meta(schema_json, opts) do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  @doc """
  Validates a JSON Schema document against its meta-schema with simple result.

  Returns `:ok` if valid, or `{:error, reason}` if invalid.

  ## Examples

      iex> schema = ~s({"type": "string", "minLength": 5})
      iex> ExJsonschema.MetaValidator.validate_simple(schema)
      :ok

      iex> invalid_schema = ~s({"type": "invalid_type"})
      iex> ExJsonschema.MetaValidator.validate_simple(invalid_schema)
      {:error, "Schema meta-validation failed"}

  """
  @spec validate_simple(binary(), keyword()) :: :ok | {:error, binary()}
  def validate_simple(schema_json, opts \\ []) when is_binary(schema_json) do
    case compile_for_meta(schema_json, opts) do
      {:ok, _} ->
        :ok

      {:error, %CompilationError{type: :json_parse_error, details: details}} ->
        {:error, "Invalid JSON: #{details}"}

      {:error, %CompilationError{details: details}} when is_binary(details) ->
        {:error, details}

      {:error, _} ->
        {:error, "Schema meta-validation failed"}
    end
  end

  @doc """
  Validates a JSON Schema document against its meta-schema with detailed errors.

  Returns `:ok` if valid, or `{:error, errors}` with detailed error information
  compatible with the standard validation error format.

  ## Examples

      iex> schema = ~s({"type": "string", "minLength": 5})
      iex> ExJsonschema.MetaValidator.validate(schema)
      :ok

      iex> invalid_schema = ~s({"type": "invalid_type"})
      iex> ExJsonschema.MetaValidator.validate(invalid_schema)
      {:error, [%ExJsonschema.ValidationError{...}]}

  """
  @spec validate(binary(), keyword()) ::
          :ok | {:error, [ValidationError.t()]} | {:error, binary()}
  def validate(schema_json, opts \\ []) when is_binary(schema_json) do
    case compile_for_meta(schema_json, opts) do
      {:ok, _} ->
        :ok

      {:error, %CompilationError{type: :json_parse_error, details: details}} ->
        {:error, "Invalid JSON: #{details}"}

      {:error, %CompilationError{} = error} ->
        {:error, [compilation_error_to_validation_error(error)]}
    end
  end

  @doc """
  Validates a JSON Schema document and raises on error.

  Like `validate/1` but raises `ExJsonschema.ValidationError` if validation fails.

  ## Examples

      iex> schema = ~s({"type": "string", "minLength": 5})
      iex> ExJsonschema.MetaValidator.validate!(schema)
      :ok

  """
  @spec validate!(binary(), keyword()) :: :ok
  def validate!(schema_json, opts \\ []) when is_binary(schema_json) do
    case validate(schema_json, opts) do
      :ok ->
        :ok

      {:error, errors} when is_list(errors) ->
        raise hd(errors)

      {:error, reason} when is_binary(reason) ->
        if String.contains?(reason, "Invalid JSON") do
          raise ArgumentError, reason
        else
          raise %ValidationError{
            instance_path: "",
            schema_path: "",
            message: reason,
            keyword: "meta"
          }
        end
    end
  end

  # -- Private --

  # Compile the schema with :ignore to validate structure without network I/O.
  # Merges caller-supplied opts (e.g. draft:) with a forced external_schemas: :ignore default.
  defp compile_for_meta(schema_json, opts) do
    compile_opts =
      opts
      |> Keyword.put_new(:external_schemas, :ignore)

    ExJsonschema.compile(schema_json, compile_opts)
  end

  defp compilation_error_to_validation_error(%CompilationError{} = error) do
    %ValidationError{
      instance_path: "",
      schema_path: "",
      message: error.message <> if(error.details, do: ": #{error.details}", else: ""),
      keyword: "meta"
    }
  end
end
