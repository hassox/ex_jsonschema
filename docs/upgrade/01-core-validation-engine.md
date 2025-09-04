# Surface 1: Core Validation Engine

## Current State
- Basic `compile/1` → `validate/2` flow
- Single validation mode
- Limited error information

## Target Capabilities (from Rust crate)
- Multiple validation approaches (one-off vs reusable)
- Quick validity checks (`is_valid`)
- Detailed validation with full error context
- Multiple output formats
- Different validation strategies

## Proposed Elixir API Design

### Enhanced Compilation
```elixir
# Current (keep for backward compatibility)
{:ok, validator} = ExJsonschema.compile(schema_json)

# Enhanced with options
{:ok, validator} = ExJsonschema.compile(schema_json, draft: :draft7)
{:ok, validator} = ExJsonschema.compile(schema_json, validate_formats: true)
{:ok, validator} = ExJsonschema.compile(schema_json, 
  draft: :auto,
  validate_formats: true,
  ignore_unknown_formats: false
)
```

### Enhanced Validation
```elixir
# Current (keep for backward compatibility)  
:ok = ExJsonschema.validate(validator, instance)
{:error, errors} = ExJsonschema.validate(validator, instance)

# Quick validity check (new)
true = ExJsonschema.valid?(validator, instance)

# One-shot validation (enhanced)
:ok = ExJsonschema.validate_once(schema, instance)
:ok = ExJsonschema.validate_once(schema, instance, draft: :draft202012)

# Validation with output control
{:error, errors} = ExJsonschema.validate(validator, instance, output: :basic)
{:error, errors} = ExJsonschema.validate(validator, instance, output: :detailed)
{:error, errors} = ExJsonschema.validate(validator, instance, output: :flag)
```

### New Validation Modes
```elixir
# Streaming validation for large documents
{:ok, stream} = ExJsonschema.validate_stream(validator, json_stream)

# Early termination validation
{:error, first_error} = ExJsonschema.validate_first_error(validator, instance)
```

## Implementation Plan

### Phase 1: Enhanced Options Structure
1. Create `ExJsonschema.Options` module
2. Add draft selection support
3. Add format validation controls
4. Extend Rust NIF to handle ValidationOptions

### Phase 2: Multiple Validation Modes  
1. Implement `valid?/2` for quick checks
2. Add output format control to `validate/3`
3. Enhance one-shot validation with options
4. Add first-error validation mode

### Phase 3: Advanced Validation
1. Research streaming validation feasibility
2. Implement validation result formatting
3. Add performance optimization controls

## Rust Integration Points
- Use `jsonschema::ValidationOptions` builder
- Leverage `Validator.is_valid()` vs `Validator.validate()`
- Map Rust output formats to Elixir equivalents
- Handle different draft-specific validators

## Backward Compatibility
- All current APIs remain unchanged
- New functionality available via optional parameters
- Graceful fallbacks for unsupported options

## User Experience
- Clear separation between quick checks and detailed validation
- Consistent option naming across all functions
- Comprehensive examples for each validation mode
- Migration guide from current API