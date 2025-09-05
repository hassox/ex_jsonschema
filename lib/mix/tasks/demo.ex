defmodule Mix.Tasks.Demo do
  @moduledoc """
  Generates comprehensive error formatting examples.

  This task creates example outputs for all available error formats
  and saves them to the demo/ directory.

  ## Usage

      mix demo
      
  ## Generated Files

  The task will create a demo/ directory with examples of:
  - Human formats (with and without colors)  
  - JSON formats (compact and pretty)
  - Table formats (standard and compact)
  - Markdown formats (basic, with TOC, custom heading levels)
  - LLM formats (prose and structured)
  - README.md with comprehensive documentation
  """

  use Mix.Task

  @shortdoc "Generate error formatting demo examples"

  def run(_args) do
    Mix.Task.run("app.start")

    IO.puts("ExJsonschema Error Formatting Demo")
    IO.puts("=====================================")

    # Ensure demo directory exists
    File.mkdir_p!("demo")

    # Create complex schema for testing
    schema = create_demo_schema()
    invalid_json = create_invalid_json()

    # Compile and validate to get errors
    {:ok, validator} = ExJsonschema.compile(schema)
    {:error, errors} = ExJsonschema.validate(validator, invalid_json, output: :verbose)

    IO.puts("Generated #{length(errors)} validation errors")
    IO.puts("Available formats: #{inspect(ExJsonschema.ErrorFormatter.available_formats())}")
    IO.puts("Saving demo outputs to demo/ directory...")

    # Generate all format examples
    generate_human_formats(errors)
    generate_json_formats(errors)
    generate_table_formats(errors)
    generate_markdown_formats(errors)
    generate_llm_formats(errors)
    generate_readme(errors)

    # Show completion summary
    show_completion_summary()

    IO.puts("\\nExplore the demo/ directory for complete examples!")
    IO.puts("Try: cat demo/errors_with_toc.md | head -20")
  end

  defp create_demo_schema do
    # Build the regex pattern safely to avoid parser bug with )?$ sequence
    lang_pattern = "^[a-z]{2}(-[A-Z]{2})" <> "?" <> "$"

    ~s({
      "type": "object",
      "properties": {
        "user": {
          "type": "object",
          "properties": {
            "name": {
              "type": "string",
              "minLength": 2,
              "maxLength": 50
            },
            "age": {
              "type": "number", 
              "minimum": 18,
              "maximum": 99
            },
            "email": {
              "type": "string",
              "format": "email"
            },
            "roles": {
              "type": "array",
              "items": {
                "type": "string",
                "enum": ["admin", "user", "moderator"]
              },
              "minItems": 1,
              "uniqueItems": true
            }
          },
          "required": ["name", "age", "email"]
        },
        "preferences": {
          "type": "object",
          "properties": {
            "theme": {
              "type": "string",
              "enum": ["light", "dark", "auto"]
            },
            "notifications": {
              "type": "object",
              "properties": {
                "email": {"type": "boolean"},
                "push": {"type": "boolean"}
              },
              "additionalProperties": false
            }
          }
        },
        "settings": {
          "type": "object",
          "properties": {
            "language": {
              "type": "string",
              "pattern": "#{lang_pattern}"
            }
          }
        }
      },
      "required": ["user", "preferences"]
    })
  end

  defp create_invalid_json do
    ~s({
      "user": {
        "name": "X",
        "age": 15,
        "email": "not-an-email",
        "roles": ["admin", "invalid-role", "admin"]
      },
      "preferences": {
        "theme": "purple",
        "notifications": {
          "email": true,
          "push": false,
          "sms": true
        }
      },
      "settings": {
        "language": "invalid-lang-code"
      }
    })
  end

  defp generate_human_formats(errors) do
    IO.puts("\\nGenerating human format examples...")

    human_with_colors = ExJsonschema.format_errors(errors, :human, color: true, max_errors: 5)
    File.write!("demo/human_with_colors.txt", human_with_colors)

    human_no_colors = ExJsonschema.format_errors(errors, :human, color: false, max_errors: 10)
    File.write!("demo/human_no_colors.txt", human_no_colors)
  end

  defp generate_json_formats(errors) do
    IO.puts("Generating JSON format examples...")

    json_compact = ExJsonschema.format_errors(errors, :json, pretty: false)
    File.write!("demo/errors_compact.json", json_compact)

    json_pretty = ExJsonschema.format_errors(errors, :json, pretty: true)
    File.write!("demo/errors_pretty.json", json_pretty)
  end

  defp generate_table_formats(errors) do
    IO.puts("Generating table format examples...")

    table_standard = ExJsonschema.format_errors(errors, :table)
    File.write!("demo/errors_table.txt", table_standard)

    table_compact = ExJsonschema.format_errors(errors, :table, compact: true)
    File.write!("demo/errors_table_compact.txt", table_compact)
  end

  defp generate_markdown_formats(errors) do
    IO.puts("Generating markdown format examples...")

    markdown_basic = ExJsonschema.format_errors(errors, :markdown)
    File.write!("demo/errors_basic.md", markdown_basic)

    markdown_with_toc =
      ExJsonschema.format_errors(errors, :markdown,
        include_toc: true,
        heading_level: 1
      )

    File.write!("demo/errors_with_toc.md", markdown_with_toc)

    markdown_h3 =
      ExJsonschema.format_errors(errors, :markdown,
        heading_level: 3,
        max_errors: 3
      )

    File.write!("demo/errors_h3.md", markdown_h3)
  end

  defp generate_llm_formats(errors) do
    IO.puts("Generating LLM format examples...")

    llm_prose = ExJsonschema.format_errors(errors, :llm)
    File.write!("demo/llm_prose.txt", llm_prose)

    llm_prose_no_schema = ExJsonschema.format_errors(errors, :llm, include_schema_context: false)
    File.write!("demo/llm_prose_no_schema.txt", llm_prose_no_schema)

    llm_structured =
      ExJsonschema.format_errors(errors, :llm,
        structured: true,
        max_errors: 10
      )

    File.write!("demo/llm_structured.txt", llm_structured)

    llm_structured_minimal =
      ExJsonschema.format_errors(errors, :llm,
        structured: true,
        include_schema_context: false
      )

    File.write!("demo/llm_structured_minimal.txt", llm_structured_minimal)
  end

  defp generate_readme(errors) do
    readme_content = """
    # ExJsonschema Error Formatting Demo

    This directory contains examples of all error formatting options available in ExJsonschema.

    ## Schema Used

    The demo uses a complex user profile schema with nested objects, arrays, enums, and various validation rules including:

    - String length constraints
    - Numeric ranges  
    - Email format validation
    - Array uniqueness and enum constraints
    - Object property requirements
    - Pattern matching for language codes

    ## Invalid Data

    The test data intentionally violates multiple validation rules to demonstrate different error types:

    - Too short string (name: "X")
    - Value below minimum (age: 15) 
    - Invalid email format (email: "not-an-email")
    - Invalid enum values and duplicates in array
    - Additional properties not allowed
    - Pattern matching failures

    ## Format Examples

    ### Human-Readable Formats
    - human_with_colors.txt - ANSI colored output for terminals
    - human_no_colors.txt - Plain text for logs and non-terminal output

    ### JSON Formats  
    - errors_compact.json - Minified JSON for APIs
    - errors_pretty.json - Pretty-printed JSON for debugging

    ### Table Formats
    - errors_table.txt - Standard ASCII table format
    - errors_table_compact.txt - Compact table layout

    ### Markdown Formats
    - errors_basic.md - Basic markdown structure
    - errors_with_toc.md - With table of contents and H1 headings
    - errors_h3.md - Custom heading level (H3) with limited errors

    ### LLM Formats
    - llm_prose.txt - Natural language format for AI analysis
    - llm_prose_no_schema.txt - Prose format without schema paths
    - llm_structured.txt - Structured key-value format
    - llm_structured_minimal.txt - Minimal structured format

    ## Usage

    Each format can be generated with:

    ExJsonschema.format_errors(errors, format, options)

    See the main ExJsonschema documentation for all available options.

    ## Generated Statistics

    - **Total validation errors**: #{length(errors)}
    - **Error types demonstrated**: enum, minimum, minLength, format, uniqueItems, additionalProperties, pattern
    - **Nested path examples**: Shows deep object and array path handling
    - **All #{length(ExJsonschema.ErrorFormatter.available_formats())} formats**: #{Enum.join(ExJsonschema.ErrorFormatter.available_formats(), ", ")}

    ## Generation

    This demo was generated using:

    mix demo

    Run this command anytime to regenerate the examples with the latest formatting features.
    """

    File.write!("demo/README.md", readme_content)
  end

  defp show_completion_summary do
    IO.puts("\\nDemo generation complete!")
    IO.puts("Generated #{length(File.ls!("demo"))} files in demo/ directory:")

    File.ls!("demo")
    |> Enum.sort()
    |> Enum.each(fn file ->
      size = File.stat!("demo/#{file}").size
      IO.puts("   #{file} (#{size} bytes)")
    end)

    IO.puts("\\nFormat examples generated:")
    IO.puts("   - Human formats (2 files) - Console and logging")
    IO.puts("   - JSON formats (2 files) - APIs and debugging")
    IO.puts("   - Table formats (2 files) - Reports and analysis")
    IO.puts("   - Markdown formats (3 files) - Documentation")
    IO.puts("   - LLM formats (4 files) - AI assistant consumption")
    IO.puts("   - README.md - Complete documentation")
  end
end
