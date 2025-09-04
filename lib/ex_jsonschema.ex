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

  ## Output Formats

  ExJsonschema supports multiple output formats for different use cases:

  ### Basic Format (fastest)
  Returns simple boolean-style results for when you only need to know if validation passed:

      {:ok, validator} = ExJsonschema.compile(~s({"type": "string"}))
      
      ExJsonschema.validate(validator, ~s("hello"), output: :basic)
      #=> :ok
      
      ExJsonschema.validate(validator, ~s(123), output: :basic)
      #=> {:error, :validation_failed}

  ### Detailed Format (default)
  Returns structured error information with paths and messages:

      {:ok, validator} = ExJsonschema.compile(~s({
        "type": "object",
        "properties": {"age": {"type": "number", "minimum": 18}},
        "required": ["age"]
      }))
      
      ExJsonschema.validate(validator, ~s({"age": 15}))
      #=> {:error, [
      #     %ExJsonschema.ValidationError{
      #       instance_path: "/age",
      #       schema_path: "/properties/age/minimum", 
      #       message: "15 is less than the minimum of 18"
      #     }
      #   ]}

  ### Verbose Format (comprehensive)
  Returns detailed errors with additional context, suggestions, and metadata:

      ExJsonschema.validate(validator, ~s({"age": 15}), output: :verbose)
      #=> {:error, [
      #     %ExJsonschema.ValidationError{
      #       instance_path: "/age",
      #       schema_path: "/properties/age/minimum",
      #       message: "15 is less than the minimum of 18",
      #       keyword: "minimum",
      #       instance_value: 15,
      #       schema_value: 18,
      #       context: %{
      #         "expected" => "value >= minimum",
      #         "actual" => 15
      #       },
      #       suggestions: ["Ensure the value meets the minimum requirement"]
      #     }
      #   ]}

  ## Features

  - Fast validation using Rust (2M+ validations/second)
  - Support for JSON Schema draft-07, draft 2019-09, and draft 2020-12
  - Multiple output formats for different use cases
  - Detailed error messages with path information
  - Comprehensive error context in verbose mode
  - Precompiled binaries for easy installation
  - Zero Rust toolchain required for end users

  """

  alias ExJsonschema.{CompilationError, DraftDetector, Native, Options, ValidationError}

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
    compile(schema_json, [])
  end

  @doc """
  Compiles a JSON Schema string with options into an optimized validator.

  ## Options

  Accepts either an `ExJsonschema.Options` struct or keyword list of options.
  When using `:auto` draft detection, the `$schema` property in the schema
  will be examined to determine the appropriate JSON Schema draft version.

  ## Examples

      # With Options struct
      iex> opts = ExJsonschema.Options.new(draft: :draft7, validate_formats: true)
      iex> schema = ~s({"type": "string"})
      iex> {:ok, compiled} = ExJsonschema.compile(schema, opts)
      iex> is_reference(compiled)
      true

      # With keyword list
      iex> schema = ~s({"type": "string"})
      iex> {:ok, compiled} = ExJsonschema.compile(schema, draft: :auto)
      iex> is_reference(compiled)
      true

      # Automatic draft detection
      iex> schema_with_draft = ~s({"$schema": "http://json-schema.org/draft-07/schema#", "type": "string"})
      iex> {:ok, compiled} = ExJsonschema.compile(schema_with_draft, draft: :auto)
      iex> is_reference(compiled)
      true

  """
  @spec compile(json_string(), Options.t() | keyword()) :: {:ok, compiled_schema()} | {:error, CompilationError.t()}
  def compile(schema_json, %Options{} = options) when is_binary(schema_json) do
    compile_with_options(schema_json, options)
  end

  def compile(schema_json, options) when is_binary(schema_json) and is_list(options) do
    case Options.validate(Options.new(options)) do
      {:ok, validated_options} -> compile_with_options(schema_json, validated_options)
      {:error, reason} -> {:error, CompilationError.from_options_error(reason)}
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
      {:ok, compiled} ->
        compiled

      {:error, %CompilationError{} = error} ->
        raise ArgumentError, "Failed to compile schema: #{error}"
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
  def validate(compiled_schema, instance_json)
      when is_reference(compiled_schema) and is_binary(instance_json) do
    validate(compiled_schema, instance_json, [])
  end

  @doc """
  Validates JSON against a compiled schema with output format control.

  ## Output Formats
  
  - `:basic` - Returns `:ok` or `{:error, :validation_failed}` (fastest)
  - `:detailed` - Returns `:ok` or `{:error, [ValidationError.t()]}` (default)
  - `:verbose` - Returns detailed errors with additional context, values, and suggestions

  ## Options

  - `output: :basic | :detailed | :verbose` - Controls error output format (default: `:detailed`)
  - Other validation options (format validation, etc.) can be passed through

  ## Examples

      # Basic format (fastest)
      iex> schema = ~s({"type": "string"})
      iex> {:ok, compiled} = ExJsonschema.compile(schema)
      iex> ExJsonschema.validate(compiled, ~s("hello"), output: :basic)
      :ok
      iex> ExJsonschema.validate(compiled, ~s(123), output: :basic)
      {:error, :validation_failed}

      # Detailed format (default)
      iex> ExJsonschema.validate(compiled, ~s(123), output: :detailed)
      {:error, [%ExJsonschema.ValidationError{message: _, instance_path: "", schema_path: _}]}

      # Verbose format (comprehensive)
      iex> result = ExJsonschema.validate(compiled, ~s(123), output: :verbose)
      iex> match?({:error, [%ExJsonschema.ValidationError{keyword: "type", instance_value: 123}]}, result)
      true

  """
  @spec validate(compiled_schema(), json_string(), keyword()) :: validation_result() | {:error, :validation_failed}
  def validate(compiled_schema, instance_json, opts)
      when is_reference(compiled_schema) and is_binary(instance_json) and is_list(opts) do
    output_format = Keyword.get(opts, :output, :detailed)
    
    case output_format do
      :basic -> validate_basic(compiled_schema, instance_json)
      :detailed -> validate_detailed(compiled_schema, instance_json)
      :verbose -> validate_verbose(compiled_schema, instance_json, opts)
      _ -> raise ArgumentError, "Invalid output format: #{inspect(output_format)}. Must be one of: :basic, :detailed, :verbose"
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
  def valid?(compiled_schema, instance_json)
      when is_reference(compiled_schema) and is_binary(instance_json) do
    Native.valid?(compiled_schema, instance_json)
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
  @spec validate_once(json_string(), json_string()) ::
          validation_result() | {:error, CompilationError.t()}
  def validate_once(schema_json, instance_json) do
    with {:ok, compiled} <- compile(schema_json) do
      validate(compiled, instance_json)
    end
  end

  @doc """
  Detects the JSON Schema draft version from a schema document.

  This function examines the `$schema` property to determine which JSON Schema
  draft version the schema is written for. If no `$schema` is present or the
  URL is unrecognized, it returns the default draft (2020-12).

  ## Examples

      # Schema with explicit draft
      iex> schema = ~s({"$schema": "http://json-schema.org/draft-07/schema#", "type": "string"})
      iex> ExJsonschema.detect_draft(schema)
      {:ok, :draft7}

      # Schema without $schema (uses default)
      iex> schema = ~s({"type": "number"})
      iex> ExJsonschema.detect_draft(schema)
      {:ok, :draft202012}

      # Map input
      iex> schema = %{"$schema" => "https://json-schema.org/draft/2020-12/schema", "type" => "object"}
      iex> ExJsonschema.detect_draft(schema)
      {:ok, :draft202012}

  """
  @spec detect_draft(json_string() | map()) :: {:ok, Options.draft()} | {:error, String.t()}
  def detect_draft(schema) do
    DraftDetector.detect_draft(schema)
  end

  @doc """
  Returns all supported JSON Schema draft versions.

  ## Examples

      iex> drafts = ExJsonschema.supported_drafts()
      iex> :draft7 in drafts
      true
      iex> :draft202012 in drafts
      true

  """
  @spec supported_drafts() :: [Options.draft()]
  def supported_drafts do
    DraftDetector.supported_drafts()
  end

  # Private validation functions for different output formats

  defp validate_basic(compiled_schema, instance_json) do
    if Native.valid?(compiled_schema, instance_json) do
      :ok
    else
      {:error, :validation_failed}
    end
  end

  defp validate_detailed(compiled_schema, instance_json) do
    case Native.validate_detailed(compiled_schema, instance_json) do
      :ok ->
        :ok

      {:error, error_list} when is_list(error_list) ->
        errors = Enum.map(error_list, &ValidationError.from_detailed_map/1)
        {:error, errors}

      {:error, _reason} ->
        {:error, [:validation_error]}
    end
  end

  defp validate_verbose(compiled_schema, instance_json, _opts) do
    case Native.validate_verbose(compiled_schema, instance_json) do
      :ok ->
        :ok

      {:error, error_list} when is_list(error_list) ->
        errors = Enum.map(error_list, &ValidationError.from_map/1)
        {:error, errors}

      {:error, _reason} ->
        {:error, [:validation_error]}
    end
  end


  # Private functions

  defp compile_with_options(schema_json, %Options{draft: :auto} = options) do
    # Auto-detect draft from schema and update options
    case DraftDetector.detect_draft(schema_json) do
      {:ok, detected_draft} ->
        updated_options = %{options | draft: detected_draft}
        compile_with_native_options(schema_json, updated_options)

      {:error, reason} ->
        {:error, CompilationError.from_detection_error(reason)}
    end
  end

  defp compile_with_options(schema_json, %Options{} = options) do
    compile_with_native_options(schema_json, options)
  end

  defp compile_with_native_options(schema_json, %Options{} = options) do
    # For M1.4: Options-aware compilation with validation
    case validate_compilation_options(schema_json, options) do
      :ok ->
        # Use the validated options - for now, we use basic compilation
        # Full options support will come in later milestones
        case Native.compile_schema(schema_json) do
          {:ok, compiled} -> {:ok, compiled}
          {:error, error_map} -> {:error, CompilationError.from_map(error_map)}
        end
      
      {:error, reason} ->
        {:error, CompilationError.from_validation_error(reason)}
    end
  end

  # Validates that compilation options are consistent with the schema
  defp validate_compilation_options(schema_json, %Options{draft: draft} = _options) do
    # When draft is not :auto, validate it matches schema if schema has $schema
    case DraftDetector.detect_draft(schema_json) do
      {:ok, detected_draft} ->
        if draft != :auto and draft != detected_draft do
          case DraftDetector.schema_has_draft?(schema_json) do
            true ->
              {:error, "Schema specifies #{detected_draft} but options specify #{draft}"}
            false ->
              :ok # No $schema in document, options draft is fine
          end
        else
          :ok
        end
      
      {:error, reason} ->
        {:error, "Draft detection failed: #{reason}"}
    end
  end
end
