# Surface 2: Configuration & Options System

## Current State
- No configuration options
- Hard-coded validation behavior
- No customization capabilities

## Target Capabilities (from Rust crate)
- `ValidationOptions` with rich configuration
- Draft-specific option builders (`draft7::options()`, etc.)
- Format validation control
- Regular expression engine selection
- External reference handling options
- Performance tuning options

## Proposed Elixir API Design

### Options Module
```elixir
defmodule ExJsonschema.Options do
  @type t :: %__MODULE__{
    # Core options
    draft: :auto | :draft4 | :draft6 | :draft7 | :draft201909 | :draft202012,
    validate_formats: boolean(),
    ignore_unknown_formats: boolean(),
    
    # Reference resolution
    resolve_external_refs: boolean(),
    base_uri: String.t() | nil,
    retriever: module() | nil,
    
    # Performance
    regex_engine: :fancy | :regex,
    max_schema_depth: pos_integer(),
    
    # Output control
    collect_annotations: boolean(),
    output_style: :flag | :basic | :detailed | :verbose,
    
    # Custom validation
    custom_keywords: [module()],
    custom_formats: [module()]
  }
  
  def new(opts \\ []), do: struct(__MODULE__, opts)
  
  def draft4(opts \\ []), do: new([draft: :draft4] ++ opts)
  def draft6(opts \\ []), do: new([draft: :draft6] ++ opts)  
  def draft7(opts \\ []), do: new([draft: :draft7] ++ opts)
  def draft201909(opts \\ []), do: new([draft: :draft201909] ++ opts)
  def draft202012(opts \\ []), do: new([draft: :draft202012] ++ opts)
end
```

### Enhanced Compilation API
```elixir
# Using options struct
options = ExJsonschema.Options.draft7(validate_formats: true)
{:ok, validator} = ExJsonschema.compile(schema, options)

# Using keyword list (converted internally)
{:ok, validator} = ExJsonschema.compile(schema, 
  draft: :draft7,
  validate_formats: true,
  ignore_unknown_formats: false
)

# Draft-specific compilation
{:ok, validator} = ExJsonschema.compile_draft7(schema, validate_formats: true)
{:ok, validator} = ExJsonschema.compile_draft202012(schema, base_uri: "https://example.com/")
```

### Configuration Profiles
```elixir
defmodule ExJsonschema.Profiles do
  def strict do
    ExJsonschema.Options.new(
      validate_formats: true,
      ignore_unknown_formats: false,
      resolve_external_refs: true,
      output_style: :detailed
    )
  end
  
  def lenient do
    ExJsonschema.Options.new(
      validate_formats: false,
      ignore_unknown_formats: true,
      resolve_external_refs: false,
      output_style: :basic
    )
  end
  
  def performance do
    ExJsonschema.Options.new(
      regex_engine: :regex,
      collect_annotations: false,
      output_style: :flag
    )
  end
end

# Usage
{:ok, validator} = ExJsonschema.compile(schema, ExJsonschema.Profiles.strict())
```

## Implementation Plan

### Phase 1: Options Infrastructure
1. Create `ExJsonschema.Options` struct with all fields
2. Add option validation and transformation functions  
3. Create draft-specific option builders
4. Update Rust NIF to accept option parameters

### Phase 2: Core Options Integration
1. Implement draft selection in Rust
2. Add format validation controls
3. Add regex engine selection
4. Handle base URI configuration

### Phase 3: Advanced Options
1. Implement external reference controls
2. Add performance tuning options
3. Create configuration profiles
4. Add option validation and helpful error messages

### Phase 4: Developer Experience
1. Create option migration helpers
2. Add comprehensive documentation
3. Provide configuration recipes
4. Add configuration validation

## Rust Integration Points
- Map Elixir options to Rust `ValidationOptions`
- Use draft-specific option builders when appropriate
- Handle option conflicts and invalid combinations
- Provide meaningful error messages for bad configurations

## Configuration Examples

### API Validation Setup
```elixir
api_options = ExJsonschema.Options.new(
  draft: :draft202012,
  validate_formats: true,
  base_uri: "https://api.example.com/schemas/",
  resolve_external_refs: true,
  output_style: :detailed
)
```

### High-Performance Setup  
```elixir
perf_options = ExJsonschema.Options.new(
  draft: :draft7,
  validate_formats: false,
  regex_engine: :regex,
  collect_annotations: false,
  output_style: :flag
)
```

### Development/Testing Setup
```elixir
dev_options = ExJsonschema.Options.new(
  draft: :auto,
  validate_formats: true,
  ignore_unknown_formats: false,
  output_style: :verbose
)
```

## Backward Compatibility
- Default options maintain current behavior exactly
- All existing APIs continue to work without changes
- Options are additive - no breaking changes
- Clear upgrade path documentation