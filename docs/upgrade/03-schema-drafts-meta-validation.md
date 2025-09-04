# Surface 3: Schema Drafts & Meta-validation

## Current State
- No explicit draft support
- No schema meta-validation
- Automatic draft detection (limited)

## Target Capabilities (from Rust crate)
- Support for JSON Schema drafts: 4, 6, 7, 2019-09, 2020-12
- Explicit draft selection and validation
- Meta-schema validation (validate schemas themselves)
- Draft-specific feature support
- Draft migration utilities

## Proposed Elixir API Design

### Draft Management
```elixir
defmodule ExJsonschema.Draft do
  @type draft :: :draft4 | :draft6 | :draft7 | :draft201909 | :draft202012 | :auto
  
  @spec detect(String.t()) :: {:ok, draft()} | {:error, term()}
  def detect(schema_json)
  
  @spec supported_drafts() :: [draft()]
  def supported_drafts()
  
  @spec features(draft()) :: [atom()]
  def features(:draft7)  # [:if_then_else, :contains, :const, ...]
  def features(:draft202012)  # [:unevaluatedProperties, :prefixItems, ...]
end
```

### Meta-validation
```elixir
defmodule ExJsonschema.Meta do
  @spec validate_schema(String.t()) :: :ok | {:error, [ExJsonschema.ValidationError.t()]}
  def validate_schema(schema_json)
  
  @spec validate_schema(String.t(), ExJsonschema.Draft.draft()) :: :ok | {:error, [ExJsonschema.ValidationError.t()]}  
  def validate_schema(schema_json, draft)
  
  @spec valid_schema?(String.t()) :: boolean()
  def valid_schema?(schema_json)
  
  @spec get_meta_schema(ExJsonschema.Draft.draft()) :: String.t()
  def get_meta_schema(:draft7)  # Returns the draft-7 meta-schema JSON
end
```

### Enhanced Schema Compilation
```elixir
# Explicit draft compilation
{:ok, validator} = ExJsonschema.compile(schema, draft: :draft7)
{:ok, validator} = ExJsonschema.compile(schema, draft: :draft202012)

# Compile with meta-validation
{:ok, validator} = ExJsonschema.compile(schema, 
  draft: :draft7, 
  validate_schema: true
)

# Draft-specific compilation shortcuts
{:ok, validator} = ExJsonschema.compile_draft7(schema)
{:ok, validator} = ExJsonschema.compile_draft202012(schema)

# Get draft information from compiled validator
{:ok, :draft7} = ExJsonschema.get_draft(validator)
```

### Draft Migration Utilities
```elixir
defmodule ExJsonschema.Migration do
  @spec can_migrate?(String.t(), ExJsonschema.Draft.draft(), ExJsonschema.Draft.draft()) :: boolean()
  def can_migrate?(schema_json, from_draft, to_draft)
  
  @spec migrate_schema(String.t(), ExJsonschema.Draft.draft(), ExJsonschema.Draft.draft()) :: 
    {:ok, String.t()} | {:error, term()}
  def migrate_schema(schema_json, from_draft, to_draft)
  
  @spec migration_warnings(String.t(), ExJsonschema.Draft.draft(), ExJsonschema.Draft.draft()) :: [String.t()]
  def migration_warnings(schema_json, from_draft, to_draft)
end
```

## Implementation Plan

### Phase 1: Draft Detection and Support
1. Implement draft detection from `$schema` keyword
2. Create draft-specific compilation paths in Rust
3. Add draft information to compiled validators
4. Implement `ExJsonschema.Draft` module

### Phase 2: Meta-validation
1. Access meta-schemas from Rust crate
2. Implement schema validation against meta-schemas
3. Add meta-validation option to compilation
4. Create `ExJsonschema.Meta` module

### Phase 3: Draft-specific Features
1. Document draft-specific keyword support
2. Implement draft-specific compilation shortcuts
3. Add feature detection per draft
4. Handle draft-specific validation differences

### Phase 4: Migration Utilities (Advanced)
1. Research feasibility of schema migration
2. Implement basic migration patterns
3. Add migration validation and warnings
4. Create migration documentation and examples

## Rust Integration Points
- Use `jsonschema::Draft` enum for draft specification
- Access `jsonschema::meta` module for meta-schemas
- Leverage draft-specific modules (`jsonschema::draft7`, etc.)
- Use `jsonschema::validate_against_meta_schema()`

## API Examples

### Schema Meta-validation
```elixir
schema = ~s({
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "properties": {
    "name": {"type": "string"}
  }
})

# Validate the schema itself
:ok = ExJsonschema.Meta.validate_schema(schema)

# Detect draft version
{:ok, :draft202012} = ExJsonschema.Draft.detect(schema)

# Get supported features
features = ExJsonschema.Draft.features(:draft202012)
# [:unevaluatedProperties, :prefixItems, :contains, :const, ...]
```

### Draft-specific Compilation
```elixir
# OpenAPI 3.0 uses draft-7 subset
openapi_schema = load_openapi_schema()
{:ok, validator} = ExJsonschema.compile_draft7(openapi_schema, 
  validate_formats: true,
  validate_schema: true
)

# Modern API using draft 2020-12
modern_schema = load_modern_schema()  
{:ok, validator} = ExJsonschema.compile_draft202012(modern_schema,
  resolve_external_refs: true,
  base_uri: "https://schemas.example.com/"
)
```

### Migration Scenarios
```elixir
# Check if old schema can be migrated
old_schema = load_draft4_schema()
can_migrate = ExJsonschema.Migration.can_migrate?(old_schema, :draft4, :draft202012)

# Perform migration with warnings
{:ok, new_schema} = ExJsonschema.Migration.migrate_schema(old_schema, :draft4, :draft202012)
warnings = ExJsonschema.Migration.migration_warnings(old_schema, :draft4, :draft202012)
```

## Use Cases

### API Gateway Validation
- Support both legacy (draft-4) and modern (draft-2020-12) schemas
- Meta-validate incoming schema definitions
- Provide migration paths for legacy schemas

### Configuration Management
- Validate configuration schemas before deployment
- Support organization-wide schema draft standards
- Provide clear error messages for draft incompatibilities

### Schema Development Workflow
- Validate schemas during development
- Support draft-specific testing
- Enable schema evolution and migration

## Backward Compatibility
- Current auto-detection behavior remains default
- No breaking changes to existing APIs
- Additional draft information available but optional
- Meta-validation is opt-in only