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

- **Total validation errors**: 7
- **Error types demonstrated**: enum, minimum, minLength, format, uniqueItems, additionalProperties, pattern
- **Nested path examples**: Shows deep object and array path handling
- **All 5 formats**: human, json, table, markdown, llm

## Generation

This demo was generated using:

mix demo

Run this command anytime to regenerate the examples with the latest formatting features.
