# ExJsonschema Error Handling Examples

This directory contains comprehensive examples demonstrating all error handling capabilities introduced in Milestones M3.1-M3.5 of the ExJsonschema upgrade project.

## Overview

The examples in this directory serve dual purposes:
1. **Comprehensive Test Coverage** - Validate that all error handling features work correctly
2. **Living Documentation** - Provide practical, tested examples for real-world usage

All examples are implemented as ExUnit test cases that can be executed to verify functionality.

## Contents

### 📋 [error_handling_examples_test.exs](./error_handling_examples_test.exs)

**18 comprehensive examples** covering fundamental error handling patterns:

#### Basic Error Handling Examples (Examples 1-3)
- **Example 1**: Simple type validation error with basic error handling
- **Example 2**: Nested object validation errors with path-based grouping  
- **Example 3**: Array validation with multiple constraint violations

#### Error Formatting Examples (Examples 4-8)
- **Example 4**: Human-readable formatting for terminal output with colors
- **Example 5**: JSON formatting for API responses (compact and pretty)
- **Example 6**: Table formatting for reports and debugging
- **Example 7**: Markdown formatting for documentation generation
- **Example 8**: LLM formatting for AI assistant integration (prose and structured)

#### Error Analysis Examples (Examples 9-13)
- **Example 9**: Comprehensive error analysis with categorization and insights
- **Example 10**: Error categorization and grouping by type and path
- **Example 11**: Severity analysis for error prioritization
- **Example 12**: Pattern detection for systematic fixes
- **Example 13**: Comprehensive error summary generation

#### Real-World Error Scenarios (Examples 14-16)
- **Example 14**: API request validation workflow with structured responses
- **Example 15**: Configuration file validation with detailed reporting
- **Example 16**: Form validation with user-friendly messages

#### Advanced Error Handling Workflows (Examples 17-18)
- **Example 17**: Multi-step validation with error accumulation
- **Example 18**: Error handling with custom business context and suggestions

### 🔌 [error_integration_examples_test.exs](./error_integration_examples_test.exs)

**10 integration examples** showing real-world framework and ecosystem integration:

#### Phoenix/Web Framework Integration (Examples 1-2)
- **Example 1**: Phoenix controller with comprehensive error handling
- **Example 2**: API middleware for automatic validation

#### Logging and Monitoring Integration (Examples 3-4) 
- **Example 3**: Structured logging with error analysis
- **Example 4**: Metrics collection for monitoring systems

#### Database Integration (Examples 5-6)
- **Example 5**: Ecto changeset integration pattern
- **Example 6**: JSON column validation in database

#### Configuration and Environment Integration (Examples 7-8)
- **Example 7**: Application configuration validation at startup
- **Example 8**: Environment variable validation

#### Testing and Development Integration (Examples 9-10)
- **Example 9**: Test data validation in test suites
- **Example 10**: Development-time schema validation warnings

## Key Features Demonstrated

### ✨ Error Formatting (5 Formats)
All examples use the 5 error formatting options introduced in M3.3:

| Format | Use Case | Key Features |
|--------|----------|--------------|
| `:human` | Terminal/CLI output | ANSI colors, readable layout, suggestions |
| `:json` | API responses | Compact/pretty options, structured data |
| `:table` | Reports/debugging | ASCII tables, compact mode |
| `:markdown` | Documentation | TOC support, heading levels |  
| `:llm` | AI integration | Prose/structured modes, context control |

### 📊 Error Analysis Capabilities
Comprehensive error analysis introduced in M3.4:

- **Categorization**: `type_mismatch`, `constraint_violation`, `structural`, `format`, `custom`
- **Severity Levels**: `critical`, `high`, `medium`, `low`
- **Pattern Detection**: `missing_properties`, `type_conflicts`, `range_violations`, `format_issues`
- **Actionable Recommendations**: Context-aware fix suggestions

### 🎯 Configuration Profiles
Examples demonstrate the 3 configuration profiles from M3.1:

- **Strict Profile**: Maximum validation rigor, verbose output
- **Lenient Profile**: User-friendly validation, detailed output  
- **Performance Profile**: Speed-optimized, minimal output

### 🚀 Draft-Specific Compilation
Examples show draft-specific compilation shortcuts from M3.5:

- `compile_draft4/2`, `compile_draft6/2`, `compile_draft7/2`
- `compile_draft201909/2`, `compile_draft202012/2`
- `compile_auto_draft/2` with automatic detection

## Running the Examples

### Run All Examples
```bash
# Run all error handling examples
mix test test/examples/

# Run with detailed output
mix test test/examples/ --trace
```

### Run Specific Examples
```bash  
# Run basic error handling examples
mix test test/examples/error_handling_examples_test.exs

# Run integration examples
mix test test/examples/error_integration_examples_test.exs

# Run specific test by line number
mix test test/examples/error_handling_examples_test.exs:42
```

### Generate Demo Examples
```bash
# Generate comprehensive error formatting demos
mix demo

# View generated examples
ls demo/
cat demo/README.md
```

## Integration Patterns

### Phoenix Controllers
```elixir
case ExJsonschema.validate(validator, params_json, output: :detailed) do
  :ok -> 
    # Success handling
    {:ok, data}
    
  {:error, validation_errors} ->
    # Convert to Phoenix-style errors
    field_errors = convert_to_changeset_errors(validation_errors)
    {:error, field_errors}
end
```

### API Responses
```elixir
# Format errors for JSON API response
formatted_errors = ExJsonschema.format_errors(errors, :json, pretty: false)

%{
  status: "error",
  message: "Validation failed",
  errors: Jason.decode!(formatted_errors),
  timestamp: DateTime.utc_now()
}
```

### Logging and Monitoring
```elixir
# Analyze errors for structured logging
analysis = ExJsonschema.analyze_errors(errors)

Logger.error("Validation failed", %{
  error_count: analysis.total_errors,
  categories: analysis.categories,
  patterns: analysis.patterns,
  recommendations: analysis.recommendations
})
```

### Configuration Validation
```elixir
# Validate application config at startup
case ExJsonschema.validate(validator, config_json, output: :verbose) do
  :ok -> 
    :ok
    
  {:error, errors} ->
    formatted = ExJsonschema.format_errors(errors, :human, color: false)
    raise "Configuration validation failed:\n#{formatted}"
end
```

## Best Practices

### 1. Choose the Right Output Format
- Use `:detailed` output for user-facing validations
- Use `:verbose` output for debugging and analysis
- Use `:basic` output for high-performance scenarios

### 2. Format Errors Appropriately
- `:human` format for CLI and terminal output
- `:json` format for API responses and logging
- `:table` format for debugging and reports
- `:markdown` format for documentation
- `:llm` format for AI assistant integration

### 3. Leverage Error Analysis
- Use `ExJsonschema.analyze_errors/1` for comprehensive insights
- Group errors by severity for prioritization
- Use pattern detection for systematic fixes
- Include recommendations in user feedback

### 4. Handle Errors Gracefully
- Always provide user-friendly error messages
- Group related errors for better UX
- Include suggestions for fixing errors
- Log detailed errors for debugging

### 5. Test Error Scenarios
- Validate test fixtures with schemas
- Test error handling paths in your code
- Use examples as integration tests
- Document expected error scenarios

## API Reference

### Core Functions
- `ExJsonschema.validate/3` - Validate with configurable output
- `ExJsonschema.format_errors/3` - Format errors in multiple formats
- `ExJsonschema.analyze_errors/1,2` - Comprehensive error analysis

### Configuration Profiles
- `ExJsonschema.Profile.strict/0` - Maximum validation rigor
- `ExJsonschema.Profile.lenient/0` - User-friendly validation  
- `ExJsonschema.Profile.performance/0` - Speed-optimized validation

### Draft-Specific Compilation
- `ExJsonschema.compile_draft4/2` through `ExJsonschema.compile_draft202012/2`
- `ExJsonschema.compile_auto_draft/2` - Automatic draft detection

## Contributing

When adding new error handling examples:

1. **Follow the Pattern**: Use ExUnit test cases that serve as both tests and documentation
2. **Include Real-World Context**: Show practical usage in common scenarios  
3. **Test All Formats**: Demonstrate multiple error formatting options
4. **Add Helper Functions**: Extract reusable patterns for clarity
5. **Document Integration**: Show how to integrate with existing systems

## M3.6 Deliverable Completion

These examples fulfill the M3.6 "Comprehensive Error Handling Examples" requirement by providing:

✅ **Complete Coverage** - All error handling features from M3.1-M3.5  
✅ **Working Examples** - All examples are tested and functional  
✅ **Real-World Scenarios** - Integration with common Elixir ecosystem tools  
✅ **Production Patterns** - Ready-to-use code patterns for applications  
✅ **Documentation** - Self-documenting test cases with explanations  

The examples demonstrate the mature error handling ecosystem introduced in M3, showing how ExJsonschema can now provide comprehensive validation feedback suitable for production applications, developer tooling, and integration with the broader Elixir ecosystem.