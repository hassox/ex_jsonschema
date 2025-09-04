defmodule ExJsonschema.ErrorFormatter do
  @moduledoc """
  Provides utilities for formatting JSON Schema validation errors in multiple output formats.
  
  Supports five output formats:
  - `:human` - Human-readable text format with colors and suggestions
  - `:json` - Structured JSON format for programmatic use
  - `:table` - Tabular format for easy scanning of multiple errors
  - `:markdown` - Markdown format for documentation and reports
  - `:llm` - LLM-optimized format for AI assistant consumption
  
  ## Examples
  
      # Format errors for human consumption
      ErrorFormatter.format(errors, :human)
      
      # Format as JSON with pretty printing
      ErrorFormatter.format(errors, :json, pretty: true)
      
      # Format as compact table
      ErrorFormatter.format(errors, :table, compact: true)
      
      # Format as markdown for documentation
      ErrorFormatter.format(errors, :markdown)
      
      # Format for LLM consumption
      ErrorFormatter.format(errors, :llm)
      
  ## Formatting Options
  
  Each format supports specific options:
  
  ### Human Format Options
  - `color: boolean()` - Enable/disable ANSI color codes (default: true)
  - `max_errors: pos_integer()` - Maximum errors to display (default: 20)
  
  ### JSON Format Options  
  - `pretty: boolean()` - Pretty print JSON with indentation (default: false)
  
  ### Table Format Options
  - `compact: boolean()` - Use compact table layout (default: false)
  - `max_errors: pos_integer()` - Maximum errors to display (default: 50)
  
  ### Markdown Format Options
  - `heading_level: 1..6` - Base heading level for sections (default: 2)
  - `include_toc: boolean()` - Include table of contents (default: false)
  - `max_errors: pos_integer()` - Maximum errors to display (default: 100)
  
  ### LLM Format Options
  - `include_schema_context: boolean()` - Include schema path context (default: true)
  - `structured: boolean()` - Use structured format vs prose (default: false)
  - `max_errors: pos_integer()` - Maximum errors to display (default: 20)
  """

  alias ExJsonschema.ValidationError

  # Available output formats
  @available_formats [:human, :json, :table, :markdown, :llm]

  @typedoc """
  Human-readable text format with ANSI colors, context, and suggestions.
  
  Ideal for console applications, terminal output, and developer feedback.
  Supports color customization and error count limits.
  """
  @type human_format :: :human

  @typedoc """
  Structured JSON format for programmatic use and API responses.
  
  Perfect for APIs, structured logging, and machine processing.
  Supports pretty-printing and clean null field handling.
  """
  @type json_format :: :json

  @typedoc """
  ASCII table format for comparing multiple errors side-by-side.
  
  Excellent for reports, debugging sessions, and scanning large error lists.
  Supports compact layout and automatic column sizing.
  """
  @type table_format :: :table

  @typedoc """
  Markdown format for documentation, reports, and rich text output.
  
  Great for README files, documentation generation, and web display.
  Supports heading levels, table of contents, and proper escaping.
  """
  @type markdown_format :: :markdown

  @typedoc """
  LLM-optimized format designed for AI assistant consumption.
  
  Optimized for large language models with structured or prose output.
  Includes clear context separation and actionable information.
  """
  @type llm_format :: :llm

  @typedoc """
  All supported output formats for error formatting.
  """
  @type format :: human_format() | json_format() | table_format() | markdown_format() | llm_format()
  @type format_option :: 
    {:color, boolean()} | 
    {:pretty, boolean()} | 
    {:compact, boolean()} | 
    {:max_errors, pos_integer()} |
    {:heading_level, 1..6} |
    {:include_toc, boolean()} |
    {:include_schema_context, boolean()} |
    {:structured, boolean()}
  @type format_options :: [format_option()]

  @doc """
  Returns all available output formats.
  
  ## Examples
  
      iex> formats = ExJsonschema.ErrorFormatter.available_formats()
      iex> :human in formats
      true
      iex> :markdown in formats
      true
      
  """
  @spec available_formats() :: [format()]
  def available_formats, do: @available_formats

  @doc """
  Formats validation errors in the specified format.
  
  ## Arguments
  - `errors` - List of ValidationError structs
  - `format` - Output format (see `available_formats/0` for supported formats)
  - `options` - Format-specific options (optional)
  
  ## Examples
  
      iex> errors = [%ExJsonschema.ValidationError{
      ...>   instance_path: "/name",
      ...>   message: "is not of type string"
      ...> }]
      iex> result = ExJsonschema.ErrorFormatter.format(errors, :human)
      iex> is_binary(result)
      true
      
  """
  @spec format([ValidationError.t()], format(), format_options()) :: String.t()
  def format(errors, format, options \\ [])

  def format(errors, format, options) when is_list(errors) and format in @available_formats do
    validated_options = validate_options(options, format)
    
    case errors do
      [] -> format_empty(format)
      _ -> do_format(errors, format, validated_options)
    end
  end

  def format(errors, _format, _options) when not is_list(errors) do
    raise ArgumentError, "errors must be a list, got: #{inspect(errors)}"
  end

  def format(_errors, format, _options) do
    format_list = @available_formats |> Enum.map(&inspect/1) |> Enum.join(", ")
    raise ArgumentError, "Invalid format: #{inspect(format)}. Must be one of: #{format_list}"
  end

  # Private implementation functions

  defp format_empty(:human), do: "No validation errors found."
  defp format_empty(:json), do: "[]"
  defp format_empty(:table), do: "No validation errors found."
  defp format_empty(:markdown), do: "## Validation Results\n\nNo validation errors found."
  defp format_empty(:llm), do: "VALIDATION_STATUS: SUCCESS\nNo validation errors detected in the JSON document."

  defp do_format(errors, :human, options) do
    format_human(errors, options)
  end

  defp do_format(errors, :json, options) do
    format_json(errors, options)
  end

  defp do_format(errors, :table, options) do
    format_table(errors, options)
  end

  defp do_format(errors, :markdown, options) do
    format_markdown(errors, options)
  end

  defp do_format(errors, :llm, options) do
    format_llm(errors, options)
  end

  # Human format implementation
  defp format_human(errors, options) do
    max_errors = Keyword.get(options, :max_errors, 20)
    color = Keyword.get(options, :color, true)
    
    {display_errors, truncated_count} = limit_errors(errors, max_errors)
    
    formatted_errors = 
      case length(display_errors) do
        1 -> format_single_human_error(hd(display_errors), color)
        _ -> format_multiple_human_errors(display_errors, color)
      end
    
    if truncated_count > 0 do
      formatted_errors <> "\n\n" <> format_truncation_notice(truncated_count, color)
    else
      formatted_errors
    end
  end

  defp format_single_human_error(error, color) do
    title = colorize("Validation Error", :red, :bold, color)
    
    [
      title,
      "",
      format_error_location(error, color),
      format_error_message(error, color),
      format_error_context(error, color),
      format_error_suggestions(error, color)
    ]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n")
  end

  defp format_multiple_human_errors(errors, color) do
    count = length(errors)
    title = colorize("#{count} Validation Errors Found", :red, :bold, color)
    
    formatted_list = 
      errors
      |> Enum.with_index(1)
      |> Enum.map(fn {error, index} ->
        error_title = colorize("Error #{index}:", :yellow, :bold, color)
        location = format_error_location(error, color)
        message = format_error_message(error, color)
        
        "#{error_title}\n#{location}\n#{message}"
      end)
      |> Enum.join("\n\n")
    
    title <> "\n\n" <> formatted_list
  end

  defp format_error_location(error, color) do
    path = colorize(error.instance_path, :cyan, :normal, color)
    "Location: #{path}"
  end

  defp format_error_message(error, color) do
    message = colorize(error.message, :white, :normal, color)
    keyword_info = if error.keyword do
      " (" <> colorize(error.keyword, :magenta, :normal, color) <> ")"
    else
      ""
    end
    "Message:  #{message}#{keyword_info}"
  end

  defp format_error_context(%{context: context}, color) when is_map(context) and map_size(context) > 0 do
    context_title = colorize("Context:", :blue, :bold, color)
    
    formatted_context = 
      context
      |> Enum.map(fn {key, value} ->
        key_colored = colorize("  #{key}:", :blue, :normal, color)
        "#{key_colored} #{inspect(value, limit: :infinity, pretty: true)}"
      end)
      |> Enum.join("\n")
    
    context_title <> "\n" <> formatted_context
  end

  defp format_error_context(_error, _color), do: ""

  defp format_error_suggestions(%{suggestions: suggestions}, color) when is_list(suggestions) and length(suggestions) > 0 do
    title = colorize("Suggestions:", :green, :bold, color)
    
    formatted_suggestions = 
      suggestions
      |> Enum.map(fn suggestion ->
        bullet = colorize("  •", :green, :normal, color)
        "#{bullet} #{suggestion}"
      end)
      |> Enum.join("\n")
    
    title <> "\n" <> formatted_suggestions
  end

  defp format_error_suggestions(_error, _color), do: ""

  defp format_truncation_notice(count, color) do
    notice = "... and #{count} more errors"
    colorize(notice, :yellow, :italic, color)
  end

  # JSON format implementation
  defp format_json(errors, options) do
    pretty = Keyword.get(options, :pretty, false)
    
    error_maps = Enum.map(errors, &validation_error_to_map/1)
    
    jason_options = if pretty, do: [pretty: true], else: []
    Jason.encode!(error_maps, jason_options)
  end

  defp validation_error_to_map(error) do
    %{}
    |> put_if_present("instance_path", error.instance_path)
    |> put_if_present("schema_path", error.schema_path) 
    |> put_if_present("message", error.message)
    |> put_if_present("keyword", error.keyword)
    |> put_if_present("instance_value", error.instance_value)
    |> put_if_present("schema_value", error.schema_value)
    |> put_if_present("context", error.context)
    |> put_if_present("annotations", error.annotations)
    |> put_if_present("suggestions", error.suggestions)
  end

  defp put_if_present(map, _key, nil), do: map
  defp put_if_present(map, _key, []), do: map
  defp put_if_present(map, _key, empty_map) when map_size(empty_map) == 0, do: map
  defp put_if_present(map, key, value), do: Map.put(map, key, value)

  # Table format implementation
  defp format_table(errors, options) do
    max_errors = Keyword.get(options, :max_errors, 50)
    compact = Keyword.get(options, :compact, false)
    
    {display_errors, truncated_count} = limit_errors(errors, max_errors)
    
    if length(display_errors) == 0 do
      "No validation errors found."
    else
      table_content = build_table(display_errors, compact)
      
      if truncated_count > 0 do
        total_count = length(errors)
        table_content <> "\n\nShowing #{length(display_errors)} of #{total_count} errors (#{total_count} errors total)"
      else
        table_content
      end
    end
  end

  defp build_table(errors, compact) do
    headers = ["Path", "Error", "Keyword"]
    
    rows = Enum.map(errors, fn error ->
      message_width = if compact, do: 50, else: 80
      [
        truncate_string(error.instance_path || "", 40),
        truncate_string(error.message || "", message_width),
        error.keyword || "-"
      ]
    end)
    
    create_ascii_table(headers, rows, compact)
  end

  defp create_ascii_table(headers, rows, compact) do
    all_rows = [headers | rows]
    col_widths = calculate_column_widths(all_rows)
    
    separator = create_separator(col_widths)
    header_row = create_table_row(headers, col_widths)
    data_rows = Enum.map(rows, &create_table_row(&1, col_widths))
    
    if compact do
      [header_row, separator | data_rows] |> Enum.join("\n")
    else
      [separator, header_row, separator | data_rows] ++ [separator]
      |> Enum.join("\n")
    end
  end

  defp calculate_column_widths(rows) do
    rows
    |> Enum.zip()
    |> Enum.map(fn col_tuple ->
      col_tuple
      |> Tuple.to_list()
      |> Enum.map(&String.length/1)
      |> Enum.max()
      |> min(80) # Maximum column width
      |> max(8)  # Minimum column width
    end)
  end

  defp create_separator(col_widths) do
    "+" <> 
    (col_widths
     |> Enum.map(&String.duplicate("-", &1 + 2))
     |> Enum.join("+")) <> 
    "+"
  end

  defp create_table_row(row, col_widths) do
    "|" <>
    (row
     |> Enum.zip(col_widths)
     |> Enum.map(fn {cell, width} ->
       " " <> String.pad_trailing(cell, width) <> " "
     end)
     |> Enum.join("|")) <>
    "|"
  end

  defp truncate_string(str, max_length) when byte_size(str) <= max_length, do: str
  defp truncate_string(str, max_length) do
    String.slice(str, 0, max_length - 3) <> "..."
  end

  # Markdown format implementation
  defp format_markdown(errors, options) do
    max_errors = Keyword.get(options, :max_errors, 100)
    heading_level = Keyword.get(options, :heading_level, 2)
    include_toc = Keyword.get(options, :include_toc, false)
    
    {display_errors, truncated_count} = limit_errors(errors, max_errors)
    
    heading_prefix = String.duplicate("#", heading_level)
    
    sections = [
      "#{heading_prefix} Validation Errors",
      "",
      build_markdown_summary(display_errors, truncated_count),
      ""
    ]
    
    sections = if include_toc do
      sections ++ build_markdown_toc(display_errors, heading_level) ++ [""]
    else
      sections
    end
    
    sections = sections ++ build_markdown_error_list(display_errors, heading_level)
    
    sections
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n")
  end

  defp build_markdown_summary(errors, truncated_count) do
    total_count = length(errors) + truncated_count
    error_word = if total_count == 1, do: "error", else: "errors"
    
    base_summary = "Found **#{total_count}** validation #{error_word}"
    
    if truncated_count > 0 do
      "#{base_summary} (showing first #{length(errors)})"
    else
      base_summary <> "."
    end
  end

  defp build_markdown_toc(errors, base_level) do
    toc_level = base_level + 1
    toc_prefix = String.duplicate("#", toc_level)
    
    toc_items = 
      errors
      |> Enum.with_index(1)
      |> Enum.map(fn {error, index} ->
        path = error.instance_path || "root"
        keyword = error.keyword || "validation"
        "- [Error #{index}: #{path} (#{keyword})](#error-#{index})"
      end)
    
    ["#{toc_prefix} Table of Contents", ""] ++ toc_items
  end

  defp build_markdown_error_list(errors, base_level) do
    error_level = base_level + 1
    
    errors
    |> Enum.with_index(1)
    |> Enum.flat_map(fn {error, index} ->
      build_markdown_error_section(error, index, error_level)
    end)
  end

  defp build_markdown_error_section(error, index, heading_level) do
    heading_prefix = String.duplicate("#", heading_level)
    
    # Create anchor-friendly ID
    anchor_id = "error-#{index}"
    
    sections = [
      "",
      "#{heading_prefix} Error #{index} {##{anchor_id}}",
      "",
      "**Location:** `#{error.instance_path || "/"}`",
      ""
    ]
    
    # Add message with proper escaping
    message_section = [
      "**Message:** #{escape_markdown(error.message)}",
      ""
    ]
    
    sections = sections ++ message_section
    
    # Add keyword if present
    sections = if error.keyword do
      sections ++ ["**Validation Rule:** `#{error.keyword}`", ""]
    else
      sections
    end
    
    # Add context if present
    sections = if error.context && map_size(error.context) > 0 do
      context_lines = [
        "**Context:**",
        "",
        "```json",
        Jason.encode!(error.context, pretty: true),
        "```",
        ""
      ]
      sections ++ context_lines
    else
      sections
    end
    
    # Add suggestions if present
    sections = if error.suggestions && length(error.suggestions) > 0 do
      suggestion_lines = ["**Suggestions:**", ""]
      formatted_suggestions = Enum.map(error.suggestions, &"- #{escape_markdown(&1)}")
      sections ++ suggestion_lines ++ formatted_suggestions ++ [""]
    else
      sections
    end
    
    sections
  end

  defp escape_markdown(text) when is_binary(text) do
    text
    |> String.replace("*", "\\*")
    |> String.replace("_", "\\_")
    |> String.replace("`", "\\`")
    |> String.replace("[", "\\[")
    |> String.replace("]", "\\]")
  end
  defp escape_markdown(value), do: inspect(value)

  # LLM format implementation  
  defp format_llm(errors, options) do
    max_errors = Keyword.get(options, :max_errors, 20)
    include_schema_context = Keyword.get(options, :include_schema_context, true)
    structured = Keyword.get(options, :structured, false)
    
    {display_errors, truncated_count} = limit_errors(errors, max_errors)
    
    if structured do
      format_llm_structured(display_errors, truncated_count, include_schema_context)
    else
      format_llm_prose(display_errors, truncated_count, include_schema_context)
    end
  end

  defp format_llm_structured(errors, truncated_count, include_schema_context) do
    header = [
      "VALIDATION_STATUS: FAILED",
      "ERROR_COUNT: #{length(errors) + truncated_count}",
      "ERRORS_SHOWN: #{length(errors)}",
      ""
    ]
    
    error_sections = 
      errors
      |> Enum.with_index(1)
      |> Enum.flat_map(fn {error, index} ->
        build_llm_structured_error(error, index, include_schema_context)
      end)
    
    footer = if truncated_count > 0 do
      ["", "TRUNCATED: #{truncated_count} additional errors not shown"]
    else
      []
    end
    
    (header ++ error_sections ++ footer)
    |> Enum.join("\n")
  end

  defp format_llm_prose(errors, truncated_count, include_schema_context) do
    total_count = length(errors) + truncated_count
    error_word = if total_count == 1, do: "error", else: "errors"
    
    intro = [
      "The JSON document failed validation with #{total_count} #{error_word}:",
      ""
    ]
    
    error_descriptions = 
      errors
      |> Enum.with_index(1)
      |> Enum.map(fn {error, index} ->
        build_llm_prose_error(error, index, include_schema_context)
      end)
    
    conclusion = if truncated_count > 0 do
      ["", "Note: #{truncated_count} additional errors were truncated from this report."]
    else
      []
    end
    
    (intro ++ error_descriptions ++ conclusion)
    |> Enum.join("\n")
  end

  defp build_llm_structured_error(error, index, include_schema_context) do
    base_fields = [
      "ERROR_#{index}:",
      "  LOCATION: #{error.instance_path || "/"}",
      "  MESSAGE: #{error.message}",
      "  KEYWORD: #{error.keyword || "unknown"}"
    ]
    
    schema_fields = if include_schema_context and error.schema_path do
      ["  SCHEMA_PATH: #{error.schema_path}"]
    else
      []
    end
    
    value_fields = [
      if error.instance_value != nil do
        "  INVALID_VALUE: #{inspect(error.instance_value, limit: :infinity)}"
      end,
      if error.schema_value != nil do
        "  EXPECTED_VALUE: #{inspect(error.schema_value, limit: :infinity)}"
      end
    ]
    |> Enum.reject(&is_nil/1)
    
    suggestion_fields = if error.suggestions && length(error.suggestions) > 0 do
      ["  SUGGESTIONS:"] ++ Enum.map(error.suggestions, &"    - #{&1}")
    else
      []
    end
    
    (base_fields ++ schema_fields ++ value_fields ++ suggestion_fields ++ [""])
  end

  defp build_llm_prose_error(error, index, include_schema_context) do
    location = error.instance_path || "root"
    
    base_description = "#{index}. At location `#{location}`: #{error.message}"
    
    context_info = if include_schema_context and error.schema_path do
      " (Schema path: `#{error.schema_path}`)"
    else
      ""
    end
    
    suggestions_info = if error.suggestions && length(error.suggestions) > 0 do
      suggestions_text = error.suggestions |> Enum.join("; ")
      " Suggestions: #{suggestions_text}."
    else
      ""
    end
    
    base_description <> context_info <> suggestions_info
  end

  # Utility functions
  defp limit_errors(errors, max_errors) do
    if length(errors) <= max_errors do
      {errors, 0}
    else
      {Enum.take(errors, max_errors), length(errors) - max_errors}
    end
  end

  defp validate_options(options, format) do
    Enum.each(options, fn {key, value} ->
      case {key, format, value} do
        {:color, :human, val} when not is_boolean(val) ->
          raise ArgumentError, "color option must be boolean, got: #{inspect(val)}"
        
        {:pretty, :json, val} when not is_boolean(val) ->
          raise ArgumentError, "pretty option must be boolean, got: #{inspect(val)}"
        
        {:compact, :table, val} when not is_boolean(val) ->
          raise ArgumentError, "compact option must be boolean, got: #{inspect(val)}"
          
        {:heading_level, :markdown, val} when not is_integer(val) or val < 1 or val > 6 ->
          raise ArgumentError, "heading_level must be an integer between 1 and 6, got: #{inspect(val)}"
          
        {:include_toc, :markdown, val} when not is_boolean(val) ->
          raise ArgumentError, "include_toc option must be boolean, got: #{inspect(val)}"
          
        {:include_schema_context, :llm, val} when not is_boolean(val) ->
          raise ArgumentError, "include_schema_context option must be boolean, got: #{inspect(val)}"
          
        {:structured, :llm, val} when not is_boolean(val) ->
          raise ArgumentError, "structured option must be boolean, got: #{inspect(val)}"
        
        {:max_errors, _, val} when not is_integer(val) or val < 1 ->
          raise ArgumentError, "max_errors must be a positive integer, got: #{inspect(val)}"
        
        {_unknown_key, _format, _value} ->
          # Ignore unknown options silently
          :ok
      end
    end)
    
    options
  end

  # ANSI color support
  defp colorize(text, _color, _style, false), do: text
  defp colorize(text, color, style, true) do
    color_code = color_to_ansi(color)
    style_code = style_to_ansi(style) 
    "\e[#{style_code};#{color_code}m#{text}\e[0m"
  end

  defp color_to_ansi(:black), do: "30"
  defp color_to_ansi(:red), do: "31"
  defp color_to_ansi(:green), do: "32"
  defp color_to_ansi(:yellow), do: "33"
  defp color_to_ansi(:blue), do: "34"
  defp color_to_ansi(:magenta), do: "35"
  defp color_to_ansi(:cyan), do: "36"
  defp color_to_ansi(:white), do: "37"
  defp color_to_ansi(_), do: "37" # default to white

  defp style_to_ansi(:normal), do: "0"
  defp style_to_ansi(:bold), do: "1"
  defp style_to_ansi(:italic), do: "3"
  defp style_to_ansi(_), do: "0" # default to normal
end