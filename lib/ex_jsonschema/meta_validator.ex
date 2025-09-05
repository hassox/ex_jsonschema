defmodule ExJsonschema.MetaValidator do
  @moduledoc """
  Meta-validation functionality for JSON Schema documents.

  This module provides functions to validate JSON Schema documents against their
  respective meta-schemas, ensuring that schemas themselves are valid before
  being used for validation.

  Meta-validation checks that a JSON Schema document:
  - Follows the correct structure for its draft version
  - Uses valid keywords and syntax
  - Meets the constraints defined by the meta-schema
  - Is properly formatted and complete

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

  ## Draft Support

  Meta-validation automatically detects the JSON Schema draft version from
  the `$schema` property and validates against the appropriate meta-schema.
  If no `$schema` is present, it defaults to the latest supported draft.

  ## Error Handling

  Meta-validation errors are returned in the same format as regular validation
  errors, making them compatible with all error formatting and analysis tools.
  """

  alias ExJsonschema.{Native, ValidationError}

  # URLs that DON'T cause panics in the Rust crate (whitelist approach)
  # Based on testing, these are the only known working $schema URLs
  # TODO: Remove this workaround once upstream jsonschema crate is fixed
  # See: https://github.com/Stranger6667/jsonschema-rs/issues/XXX
  @safe_schema_urls [
    "http://json-schema.org/draft-04/schema#",
    "http://json-schema.org/draft-04/schema",
    "https://json-schema.org/draft/2019-09/schema",
    "https://json-schema.org/draft/2020-12/schema"
  ]

  @doc """
  Checks if a JSON Schema document is valid against its meta-schema.

  Returns a boolean indicating whether the schema is valid.

  ## Examples

      iex> schema = ~s({"type": "string", "minLength": 5})
      iex> ExJsonschema.MetaValidator.valid?(schema)
      true

      iex> invalid_schema = ~s({"type": "invalid_type"})
      iex> ExJsonschema.MetaValidator.valid?(schema)
      false

  ## Parameters

  - `schema_json` - A JSON string containing the schema to validate

  ## Returns

  - `true` if the schema is valid
  - `false` if the schema is invalid
  - Raises `ArgumentError` if the JSON is malformed
  """
  @spec valid?(binary()) :: boolean()
  def valid?(schema_json) when is_binary(schema_json) do
    # Preprocess to avoid Rust crate panics on problematic $schema URLs
    safe_schema = preprocess_schema_for_rust(schema_json)

    case Native.meta_is_valid(safe_schema) do
      {:ok, result} ->
        result

      {:error, %{"type" => "json_parse_error"} = error} ->
        raise ArgumentError, "Invalid JSON: #{Map.get(error, "details", "malformed JSON")}"

      {:error, _} ->
        false
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

  ## Parameters

  - `schema_json` - A JSON string containing the schema to validate

  ## Returns

  - `:ok` if the schema is valid
  - `{:error, reason}` if the schema is invalid or JSON is malformed
  """
  @spec validate_simple(binary()) :: :ok | {:error, binary()}
  def validate_simple(schema_json) when is_binary(schema_json) do
    # Preprocess to avoid Rust crate panics on problematic $schema URLs
    safe_schema = preprocess_schema_for_rust(schema_json)

    case Native.meta_validate(safe_schema) do
      :ok ->
        :ok

      {:error, %{"type" => "json_parse_error", "details" => details}} ->
        {:error, "Invalid JSON: #{details}"}

      {:error, %{"type" => "meta_validation_error", "details" => details}} ->
        {:error, details}

      {:error, %{"details" => details}} ->
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
      {:error, [%ExJsonschema.ValidationError{
        instance_path: "",
        schema_path: "",
        message: "...",
        keyword: "meta"
      }]}

  ## Parameters

  - `schema_json` - A JSON string containing the schema to validate

  ## Returns

  - `:ok` if the schema is valid
  - `{:error, [ExJsonschema.ValidationError.t()]}` if the schema is invalid
  - `{:error, reason}` if JSON parsing fails
  """
  @spec validate(binary()) :: :ok | {:error, [ValidationError.t()]} | {:error, binary()}
  def validate(schema_json) when is_binary(schema_json) do
    # Preprocess to avoid Rust crate panics on problematic $schema URLs
    safe_schema = preprocess_schema_for_rust(schema_json)

    case Native.meta_validate_detailed(safe_schema) do
      :ok ->
        :ok

      {:error, %{"type" => "json_parse_error", "details" => details}} ->
        {:error, "Invalid JSON: #{details}"}

      {:error, error_list} when is_list(error_list) ->
        errors = Enum.map(error_list, &convert_to_validation_error/1)
        {:error, errors}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Validates a JSON Schema document and raises on error.

  Like `validate/1` but raises `ExJsonschema.ValidationError` if validation fails.

  ## Examples

      iex> schema = ~s({"type": "string", "minLength": 5})
      iex> ExJsonschema.MetaValidator.validate!(schema)
      :ok

      iex> invalid_schema = ~s({"type": "invalid_type"})
      iex> ExJsonschema.MetaValidator.validate!(invalid_schema)
      ** (ExJsonschema.ValidationError) Schema meta-validation failed

  ## Parameters

  - `schema_json` - A JSON string containing the schema to validate

  ## Returns

  - `:ok` if the schema is valid
  - Raises `ExJsonschema.ValidationError` if validation fails
  - Raises `ArgumentError` if JSON is malformed
  """
  @spec validate!(binary()) :: :ok
  def validate!(schema_json) when is_binary(schema_json) do
    case validate(schema_json) do
      :ok ->
        :ok

      {:error, errors} when is_list(errors) ->
        [first_error | _] = errors
        raise first_error

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

  # Safely preprocess schema JSON to avoid known Rust crate panics
  # TODO: Remove this workaround once upstream jsonschema crate is fixed
  defp preprocess_schema_for_rust(schema_json) when is_binary(schema_json) do
    case Jason.decode(schema_json) do
      {:ok, schema_map} when is_map(schema_map) ->
        case Map.get(schema_map, "$schema") do
          schema_url when is_binary(schema_url) ->
            if schema_url in @safe_schema_urls do
              # Known safe URL - use original schema
              schema_json
            else
              # Unknown/problematic URL - remove to prevent panic, let Rust use default
              safe_schema = Map.delete(schema_map, "$schema")
              Jason.encode!(safe_schema)
            end

          schema_url when not is_nil(schema_url) ->
            # Non-string, non-nil $schema value - fail fast (Elixir philosophy)
            raise ArgumentError, "$schema must be a string, got: #{inspect(schema_url)}"

          nil ->
            # No $schema property - safe to use as-is
            schema_json
        end

      {:ok, _non_map} ->
        # Boolean schema or other valid JSON - safe to use as-is
        schema_json

      {:error, _} ->
        # Invalid JSON - let the Rust crate handle the error properly
        schema_json
    end
  rescue
    # If JSON processing fails, use original (let Rust handle the error)
    Jason.EncodeError -> schema_json
  end

  # Private helper to convert native error maps to ValidationError structs
  defp convert_to_validation_error(error_map) when is_map(error_map) do
    %ValidationError{
      instance_path: Map.get(error_map, "instance_path", ""),
      schema_path: Map.get(error_map, "schema_path", ""),
      message: Map.get(error_map, "message", "Unknown meta-validation error"),
      keyword: Map.get(error_map, "keyword", "meta"),
      instance_value: Map.get(error_map, "instance_value"),
      schema_value: Map.get(error_map, "schema_value"),
      context: Map.get(error_map, "context", %{}),
      annotations: Map.get(error_map, "annotations", %{}),
      suggestions: Map.get(error_map, "suggestions", [])
    }
  end
end
