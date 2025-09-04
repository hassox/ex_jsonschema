defmodule ExJsonschema do
  @moduledoc """
  High-performance JSON Schema validation for Elixir using Rust.

  Fast, spec-compliant JSON Schema validation powered by the Rust `jsonschema` 
  crate with support for multiple draft versions and comprehensive error reporting.

  ## Quick Start

      # Compile and validate
      schema = ~s({"type": "object", "properties": {"name": {"type": "string"}}})
      {:ok, validator} = ExJsonschema.compile(schema)
      :ok = ExJsonschema.validate(validator, ~s({"name": "John"}))
      
      # Get detailed errors
      {:error, errors} = ExJsonschema.validate(validator, ~s({"name": 123}))
      ExJsonschema.format_errors(errors, :human)

  ## Core Functions

  - `compile/1,2` - Compile JSON Schema for validation
  - `validate/2,3` - Validate JSON against compiled schema  
  - `valid?/2,3` - Quick boolean validation check
  - `meta_validate/1` - Validate schema document itself
  - `format_errors/3` - Format validation errors for display
  - `analyze_errors/1,2` - Analyze error patterns and severity

  ## Output Formats

  - `:basic` - Simple pass/fail (fastest)
  - `:detailed` - Structured errors with paths (default)
  - `:verbose` - Comprehensive errors with context and suggestions

  ## Configuration & Options

      # Use predefined profiles for common scenarios
      strict_opts = ExJsonschema.Options.new(:strict)      # API validation
      lenient_opts = ExJsonschema.Options.new(:lenient)    # User forms  
      perf_opts = ExJsonschema.Options.new(:performance)   # High-volume
      
      # Enable validation options
      ExJsonschema.validate(validator, json, validate_formats: true)
      ExJsonschema.valid?(validator, json, stop_on_first_error: true)

  ## Draft Support & Meta-Validation

  Supports JSON Schema drafts 4, 6, 7, 2019-09, and 2020-12:

      ExJsonschema.compile_draft7(schema)        # Draft-specific compilation
      ExJsonschema.compile_auto_draft(schema)    # Auto-detect from $schema
      
      # Validate schema documents against meta-schemas
      ExJsonschema.meta_valid?(schema)           # Quick check  
      ExJsonschema.meta_validate(schema)         # Detailed errors

  ## Error Handling & Analysis

  Rich error formatting and intelligent analysis:

      {:error, errors} = ExJsonschema.validate(validator, invalid_data)
      
      # Format for display
      ExJsonschema.format_errors(errors, :human, color: true)
      ExJsonschema.format_errors(errors, :json, pretty: true)
      ExJsonschema.format_errors(errors, :table, compact: true)
      
      # Analyze patterns and get recommendations
      analysis = ExJsonschema.analyze_errors(errors)
      analysis.total_errors        # => 5
      analysis.categories          # => %{type_mismatch: 2, constraint_violation: 3}  
      analysis.recommendations     # => ["Review required fields...", ...]

  ## Comprehensive Documentation

  For detailed guides, examples, and advanced usage:
  - [HexDocs](https://hexdocs.pm/ex_jsonschema) - Complete API reference
  - [GitHub](https://github.com/hassox/ex_jsonschema) - Source code and examples
  - `docs/guides/` - In-depth usage guides and integration patterns

  Built on the blazing-fast Rust `jsonschema` crate for optimal performance.
  """

  require Logger

  alias ExJsonschema.{
    CompilationError,
    DraftDetector,
    ErrorAnalyzer,
    ErrorFormatter,
    MetaValidator,
    Native,
    Options,
    ValidationError
  }

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
  @spec compile(json_string(), Options.t() | keyword()) ::
          {:ok, compiled_schema()} | {:error, CompilationError.t()}
  def compile(schema_json, %Options{} = options) when is_binary(schema_json) do
    Logger.debug("Starting schema compilation", %{
      schema_size: byte_size(schema_json),
      draft: options.draft,
      output_format: options.output_format
    })

    result = compile_with_options(schema_json, options)

    case result do
      {:ok, _compiled} ->
        Logger.info("Schema compilation successful", %{
          schema_size: byte_size(schema_json),
          draft: options.draft
        })

      {:error, error} ->
        Logger.error("Schema compilation failed", %{
          schema_size: byte_size(schema_json),
          draft: options.draft,
          error: inspect(error)
        })
    end

    result
  end

  def compile(schema_json, options) when is_binary(schema_json) and is_list(options) do
    Logger.debug("Converting keyword options to Options struct", %{
      options: options,
      schema_size: byte_size(schema_json)
    })

    case Options.validate(Options.new(options)) do
      {:ok, validated_options} ->
        Logger.debug("Options validation successful")
        compile_with_options(schema_json, validated_options)

      {:error, reason} ->
        Logger.warning("Options validation failed", %{
          reason: reason,
          options: options
        })

        {:error, CompilationError.from_options_error(reason)}
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
  @spec validate(compiled_schema(), json_string(), keyword() | Options.t()) ::
          validation_result() | basic_validation_result()

  # Accept Options struct
  def validate(compiled_schema, instance_json, %Options{} = options)
      when is_reference(compiled_schema) and is_binary(instance_json) do
    Logger.debug("Starting validation", %{
      instance_size: byte_size(instance_json),
      output_format: options.output_format,
      validate_formats: options.validate_formats
    })

    result = validate_with_options(compiled_schema, instance_json, options)

    case result do
      :ok ->
        Logger.debug("Validation successful", %{
          instance_size: byte_size(instance_json),
          output_format: options.output_format
        })

      {:error, :validation_failed} ->
        Logger.debug("Basic validation failed", %{
          instance_size: byte_size(instance_json)
        })

      {:error, errors} when is_list(errors) ->
        Logger.debug("Validation failed with errors", %{
          instance_size: byte_size(instance_json),
          error_count: length(errors),
          output_format: options.output_format
        })

      {:error, error} ->
        Logger.warning("Validation failed with unexpected error", %{
          instance_size: byte_size(instance_json),
          error: inspect(error)
        })
    end

    result
  end

  # Accept keyword list
  def validate(compiled_schema, instance_json, opts)
      when is_reference(compiled_schema) and is_binary(instance_json) and is_list(opts) do
    Logger.debug("Converting validation options", %{
      instance_size: byte_size(instance_json),
      options: opts
    })

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
  Compiles a JSON Schema using Draft 4 specific optimizations.

  This provides a direct shortcut to compile schemas specifically for Draft 4,
  which can be faster than using the generic `compile/2` with draft options.

  ## Examples

      iex> schema = ~s({"type": "string"})
      iex> {:ok, compiled} = ExJsonschema.compile_draft4(schema)
      iex> is_reference(compiled)
      true

      # With additional options
      iex> {:ok, compiled} = ExJsonschema.compile_draft4(schema, validate_formats: true)
      iex> is_reference(compiled)
      true

  """
  @spec compile_draft4(json_string(), keyword()) ::
          {:ok, compiled_schema()} | {:error, CompilationError.t()}
  def compile_draft4(schema_json, options \\ []) when is_binary(schema_json) do
    options_with_draft = Keyword.put(options, :draft, :draft4)
    compile(schema_json, options_with_draft)
  end

  @doc """
  Compiles a JSON Schema using Draft 6 specific optimizations.

  ## Examples

      iex> schema = ~s({"type": "string"})
      iex> {:ok, compiled} = ExJsonschema.compile_draft6(schema)
      iex> is_reference(compiled)
      true

  """
  @spec compile_draft6(json_string(), keyword()) ::
          {:ok, compiled_schema()} | {:error, CompilationError.t()}
  def compile_draft6(schema_json, options \\ []) when is_binary(schema_json) do
    options_with_draft = Keyword.put(options, :draft, :draft6)
    compile(schema_json, options_with_draft)
  end

  @doc """
  Compiles a JSON Schema using Draft 7 specific optimizations.

  Draft 7 is widely used and includes support for conditional schemas with `if`, `then`, `else`.

  ## Examples

      iex> schema = ~s({"type": "string"})
      iex> {:ok, compiled} = ExJsonschema.compile_draft7(schema)
      iex> is_reference(compiled)
      true

  """
  @spec compile_draft7(json_string(), keyword()) ::
          {:ok, compiled_schema()} | {:error, CompilationError.t()}
  def compile_draft7(schema_json, options \\ []) when is_binary(schema_json) do
    options_with_draft = Keyword.put(options, :draft, :draft7)
    compile(schema_json, options_with_draft)
  end

  @doc """
  Compiles a JSON Schema using Draft 2019-09 specific optimizations.

  ## Examples

      iex> schema = ~s({"type": "string"})
      iex> {:ok, compiled} = ExJsonschema.compile_draft201909(schema)
      iex> is_reference(compiled)
      true

  """
  @spec compile_draft201909(json_string(), keyword()) ::
          {:ok, compiled_schema()} | {:error, CompilationError.t()}
  def compile_draft201909(schema_json, options \\ []) when is_binary(schema_json) do
    options_with_draft = Keyword.put(options, :draft, :draft201909)
    compile(schema_json, options_with_draft)
  end

  @doc """
  Compiles a JSON Schema using Draft 2020-12 specific optimizations.

  Draft 2020-12 is the latest specification with the most comprehensive feature set.

  ## Examples

      iex> schema = ~s({"type": "string"})
      iex> {:ok, compiled} = ExJsonschema.compile_draft202012(schema)
      iex> is_reference(compiled)
      true

  """
  @spec compile_draft202012(json_string(), keyword()) ::
          {:ok, compiled_schema()} | {:error, CompilationError.t()}
  def compile_draft202012(schema_json, options \\ []) when is_binary(schema_json) do
    options_with_draft = Keyword.put(options, :draft, :draft202012)
    compile(schema_json, options_with_draft)
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

  @doc """
  Compiles a schema using the automatically detected draft version.

  This is a convenience function that combines `detect_draft/1` and `compile/2` 
  to automatically select the most appropriate draft for the schema.

  ## Examples

      # Schema with explicit $schema
      iex> schema = ~s({"$schema": "http://json-schema.org/draft-07/schema#", "type": "string"})
      iex> {:ok, compiled} = ExJsonschema.compile_auto_draft(schema)
      iex> is_reference(compiled)
      true

      # Schema without $schema (defaults to latest)
      iex> schema = ~s({"type": "number"})
      iex> {:ok, compiled} = ExJsonschema.compile_auto_draft(schema)
      iex> is_reference(compiled)
      true

  """
  @spec compile_auto_draft(json_string(), keyword()) ::
          {:ok, compiled_schema()} | {:error, CompilationError.t()}
  def compile_auto_draft(schema_json, options \\ []) when is_binary(schema_json) do
    options_with_auto = Keyword.put(options, :draft, :auto)
    compile(schema_json, options_with_auto)
  end

  @doc """
  Formats validation errors for display using the specified format.

  This is a convenience function that delegates to `ExJsonschema.ErrorFormatter.format/3`.

  ## Supported Formats

  - `:human` - Human-readable text format with colors and suggestions
  - `:json` - Structured JSON format for programmatic use
  - `:table` - Tabular format for easy scanning of multiple errors
  - `:markdown` - Markdown format for documentation and web display
  - `:llm` - LLM-optimized format for AI assistant consumption

  ## Examples

      # Format errors for human consumption
      ExJsonschema.format_errors(errors, :human)
      
      # Format as pretty-printed JSON
      ExJsonschema.format_errors(errors, :json, pretty: true)
      
      # Format as compact table
      ExJsonschema.format_errors(errors, :table, compact: true)
      
  """
  @spec format_errors(
          [ValidationError.t()],
          ErrorFormatter.format(),
          ErrorFormatter.format_options()
        ) :: String.t()
  def format_errors(errors, format, options \\ []) do
    Logger.debug("Formatting validation errors", %{
      error_count: length(errors),
      format: format,
      options: options
    })

    result = ErrorFormatter.format(errors, format, options)

    Logger.info("Error formatting complete", %{
      error_count: length(errors),
      format: format,
      output_size: byte_size(result)
    })

    result
  end

  @doc """
  Analyzes validation errors to provide insights, categorization, and recommendations.

  Returns a comprehensive analysis including error categories, severity levels,
  detected patterns, and actionable recommendations for fixing the issues.

  ## Examples

      {:error, errors} = ExJsonschema.validate(validator, invalid_json)
      analysis = ExJsonschema.analyze_errors(errors)
      
      analysis.total_errors
      #=> 3
      
      analysis.categories
      #=> %{type_mismatch: 1, constraint_violation: 2}
      
      analysis.recommendations
      #=> ["Review required fields - ensure all mandatory properties are included", ...]
      
      # Get human-readable summary
      ExJsonschema.analyze_errors(errors, :summary)
      #=> "3 validation errors detected\\n\\nCategories: 1 type mismatches, 2 constraint violations..."

  """
  @spec analyze_errors([ValidationError.t()]) :: ErrorAnalyzer.error_analysis()
  @spec analyze_errors([ValidationError.t()], :summary) :: String.t()
  def analyze_errors(errors, format \\ :analysis)

  def analyze_errors(errors, :analysis) when is_list(errors) do
    ErrorAnalyzer.analyze(errors)
  end

  def analyze_errors(errors, :summary) when is_list(errors) do
    ErrorAnalyzer.summarize(errors)
  end

  # Meta-validation functions

  @doc """
  Checks if a JSON Schema document is valid against its meta-schema.

  This function validates that the provided schema document itself follows
  the correct JSON Schema specification for its draft version.

  ## Examples

      iex> schema = ~s({"type": "string", "minLength": 5})
      iex> ExJsonschema.meta_valid?(schema)
      true
      
      iex> invalid_schema = ~s({"type": "invalid_type"})
      iex> ExJsonschema.meta_valid?(invalid_schema)
      false

  ## Parameters

  - `schema_json` - JSON string containing the schema to validate

  ## Returns

  - `true` if the schema is valid against its meta-schema
  - `false` if the schema is invalid
  - Raises `ArgumentError` if JSON is malformed
  """
  @spec meta_valid?(binary()) :: boolean()
  defdelegate meta_valid?(schema_json), to: MetaValidator, as: :valid?

  @doc """
  Validates a JSON Schema document against its meta-schema.

  Returns detailed validation errors compatible with standard validation error
  formatting and analysis tools.

  ## Examples

      iex> schema = ~s({"type": "string", "minLength": 5})
      iex> ExJsonschema.meta_validate(schema)
      :ok
      
      iex> invalid_schema = ~s({"type": "invalid_type"})
      iex> {:error, errors} = ExJsonschema.meta_validate(invalid_schema)
      iex> ExJsonschema.format_errors(errors, :human)

  ## Parameters

  - `schema_json` - JSON string containing the schema to validate

  ## Returns

  - `:ok` if the schema is valid
  - `{:error, [ExJsonschema.ValidationError.t()]}` if validation fails
  - `{:error, reason}` if JSON parsing fails
  """
  @spec meta_validate(binary()) :: :ok | {:error, [ValidationError.t()]} | {:error, binary()}
  defdelegate meta_validate(schema_json), to: MetaValidator, as: :validate

  @doc """
  Validates a JSON Schema document against its meta-schema, raising on error.

  Like `meta_validate/1` but raises `ExJsonschema.ValidationError` if validation fails.

  ## Examples

      iex> schema = ~s({"type": "string", "minLength": 5})
      iex> ExJsonschema.meta_validate!(schema)
      :ok

  ## Parameters

  - `schema_json` - JSON string containing the schema to validate

  ## Returns

  - `:ok` if the schema is valid
  - Raises `ExJsonschema.ValidationError` if validation fails
  - Raises `ArgumentError` if JSON is malformed
  """
  @spec meta_validate!(binary()) :: :ok
  defdelegate meta_validate!(schema_json), to: MetaValidator, as: :validate!

  # Private helper functions for validation options

  defp validate_and_normalize_options(opts) do
    # Validate each option
    valid_options = [
      :output,
      :validate_formats,
      :ignore_unknown_formats,
      :stop_on_first_error,
      :collect_annotations
    ]

    # Check for invalid options
    invalid_opts = Keyword.keys(opts) -- valid_options

    unless Enum.empty?(invalid_opts) do
      raise ArgumentError,
            "Invalid validation option(s): #{inspect(invalid_opts)}. " <>
              "Valid options are: #{inspect(valid_options)}"
    end

    # Validate boolean options
    boolean_opts = [
      :validate_formats,
      :ignore_unknown_formats,
      :stop_on_first_error,
      :collect_annotations
    ]

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
        raise ArgumentError,
              "Invalid output format: #{inspect(output)}. Must be one of: :basic, :detailed, :verbose"
      end
    end

    # Convert to Options struct with defaults
    Options.new(
      output_format: Keyword.get(opts, :output, :detailed),
      validate_formats: Keyword.get(opts, :validate_formats, false),
      ignore_unknown_formats: Keyword.get(opts, :ignore_unknown_formats, true),
      stop_on_first_error: Keyword.get(opts, :stop_on_first_error, false),
      collect_annotations: Keyword.get(opts, :collect_annotations, true)
    )
  end

  defp validate_with_options(
         compiled_schema,
         instance_json,
         %Options{output_format: output_format} = options
       ) do
    case output_format do
      :basic ->
        validate_basic_with_options(compiled_schema, instance_json, options)

      :detailed ->
        validate_detailed_with_options(compiled_schema, instance_json, options)

      :verbose ->
        validate_verbose_with_options(compiled_schema, instance_json, options)

      _ ->
        raise ArgumentError,
              "Invalid output format: #{inspect(output_format)}. Must be one of: :basic, :detailed, :verbose"
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
    Logger.debug("Auto-detecting JSON Schema draft")

    # Auto-detect draft from schema and update options
    case DraftDetector.detect_draft(schema_json) do
      {:ok, detected_draft} ->
        Logger.debug("Draft auto-detection successful", %{detected_draft: detected_draft})
        updated_options = %{options | draft: detected_draft}
        compile_with_native_options(schema_json, updated_options)

      {:error, reason} ->
        Logger.warning("Draft auto-detection failed", %{reason: reason})
        {:error, CompilationError.from_detection_error(reason)}
    end
  end

  defp compile_with_options(schema_json, %Options{} = options) do
    compile_with_native_options(schema_json, options)
  end

  defp compile_with_native_options(schema_json, %Options{draft: draft} = options) do
    Logger.debug("Compiling with native options", %{draft: draft})

    # For M3.5: Draft-specific compilation with validation
    case validate_compilation_options(schema_json, options) do
      :ok ->
        Logger.debug("Compilation options validation successful")

        # Use draft-specific compilation when draft is specified (not :auto)
        result =
          case draft do
            :auto ->
              Logger.debug("Using generic compilation (auto draft)")
              # Already resolved by compile_with_options, shouldn't reach here
              Native.compile_schema(schema_json)

            draft when draft in [:draft4, :draft6, :draft7, :draft201909, :draft202012] ->
              Logger.debug("Using draft-specific compilation", %{draft: draft})
              Native.compile_schema_with_draft(schema_json, draft)

            _ ->
              Logger.warning("Unknown draft, falling back to generic compilation", %{draft: draft})

              # Fallback to generic compilation
              Native.compile_schema(schema_json)
          end

        case result do
          {:ok, compiled} ->
            Logger.debug("Native compilation successful")
            {:ok, compiled}

          {:error, error_map} ->
            Logger.error("Native compilation failed", %{error_map: error_map})
            {:error, CompilationError.from_map(error_map)}
        end

      {:error, reason} ->
        Logger.warning("Compilation options validation failed", %{reason: reason})
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
              # No $schema in document, options draft is fine
              :ok
          end
        else
          :ok
        end

      {:error, reason} ->
        {:error, "Draft detection failed: #{reason}"}
    end
  end
end
