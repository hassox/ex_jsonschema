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

  ## Validation Options

  ExJsonschema supports configurable validation options:

      # Enable format validation
      ExJsonschema.validate(validator, json, validate_formats: true)
      
      # Stop on first error for faster validation
      ExJsonschema.validate(validator, json, stop_on_first_error: true)
      
      # Use Options struct for reusable configuration
      opts = ExJsonschema.Options.new(
        output_format: :verbose,
        validate_formats: true,
        stop_on_first_error: false
      )
      ExJsonschema.validate(validator, json, opts)

      # Quick validation with options
      ExJsonschema.valid?(validator, json, validate_formats: true)

  ## Configuration Profiles

  ExJsonschema includes three predefined profiles optimized for common use cases:

      # Strict validation for APIs and compliance
      strict_opts = ExJsonschema.Options.new(:strict)
      {:ok, validator} = ExJsonschema.compile(schema, strict_opts)
      
      # Lenient validation for user forms
      lenient_opts = ExJsonschema.Options.new(:lenient)
      ExJsonschema.validate(validator, user_data, lenient_opts)
      
      # Performance-optimized for high-volume processing
      perf_opts = ExJsonschema.Options.new(:performance)
      is_valid = ExJsonschema.valid?(validator, data, perf_opts)
      
      # Customize any profile with overrides
      custom = ExJsonschema.Options.new({:strict, [output_format: :basic]})

  Profiles can also be accessed through the Profile module:

      ExJsonschema.Profile.strict(validate_formats: true)
      ExJsonschema.Profile.lenient(draft: :draft7)
      ExJsonschema.Profile.performance(output_format: :detailed)

  ## Features

  - High-performance validation using Rust (1.4M-1.9M validations/second)
  - Support for JSON Schema draft-07, draft 2019-09, and draft 2020-12
  - Multiple output formats: basic (fastest), detailed (default), verbose (comprehensive)
  - Configurable validation options for format validation, error handling, and annotations
  - Both keyword list and Options struct interfaces
  - Detailed error messages with path information and suggestions
  - Built-in performance benchmarking via `mix benchmark`
  - Precompiled binaries for easy installation
  - Zero Rust toolchain required for end users

  """

  alias ExJsonschema.{CompilationError, DraftDetector, Native, Options, ValidationError}

  @typedoc """
  A compiled JSON Schema validator optimized for repeated use.

  This is an opaque reference to a compiled schema stored in the Rust NIF.
  Compile once with `compile/1` or `compile/2`, then use multiple times 
  with `validate/2`, `validate/3`, or `valid?/2`, `valid?/3`.

  ## Performance Note
  Compiled schemas are significantly faster than one-shot validation
  when validating multiple instances against the same schema.
  """
  @type compiled_schema :: reference()

  @typedoc """
  A JSON document represented as a string.

  Must be valid JSON syntax. Both the schema and instance documents
  are expected to be JSON strings that will be parsed by the Rust NIF.

  ## Examples
      "{\\"type\\": \\"string\\"}"
      "{\\"name\\": \\"John\\", \\"age\\": 30}"
      "[\\"item1\\", \\"item2\\", \\"item3\\"]"
  """
  @type json_string :: String.t()

  @typedoc """
  Result of validation operations.

  - `:ok` - Validation succeeded, the instance is valid
  - `{:error, [ValidationError.t()]}` - Validation failed with detailed error information

  The error list contains structured error information including:
  - Instance path (where the error occurred)  
  - Schema path (which schema rule failed)
  - Descriptive error message
  - Additional context in verbose mode
  """
  @type validation_result :: :ok | {:error, [ValidationError.t()]}

  @typedoc """
  Result of basic validation operations.

  - `:ok` - Validation succeeded
  - `{:error, :validation_failed}` - Validation failed (no detailed errors)

  This is returned by validation with `output: :basic` for fastest performance
  when you only need to know if validation passed or failed.
  """
  @type basic_validation_result :: :ok | {:error, :validation_failed}

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
  Validates JSON against a compiled schema with output format and validation options control.

  ## Output Formats
  
  - `:basic` - Returns `:ok` or `{:error, :validation_failed}` (fastest)
  - `:detailed` - Returns `:ok` or `{:error, [ValidationError.t()]}` (default)
  - `:verbose` - Returns detailed errors with additional context, values, and suggestions

  ## Validation Options

  - `output: :basic | :detailed | :verbose` - Controls error output format (default: `:detailed`)
  - `validate_formats: boolean()` - Enable format validation (default: `false`)
  - `ignore_unknown_formats: boolean()` - Ignore unknown format assertions (default: `true`)
  - `stop_on_first_error: boolean()` - Stop validation on first error (default: `false`)
  - `collect_annotations: boolean()` - Collect annotations during validation (default: `true`)

  ## Examples

      # Basic format (fastest)
      iex> schema = ~s({"type": "string"})
      iex> {:ok, compiled} = ExJsonschema.compile(schema)
      iex> ExJsonschema.validate(compiled, ~s("hello"), output: :basic)
      :ok
      iex> ExJsonschema.validate(compiled, ~s(123), output: :basic)
      {:error, :validation_failed}

      # With format validation enabled
      iex> schema = ~s({"type": "string", "format": "email"})
      iex> {:ok, compiled} = ExJsonschema.compile(schema)
      iex> ExJsonschema.validate(compiled, ~s("not-email"), validate_formats: true)
      {:error, [%ExJsonschema.ValidationError{}]}

      # Stop on first error
      iex> ExJsonschema.validate(compiled, ~s(123), stop_on_first_error: true)
      {:error, [%ExJsonschema.ValidationError{}]}

  """
  @spec validate(compiled_schema(), json_string(), keyword() | Options.t()) :: validation_result() | basic_validation_result()
  
  # Accept Options struct
  def validate(compiled_schema, instance_json, %Options{} = options)
      when is_reference(compiled_schema) and is_binary(instance_json) do
    validate_with_options(compiled_schema, instance_json, options)
  end
  
  # Accept keyword list
  def validate(compiled_schema, instance_json, opts)
      when is_reference(compiled_schema) and is_binary(instance_json) and is_list(opts) do
    validated_options = validate_and_normalize_options(opts)
    validate_with_options(compiled_schema, instance_json, validated_options)
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
  Checks if JSON is valid against a compiled schema with validation options.

  This is faster than `validate/3` when you only need to know if the JSON is valid and
  supports validation options like format validation.

  ## Validation Options

  - `validate_formats: boolean()` - Enable format validation (default: `false`)
  - `ignore_unknown_formats: boolean()` - Ignore unknown format assertions (default: `true`)
  - `stop_on_first_error: boolean()` - Stop validation on first error (default: `false`)
  - `collect_annotations: boolean()` - Collect annotations during validation (default: `true`)

  ## Examples

      iex> schema = ~s({"type": "string", "format": "email"})
      iex> {:ok, compiled} = ExJsonschema.compile(schema)
      iex> ExJsonschema.valid?(compiled, ~s("test@example.com"), validate_formats: true)
      true
      iex> ExJsonschema.valid?(compiled, ~s("not-email"), validate_formats: true)
      false

  """
  @spec valid?(compiled_schema(), json_string(), keyword() | Options.t()) :: boolean()
  
  # Accept Options struct
  def valid?(compiled_schema, instance_json, %Options{} = options)
      when is_reference(compiled_schema) and is_binary(instance_json) do
    valid_with_options(compiled_schema, instance_json, options)
  end
  
  # Accept keyword list
  def valid?(compiled_schema, instance_json, opts)
      when is_reference(compiled_schema) and is_binary(instance_json) and is_list(opts) do
    validated_options = validate_and_normalize_options(opts)
    valid_with_options(compiled_schema, instance_json, validated_options)
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

  # Private helper functions for validation options

  defp validate_and_normalize_options(opts) do
    # Validate each option
    valid_options = [:output, :validate_formats, :ignore_unknown_formats, 
                     :stop_on_first_error, :collect_annotations]
    
    # Check for invalid options
    invalid_opts = Keyword.keys(opts) -- valid_options
    unless Enum.empty?(invalid_opts) do
      raise ArgumentError, "Invalid validation option(s): #{inspect(invalid_opts)}. " <>
                          "Valid options are: #{inspect(valid_options)}"
    end
    
    # Validate boolean options
    boolean_opts = [:validate_formats, :ignore_unknown_formats, :stop_on_first_error, :collect_annotations]
    for opt <- boolean_opts do
      if Keyword.has_key?(opts, opt) do
        value = Keyword.get(opts, opt)
        unless is_boolean(value) do
          raise ArgumentError, "Option #{inspect(opt)} must be a boolean, got: #{inspect(value)}"
        end
      end
    end
    
    # Validate output format
    if Keyword.has_key?(opts, :output) do
      output = Keyword.get(opts, :output)
      unless output in [:basic, :detailed, :verbose] do
        raise ArgumentError, "Invalid output format: #{inspect(output)}. Must be one of: :basic, :detailed, :verbose"
      end
    end
    
    # Convert to Options struct with defaults
    Options.new([
      output_format: Keyword.get(opts, :output, :detailed),
      validate_formats: Keyword.get(opts, :validate_formats, false),
      ignore_unknown_formats: Keyword.get(opts, :ignore_unknown_formats, true),
      stop_on_first_error: Keyword.get(opts, :stop_on_first_error, false),
      collect_annotations: Keyword.get(opts, :collect_annotations, true)
    ])
  end
  
  defp validate_with_options(compiled_schema, instance_json, %Options{output_format: output_format} = options) do
    case output_format do
      :basic -> validate_basic_with_options(compiled_schema, instance_json, options)
      :detailed -> validate_detailed_with_options(compiled_schema, instance_json, options)
      :verbose -> validate_verbose_with_options(compiled_schema, instance_json, options)
      _ -> raise ArgumentError, "Invalid output format: #{inspect(output_format)}. Must be one of: :basic, :detailed, :verbose"
    end
  end
  
  defp valid_with_options(compiled_schema, instance_json, %Options{} = options) do
    # For now, use basic validation with options
    # In the future, this could be optimized to use a dedicated native function
    case validate_with_options(compiled_schema, instance_json, %{options | output_format: :basic}) do
      :ok -> true
      {:error, _} -> false
    end
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
  
  # Validation functions with options support
  # NOTE: For M2.4, these are implemented as placeholders that use the existing
  # native functions. Full options support in the Rust NIF will come in later milestones.
  
  defp validate_basic_with_options(compiled_schema, instance_json, %Options{} = _options) do
    # For now, use basic validation without options
    # TODO: Pass options to native function when Rust NIF is updated
    validate_basic(compiled_schema, instance_json)
  end
  
  defp validate_detailed_with_options(compiled_schema, instance_json, %Options{} = _options) do
    # For now, use detailed validation without options
    # TODO: Pass options to native function when Rust NIF is updated
    validate_detailed(compiled_schema, instance_json)
  end
  
  defp validate_verbose_with_options(compiled_schema, instance_json, %Options{} = options) do
    # For now, use verbose validation without options
    # TODO: Pass options to native function when Rust NIF is updated
    validate_verbose(compiled_schema, instance_json, Map.to_list(options))
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
