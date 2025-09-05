defmodule ExJsonschema.Options do
  @moduledoc """
  Configuration options for JSON Schema compilation and validation.

  This module provides a structured way to configure JSON Schema operations, including:
  - Draft version selection
  - Format validation settings
  - Performance optimizations

  ## Examples

      # Default options with automatic draft detection
      opts = ExJsonschema.Options.new()
      
      # Strict validation with format checking
      opts = ExJsonschema.Options.new(
        draft: :draft202012,
        validate_formats: true
      )
      
      # Performance-optimized options
      opts = ExJsonschema.Options.new(
        regex_engine: :regex
      )
  """

  @typedoc """
  JSON Schema draft version specification.

  - `:auto` - Automatically detect draft from schema's `$schema` property
  - `:draft4` - JSON Schema Draft 4 (2013)
  - `:draft6` - JSON Schema Draft 6 (2017) 
  - `:draft7` - JSON Schema Draft 7 (2019)
  - `:draft201909` - JSON Schema 2019-09
  - `:draft202012` - JSON Schema 2020-12 (latest)

  When `:auto` is used, the library examines the `$schema` property
  to determine the appropriate draft version. Defaults to `:draft202012`
  if no `$schema` is found.
  """
  @type draft :: :auto | :draft4 | :draft6 | :draft7 | :draft201909 | :draft202012

  @typedoc """
  Regular expression engine used for pattern validation.

  - `:fancy_regex` - Full-featured regex engine with advanced features (default)
  - `:regex` - Simpler, faster regex engine for basic patterns

  The `:fancy_regex` engine supports advanced features like lookahead/lookbehind
  while `:regex` provides better performance for simple pattern matching.
  """
  @type regex_engine :: :fancy_regex | :regex

  @typedoc """
  Output format for validation results.

  - `:basic` - `:ok` or `{:error, :validation_failed}` 
  - `:detailed` - Structured error information with paths and messages (default)
  - `:verbose` - Comprehensive error details with context, values, and suggestions

  Use `:basic` for maximum performance when you only need pass/fail results.
  Use `:detailed` for structured error handling. Use `:verbose` for debugging
  and user-friendly error reporting.
  """
  @type output_format :: :basic | :detailed | :verbose

  defstruct [
    # Draft specification
    draft: :auto,

    # Validation behavior
    validate_formats: false,

    # Performance settings
    regex_engine: :fancy_regex,

    # Output control
    output_format: :detailed
  ]

  @type t :: %__MODULE__{
          draft: draft(),
          validate_formats: boolean(),
          regex_engine: regex_engine(),
          output_format: output_format()
        }

  @doc """
  Creates a new Options struct with default values.

  ## Options

    * `:draft` - JSON Schema draft to use (default: `:auto`)
    * `:validate_formats` - Enable format validation (default: `false`)
    * `:regex_engine` - Regex engine to use (default: `:fancy_regex`)
    * `:output_format` - Error output format (default: `:detailed`)

  ## Examples

      iex> opts = ExJsonschema.Options.new()
      iex> opts.draft
      :auto
      
      iex> opts = ExJsonschema.Options.new(draft: :draft202012, validate_formats: true)
      iex> {opts.draft, opts.validate_formats}
      {:draft202012, true}
      
  ## Profile Integration

  You can also create Options from predefined profiles:

      iex> opts = ExJsonschema.Options.new(:strict)
      iex> opts.validate_formats
      true
      
      iex> opts = ExJsonschema.Options.new({:performance, [output_format: :basic]})
      iex> opts.output_format
      :basic
  """
  def new(profile_or_overrides \\ [])

  def new(profile) when profile in [:strict, :lenient, :performance] do
    ExJsonschema.Profile.get(profile)
  end

  def new({profile, overrides})
      when profile in [:strict, :lenient, :performance] and is_list(overrides) do
    ExJsonschema.Profile.get(profile, overrides)
  end

  def new(overrides) when is_list(overrides) do
    struct(%__MODULE__{}, overrides)
  end

  @doc """
  Creates options from a profile with optional overrides.

  This is a convenience function that's equivalent to `ExJsonschema.Profile.get/2`
  but provides a consistent API within the Options module.

  ## Examples

      iex> opts = ExJsonschema.Options.profile(:strict)
      iex> opts.validate_formats
      true
      
      iex> opts = ExJsonschema.Options.profile(:performance, output_format: :basic)
      iex> opts.output_format
      :basic
  """
  def profile(profile_name, overrides \\ []) do
    ExJsonschema.Profile.get(profile_name, overrides)
  end

  @doc """
  Creates options optimized for Draft 4 schemas.
  """
  def draft4(overrides \\ []) do
    overrides
    |> Keyword.put(:draft, :draft4)
    |> new()
  end

  @doc """
  Creates options optimized for Draft 6 schemas.
  """
  def draft6(overrides \\ []) do
    overrides
    |> Keyword.put(:draft, :draft6)
    |> new()
  end

  @doc """
  Creates options optimized for Draft 7 schemas.
  """
  def draft7(overrides \\ []) do
    overrides
    |> Keyword.put(:draft, :draft7)
    |> new()
  end

  @doc """
  Creates options optimized for Draft 2019-09 schemas.
  """
  def draft201909(overrides \\ []) do
    overrides
    |> Keyword.put(:draft, :draft201909)
    |> new()
  end

  @doc """
  Creates options optimized for Draft 2020-12 schemas.
  """
  def draft202012(overrides \\ []) do
    overrides
    |> Keyword.put(:draft, :draft202012)
    |> new()
  end

  @doc """
  Validates the options struct and returns {:ok, options} or {:error, reason}.

  ## Examples

      iex> opts = ExJsonschema.Options.new(draft: :draft202012)
      iex> ExJsonschema.Options.validate(opts)
      {:ok, opts}
      
      iex> opts = %ExJsonschema.Options{draft: :invalid}
      iex> ExJsonschema.Options.validate(opts)
      {:error, "Invalid draft version: :invalid"}
  """
  def validate(%__MODULE__{} = options) do
    with :ok <- validate_draft(options.draft),
         :ok <- validate_regex_engine(options.regex_engine),
         :ok <- validate_output_format(options.output_format) do
      {:ok, options}
    end
  end

  defp validate_draft(draft)
       when draft in [:auto, :draft4, :draft6, :draft7, :draft201909, :draft202012],
       do: :ok

  defp validate_draft(draft), do: {:error, "Invalid draft version: #{inspect(draft)}"}

  defp validate_regex_engine(engine) when engine in [:fancy_regex, :regex], do: :ok
  defp validate_regex_engine(engine), do: {:error, "Invalid regex engine: #{inspect(engine)}"}

  defp validate_output_format(format) when format in [:basic, :detailed, :verbose], do: :ok
  defp validate_output_format(format), do: {:error, "Invalid output format: #{inspect(format)}"}
end
