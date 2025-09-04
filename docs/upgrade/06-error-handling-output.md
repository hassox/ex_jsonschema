# Surface 6: Error Handling & Output

## Current State
- Basic error information with path and message
- Single error format
- Limited error context

## Target Capabilities (from Rust crate)
- Multiple output formats (flag, basic, detailed, verbose)
- Rich error context with schema paths
- Annotation collection and reporting
- Structured error hierarchies
- Custom error formatting
- Error aggregation and filtering

## Proposed Elixir API Design

### Enhanced Error Structures
```elixir
defmodule ExJsonschema.ValidationError do
  @type t :: %__MODULE__{
    # Core error info
    message: String.t(),
    instance_path: String.t(),
    schema_path: String.t(),
    
    # Enhanced context
    keyword: String.t(),
    instance_value: term(),
    schema_value: term(),
    
    # Error classification
    severity: :error | :warning | :info,
    error_code: atom(),
    
    # Additional context
    annotations: map(),
    suggested_fix: String.t() | nil,
    documentation_url: String.t() | nil,
    
    # Nested errors for complex validations
    sub_errors: [t()] | []
  }
end

defmodule ExJsonschema.CompilationError do
  @type t :: %__MODULE__{
    # Current fields (keep for compatibility)
    type: atom(),
    message: String.t(),
    details: String.t(),
    
    # Enhanced fields
    location: String.t() | nil,
    schema_path: String.t() | nil,
    suggested_fix: String.t() | nil,
    error_code: atom(),
    
    # For reference resolution errors
    failed_reference: String.t() | nil,
    reference_chain: [String.t()] | []
  }
end
```

### Output Format Control
```elixir
defmodule ExJsonschema.Output do
  @type format :: :flag | :basic | :detailed | :verbose | :structured
  @type options :: %{
    format: format(),
    include_annotations: boolean(),
    include_schema_context: boolean(),
    include_suggestions: boolean(),
    max_errors: pos_integer() | :unlimited,
    error_filter: (ExJsonschema.ValidationError.t() -> boolean()) | nil
  }
end

# Enhanced validation with output control
{:error, errors} = ExJsonschema.validate(validator, instance, 
  output: %ExJsonschema.Output{
    format: :detailed,
    include_annotations: true,
    include_suggestions: true,
    max_errors: 10
  }
)

# Shorthand for common formats
{:error, errors} = ExJsonschema.validate(validator, instance, output: :verbose)
{:error, errors} = ExJsonschema.validate(validator, instance, output: :basic)
```

### Error Formatting and Reporting
```elixir
defmodule ExJsonschema.ErrorFormatter do
  @type format :: :human | :json | :yaml | :table | :markdown
  
  @spec format([ExJsonschema.ValidationError.t()], format()) :: String.t()
  def format(errors, format \\ :human)
  
  @spec format_for_logging([ExJsonschema.ValidationError.t()]) :: String.t()
  def format_for_logging(errors)
  
  @spec format_for_api([ExJsonschema.ValidationError.t()]) :: [map()]
  def format_for_api(errors)
  
  @spec group_by_path([ExJsonschema.ValidationError.t()]) :: map()
  def group_by_path(errors)
  
  @spec filter_by_severity([ExJsonschema.ValidationError.t()], atom()) :: [ExJsonschema.ValidationError.t()]
  def filter_by_severity(errors, severity)
end
```

### Error Analysis and Utilities
```elixir
defmodule ExJsonschema.ErrorAnalysis do
  @spec count_by_keyword([ExJsonschema.ValidationError.t()]) :: map()
  def count_by_keyword(errors)
  
  @spec most_common_errors([ExJsonschema.ValidationError.t()]) :: [{String.t(), non_neg_integer()}]
  def most_common_errors(errors)
  
  @spec suggest_schema_fixes([ExJsonschema.ValidationError.t()]) :: [String.t()]
  def suggest_schema_fixes(errors)
  
  @spec find_root_cause([ExJsonschema.ValidationError.t()]) :: ExJsonschema.ValidationError.t() | nil
  def find_root_cause(errors)
end
```

### Structured Error Handling
```elixir
# Error handling with pattern matching
case ExJsonschema.validate(validator, instance, output: :structured) do
  :ok -> 
    :ok
    
  {:error, errors} ->
    errors
    |> ExJsonschema.ErrorAnalysis.group_by_keyword()
    |> handle_grouped_errors()
end

defp handle_grouped_errors(grouped_errors) do
  Enum.each(grouped_errors, fn
    {"required", errors} -> handle_missing_fields(errors)
    {"type", errors} -> handle_type_mismatches(errors)  
    {"format", errors} -> handle_format_violations(errors)
    {keyword, errors} -> handle_generic_errors(keyword, errors)
  end)
end
```

## Implementation Plan

### Phase 1: Enhanced Error Structures
1. Expand ValidationError and CompilationError structs
2. Update Rust NIF to provide richer error context
3. Add error classification and severity levels
4. Implement nested error support

### Phase 2: Output Format System
1. Implement multiple output format support in Rust
2. Add output format configuration to validation
3. Create error filtering and limiting functionality
4. Add annotation collection support

### Phase 3: Error Formatting and Reporting
1. Implement ErrorFormatter module with multiple output formats
2. Add specialized formatting for different use cases
3. Create error grouping and analysis utilities
4. Add suggestion generation system

### Phase 4: Advanced Error Features
1. Implement error correlation and root cause analysis
2. Add error trend analysis and reporting
3. Create error documentation and help system
4. Add error debugging and introspection tools

## Rust Integration Points
- Use Rust output format system (`jsonschema::output`)
- Collect rich validation context from Rust validator
- Handle annotation gathering and serialization
- Map Rust error types to enhanced Elixir structures

## API Examples

### API Validation with Rich Errors
```elixir
def validate_api_request(schema, request_json) do
  case ExJsonschema.validate(schema, request_json, 
    output: %ExJsonschema.Output{
      format: :detailed,
      include_suggestions: true,
      max_errors: 5
    }) do
    :ok -> 
      {:ok, :valid}
      
    {:error, errors} ->
      formatted_errors = ExJsonschema.ErrorFormatter.format_for_api(errors)
      {:error, %{
        message: "Validation failed",
        errors: formatted_errors,
        error_count: length(errors)
      }}
  end
end
```

### Development-friendly Error Display
```elixir
def validate_with_helpful_errors(schema, instance) do
  case ExJsonschema.validate(schema, instance, output: :verbose) do
    :ok -> 
      IO.puts("✅ Validation passed!")
      
    {:error, errors} ->
      IO.puts("❌ Validation failed:")
      
      errors
      |> ExJsonschema.ErrorFormatter.format(:human)
      |> IO.puts()
      
      # Show suggestions
      suggestions = ExJsonschema.ErrorAnalysis.suggest_schema_fixes(errors)
      if suggestions != [] do
        IO.puts("\n💡 Suggestions:")
        Enum.each(suggestions, &IO.puts("  • #{&1}"))
      end
  end
end
```

### Error Aggregation for Monitoring
```elixir
def collect_validation_metrics(errors) do
  keyword_counts = ExJsonschema.ErrorAnalysis.count_by_keyword(errors)
  common_errors = ExJsonschema.ErrorAnalysis.most_common_errors(errors)
  
  :telemetry.execute([:validation, :errors], %{
    total_errors: length(errors),
    error_types: map_size(keyword_counts),
    most_common: common_errors |> List.first() |> elem(0)
  })
end
```

### Custom Error Formatting
```elixir
defmodule MyApp.CustomErrorFormatter do
  def format_for_user(errors) do
    errors
    |> Enum.group_by(& &1.instance_path)
    |> Enum.map(fn {path, path_errors} ->
      %{
        field: human_readable_path(path),
        issues: Enum.map(path_errors, &format_single_error/1)
      }
    end)
  end
  
  defp format_single_error(error) do
    %{
      problem: simplify_message(error.message),
      suggestion: error.suggested_fix,
      severity: error.severity
    }
  end
  
  defp human_readable_path("/properties/user/properties/email"), do: "user email"
  defp human_readable_path("/items/0/properties/name"), do: "first item name"
  defp human_readable_path(path), do: String.replace(path, ~r{/properties/}, ".")
end
```

### Error Filtering and Analysis
```elixir
def analyze_validation_errors(errors) do
  # Filter by severity
  critical_errors = ExJsonschema.ErrorAnalysis.filter_by_severity(errors, :error)
  warnings = ExJsonschema.ErrorAnalysis.filter_by_severity(errors, :warning)
  
  # Group by type
  grouped = ExJsonschema.ErrorAnalysis.group_by_keyword(errors)
  
  # Find patterns
  if Map.has_key?(grouped, "required") and Map.has_key?(grouped, "additionalProperties") do
    IO.puts("🔍 Detected potential schema design issue: required fields with strict additional properties")
  end
  
  # Root cause analysis
  case ExJsonschema.ErrorAnalysis.find_root_cause(errors) do
    %{keyword: "type"} = root_error ->
      IO.puts("🎯 Root cause: Type mismatch at #{root_error.instance_path}")
    _ ->
      IO.puts("🎯 Multiple validation issues detected")
  end
end
```

## Output Format Examples

### Human-readable Format
```
❌ Validation failed with 3 errors:

  • /user/email: "invalid-email" is not a valid email format
    💡 Suggestion: Check the email format (expected: user@domain.com)
    
  • /user/age: -5 is less than the minimum value of 0  
    💡 Suggestion: Age must be a positive number
    
  • /preferences: Property "invalidKey" is not allowed
    💡 Suggestion: Remove unknown property or update schema
```

### Structured JSON Format
```json
{
  "valid": false,
  "error_count": 3,
  "errors": [
    {
      "message": "\"invalid-email\" is not a valid email format",
      "instance_path": "/user/email", 
      "schema_path": "/properties/user/properties/email/format",
      "keyword": "format",
      "severity": "error",
      "error_code": "format_violation",
      "suggested_fix": "Check the email format (expected: user@domain.com)"
    }
  ]
}
```

## Use Cases

### API Gateway Validation
- Detailed errors for debugging during development
- Concise errors for production API responses  
- Error aggregation for monitoring and alerting

### Configuration Validation
- Human-readable errors for operators
- Suggested fixes for common configuration mistakes
- Error grouping by configuration section

### Data Pipeline Validation
- Batch error reporting for large datasets
- Error sampling and rate limiting
- Schema evolution guidance based on error patterns

## Backward Compatibility
- Current error structures remain supported
- Default output format maintains existing behavior
- Enhanced features available through opt-in parameters
- Gradual migration path for applications wanting richer errors