defmodule ExJsonschema do
  @moduledoc """
  High-performance JSON Schema validation for Elixir using Rust.

  This library provides a fast and spec-compliant JSON Schema validator
  powered by the Rust `jsonschema` crate. It supports multiple JSON Schema
  draft versions and provides detailed validation error information.

  ## Quick Start

      # Compile a schema
      schema = ~s({"type": "object", "properties": {"name": {"type": "string"}}})
      {:ok, compiled} = ExJsonschema.compile(schema)

      # Validate JSON
      valid_json = ~s({"name": "John"})
      :ok = ExJsonschema.validate(compiled, valid_json)

      invalid_json = ~s({"name": 123})
      {:error, errors} = ExJsonschema.validate(compiled, invalid_json)

  ## Features

  - Fast validation using Rust
  - Support for JSON Schema draft-07, draft 2019-09, and draft 2020-12
  - Detailed error messages with path information
  - Precompiled binaries for easy installation
  - Zero Rust toolchain required for end users

  """

  alias ExJsonschema.{Native, ValidationError, CompilationError}

  @type compiled_schema :: reference()
  @type json_string :: String.t()
  @type validation_result :: :ok | {:error, [ValidationError.t()]}

  @doc """
  Compiles a JSON Schema string into an optimized validator.

  ## Examples

      iex> schema = ~s({"type": "string"})
      iex> {:ok, compiled} = ExJsonschema.compile(schema)
      iex> is_reference(compiled)
      true

      iex> invalid_schema = ~s({"type": "invalid_type"})
      iex> {:error, %ExJsonschema.CompilationError{type: :compilation_error}} = ExJsonschema.compile(invalid_schema)

  """
  @spec compile(json_string()) :: {:ok, compiled_schema()} | {:error, CompilationError.t()}
  def compile(schema_json) when is_binary(schema_json) do
    case Native.compile_schema(schema_json) do
      {:ok, compiled} -> {:ok, compiled}
      {:error, error_map} -> {:error, CompilationError.from_map(error_map)}
    end
  end

  @doc """
  Compiles a JSON Schema, raising an exception on failure.

  ## Examples

      iex> schema = ~s({"type": "string"})
      iex> compiled = ExJsonschema.compile!(schema)
      iex> is_reference(compiled)
      true

  """
  @spec compile!(json_string()) :: compiled_schema()
  def compile!(schema_json) when is_binary(schema_json) do
    case compile(schema_json) do
      {:ok, compiled} -> compiled
      {:error, %CompilationError{} = error} -> raise ArgumentError, "Failed to compile schema: #{error}"
    end
  end

  @doc """
  Validates JSON against a compiled schema.

  Returns `:ok` if valid, or `{:error, errors}` with detailed error information.

  ## Examples

      iex> schema = ~s({"type": "string"})
      iex> {:ok, compiled} = ExJsonschema.compile(schema)
      iex> ExJsonschema.validate(compiled, ~s("hello"))
      :ok
      iex> match?({:error, [%ExJsonschema.ValidationError{} | _]}, ExJsonschema.validate(compiled, ~s(123)))
      true

  """
  @spec validate(compiled_schema(), json_string()) :: validation_result()
  def validate(compiled_schema, instance_json) when is_reference(compiled_schema) and is_binary(instance_json) do
    case Native.validate_detailed(compiled_schema, instance_json) do
      :ok -> :ok
      {:error, error_list} when is_list(error_list) ->
        errors = Enum.map(error_list, &ValidationError.from_map/1)
        {:error, errors}
      {:error, _reason} -> {:error, [:validation_error]}
    end
  end

  @doc """
  Validates JSON against a compiled schema, raising an exception on validation failure.

  ## Examples

      iex> schema = ~s({"type": "string"})
      iex> {:ok, compiled} = ExJsonschema.compile(schema)
      iex> ExJsonschema.validate!(compiled, ~s("hello"))
      :ok

  """
  @spec validate!(compiled_schema(), json_string()) :: :ok
  def validate!(compiled_schema, instance_json) do
    case validate(compiled_schema, instance_json) do
      :ok -> :ok
      {:error, errors} -> raise ExJsonschema.ValidationError.Exception, errors: errors
    end
  end

  @doc """
  Checks if JSON is valid against a compiled schema without returning error details.

  This is faster than `validate/2` when you only need to know if the JSON is valid.

  ## Examples

      iex> schema = ~s({"type": "string"})
      iex> {:ok, compiled} = ExJsonschema.compile(schema)
      iex> ExJsonschema.valid?(compiled, ~s("hello"))
      true
      iex> ExJsonschema.valid?(compiled, ~s(123))
      false

  """
  @spec valid?(compiled_schema(), json_string()) :: boolean()
  def valid?(compiled_schema, instance_json) when is_reference(compiled_schema) and is_binary(instance_json) do
    Native.is_valid(compiled_schema, instance_json)
  end

  @doc """
  One-shot validation: compiles schema and validates instance in a single call.

  This is convenient for one-time validations but less efficient for repeated
  validations of the same schema.

  ## Examples

      iex> schema = ~s({"type": "string"})
      iex> ExJsonschema.validate_once(schema, ~s("hello"))
      :ok
      iex> match?({:error, [%ExJsonschema.ValidationError{} | _]}, ExJsonschema.validate_once(schema, ~s(123)))
      true

  """
  @spec validate_once(json_string(), json_string()) :: validation_result() | {:error, CompilationError.t()}
  def validate_once(schema_json, instance_json) do
    with {:ok, compiled} <- compile(schema_json) do
      validate(compiled, instance_json)
    end
  end
end
