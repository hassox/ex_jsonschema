use rustler::{Atom, Encoder, Env, ResourceArc, Term};
use serde_json::{json, Value};
use std::collections::HashMap;
use std::panic::AssertUnwindSafe;
use std::sync::{Arc, Mutex};
use thiserror::Error;

mod atoms {
    rustler::atoms! {
        ok,
        error,
        nil,
        // Error types
        compilation_error,
        validation_error,
        json_parse_error,
        // Draft versions
        auto,
        draft4,
        draft6,
        draft7,
        draft201909,
        draft202012,
        // Regex engines
        fancy_regex,
        regex,
        // Additional atoms for validation options
        true_atom = "true",
        false_atom = "false",
        type_ = "type",
        message = "message",
        // External schema resolution modes
        ignore,
        http,
    }
}

#[derive(Error, Debug)]
pub enum JsonSchemaError {
    #[error("JSON parsing error: {0}")]
    JsonParseError(#[from] serde_json::Error),
    #[error("Schema compilation error: {0}")]
    CompilationError(String),
    #[error("Validation error")]
    ValidationError(Vec<ValidationErrorDetail>),
}

#[derive(Debug, Clone)]
pub struct ValidationErrorDetail {
    pub instance_path: String,
    pub schema_path: String,
    pub message: String,
}

#[derive(Debug, Clone)]
pub struct VerboseValidationErrorDetail {
    pub instance_path: String,
    pub schema_path: String,
    pub message: String,
    pub keyword: String,
    pub instance_value: Value,
    pub schema_value: Value,
    pub context: HashMap<String, Value>,
    pub annotations: HashMap<String, Value>,
    pub suggestions: Vec<String>,
}

#[derive(rustler::NifStruct)]
#[module = "ExJsonschema.Native.ValidationOptions"]
pub struct ValidationOptionsStruct {
    pub draft: Atom,
    pub validate_formats: bool,
    pub regex_engine: Atom,
    pub external_schemas_mode: Atom,
}

pub struct CompiledSchema {
    validator: AssertUnwindSafe<jsonschema::Validator>,
    schema: Value,
}

// -- External schema retrievers --

/// Returns a permissive empty schema for every URI, effectively ignoring all
/// external `$ref`s.  The empty object `{}` is a valid JSON Schema that
/// accepts any value.
struct IgnoreRetriever;

impl jsonschema::Retrieve for IgnoreRetriever {
    fn retrieve(
        &self,
        _uri: &jsonschema::Uri<String>,
    ) -> Result<Value, Box<dyn std::error::Error + Send + Sync>> {
        Ok(json!({}))
    }
}

/// Looks up pre-resolved schemas by URI string.  Falls back to a permissive
/// empty schema when the URI is not in the map, recording the URI in
/// `missing` so a caller can resolve it and build again.
struct PreloadedRetriever {
    schemas: HashMap<String, Value>,
    missing: Arc<Mutex<Vec<String>>>,
}

impl PreloadedRetriever {
    fn new(schemas: HashMap<String, Value>) -> Self {
        PreloadedRetriever {
            schemas,
            missing: Arc::new(Mutex::new(Vec::new())),
        }
    }
}

impl jsonschema::Retrieve for PreloadedRetriever {
    fn retrieve(
        &self,
        uri: &jsonschema::Uri<String>,
    ) -> Result<Value, Box<dyn std::error::Error + Send + Sync>> {
        let uri_str = uri.to_string();
        match self.schemas.get(&uri_str) {
            Some(schema) => Ok(schema.clone()),
            None => {
                if let Ok(mut missing) = self.missing.lock() {
                    missing.push(uri_str);
                }
                Ok(json!({}))
            }
        }
    }
}

/// Builder configured from the Elixir options: draft, format validation and
/// regex engine, seeded with every bundled JSON Schema meta-schema (draft 4
/// through 2020-12).  The `referencing` crawler never retrieves
/// `json-schema.org` meta-schema refs and on its own only injects the
/// meta-schemas for the document's draft, so without this baseline a 2020-12
/// schema that `$ref`s the draft-07 meta-schema fails to compile.
fn configured_options(options: &ValidationOptionsStruct) -> jsonschema::ValidationOptions {
    let mut builder = jsonschema::options().with_registry(referencing::SPECIFICATIONS.clone());

    if options.draft != atoms::auto() {
        builder = if options.draft == atoms::draft4() {
            builder.with_draft(jsonschema::Draft::Draft4)
        } else if options.draft == atoms::draft6() {
            builder.with_draft(jsonschema::Draft::Draft6)
        } else if options.draft == atoms::draft7() {
            builder.with_draft(jsonschema::Draft::Draft7)
        } else if options.draft == atoms::draft201909() {
            builder.with_draft(jsonschema::Draft::Draft201909)
        } else if options.draft == atoms::draft202012() {
            builder.with_draft(jsonschema::Draft::Draft202012)
        } else {
            builder // Unknown draft, use default
        };
    }

    if options.validate_formats {
        builder = builder.should_validate_formats(true);
    }

    if options.regex_engine == atoms::regex() {
        // Use safer regex engine
        builder.with_pattern_options(jsonschema::PatternOptions::regex())
    } else {
        // Use fancy_regex with security limits
        builder
            .with_pattern_options(jsonschema::PatternOptions::fancy_regex().backtrack_limit(10_000))
    }
}

impl CompiledSchema {
    fn new(schema: Value) -> Result<Self, JsonSchemaError> {
        let validator = jsonschema::validator_for(&schema)
            .map_err(|e| JsonSchemaError::CompilationError(e.to_string()))?;

        Ok(CompiledSchema {
            validator: AssertUnwindSafe(validator),
            schema: schema.clone(),
        })
    }

    fn new_with_draft(schema: Value, draft: Atom) -> Result<Self, JsonSchemaError> {
        let validator = if draft == atoms::draft4() {
            jsonschema::draft4::new(&schema)
                .map_err(|e| JsonSchemaError::CompilationError(e.to_string()))?
        } else if draft == atoms::draft6() {
            jsonschema::draft6::new(&schema)
                .map_err(|e| JsonSchemaError::CompilationError(e.to_string()))?
        } else if draft == atoms::draft7() {
            jsonschema::draft7::new(&schema)
                .map_err(|e| JsonSchemaError::CompilationError(e.to_string()))?
        } else if draft == atoms::draft201909() {
            jsonschema::draft201909::new(&schema)
                .map_err(|e| JsonSchemaError::CompilationError(e.to_string()))?
        } else if draft == atoms::draft202012() {
            jsonschema::draft202012::new(&schema)
                .map_err(|e| JsonSchemaError::CompilationError(e.to_string()))?
        } else {
            // Default to generic validator for unknown drafts
            jsonschema::validator_for(&schema)
                .map_err(|e| JsonSchemaError::CompilationError(e.to_string()))?
        };

        Ok(CompiledSchema {
            validator: AssertUnwindSafe(validator),
            schema: schema.clone(),
        })
    }

    fn new_with_options(
        schema: Value,
        options: ValidationOptionsStruct,
    ) -> Result<Self, JsonSchemaError> {
        let mut builder = configured_options(&options);

        // Apply external schema retriever based on mode
        if options.external_schemas_mode == atoms::ignore() {
            builder = builder.with_retriever(IgnoreRetriever);
        }
        // :http mode uses the crate's default HTTP fetching (no custom retriever)

        // Build the validator
        let validator = builder
            .build(&schema)
            .map_err(|e| JsonSchemaError::CompilationError(e.to_string()))?;

        Ok(CompiledSchema {
            validator: AssertUnwindSafe(validator),
            schema: schema.clone(),
        })
    }

    fn new_with_resolved_schemas(
        schema: Value,
        options: ValidationOptionsStruct,
        resolved_schemas: HashMap<String, Value>,
    ) -> Result<Self, JsonSchemaError> {
        let validator = configured_options(&options)
            .with_retriever(PreloadedRetriever::new(resolved_schemas))
            .build(&schema)
            .map_err(|e| JsonSchemaError::CompilationError(e.to_string()))?;

        Ok(CompiledSchema {
            validator: AssertUnwindSafe(validator),
            schema: schema.clone(),
        })
    }

    fn validate(&self, instance: &Value) -> Result<(), JsonSchemaError> {
        if self.validator.is_valid(instance) {
            Ok(())
        } else {
            let error_details: Vec<ValidationErrorDetail> = self
                .validator
                .iter_errors(instance)
                .map(|error| ValidationErrorDetail {
                    instance_path: error.instance_path().to_string(),
                    schema_path: error.schema_path().to_string(),
                    message: error.to_string(),
                })
                .collect();

            Err(JsonSchemaError::ValidationError(error_details))
        }
    }

    fn validate_verbose(&self, instance: &Value) -> Result<(), Vec<VerboseValidationErrorDetail>> {
        if self.validator.is_valid(instance) {
            Ok(())
        } else {
            let verbose_errors: Vec<VerboseValidationErrorDetail> = self
                .validator
                .iter_errors(instance)
                .map(|error| {
                    let keyword = extract_keyword_from_error(&error);
                    let (instance_value, schema_value) =
                        extract_values_from_error(&error, instance, &self.schema);
                    let context =
                        build_error_context(&error, &instance_value, &schema_value, &keyword);
                    let annotations = extract_annotations_from_error(&error, &self.schema);
                    let suggestions = generate_suggestions_for_error(
                        &error,
                        &keyword,
                        &instance_value,
                        &schema_value,
                    );

                    VerboseValidationErrorDetail {
                        instance_path: error.instance_path().to_string(),
                        schema_path: error.schema_path().to_string(),
                        message: error.to_string(),
                        keyword,
                        instance_value,
                        schema_value,
                        context,
                        annotations,
                        suggestions,
                    }
                })
                .collect();

            Err(verbose_errors)
        }
    }

    fn is_valid(&self, instance: &Value) -> bool {
        self.validator.is_valid(instance)
    }
}

// Resource type for compiled schemas
#[rustler::resource_impl]
impl rustler::Resource for CompiledSchema {}

#[rustler::nif]
fn compile_schema(env: Env, schema_json: String) -> Term {
    let schema_value: Value = match serde_json::from_str(&schema_json) {
        Ok(value) => value,
        Err(e) => {
            let error_map = rustler::types::map::map_new(env)
                .map_put("type".encode(env), "json_parse_error".encode(env))
                .unwrap()
                .map_put(
                    "message".encode(env),
                    format!("Invalid JSON: {}", e).encode(env),
                )
                .unwrap()
                .map_put(
                    "details".encode(env),
                    format!(
                        "Failed to parse JSON at line {}, column {}",
                        e.line(),
                        e.column()
                    )
                    .encode(env),
                )
                .unwrap();
            return (atoms::error(), error_map).encode(env);
        }
    };

    let compiled = match CompiledSchema::new(schema_value) {
        Ok(compiled) => compiled,
        Err(JsonSchemaError::CompilationError(msg)) => {
            let error_map = rustler::types::map::map_new(env)
                .map_put("type".encode(env), "compilation_error".encode(env))
                .unwrap()
                .map_put(
                    "message".encode(env),
                    "Schema compilation failed".encode(env),
                )
                .unwrap()
                .map_put("details".encode(env), msg.encode(env))
                .unwrap();
            return (atoms::error(), error_map).encode(env);
        }
        Err(e) => {
            let error_map = rustler::types::map::map_new(env)
                .map_put("type".encode(env), "compilation_error".encode(env))
                .unwrap()
                .map_put(
                    "message".encode(env),
                    "Unknown compilation error".encode(env),
                )
                .unwrap()
                .map_put("details".encode(env), format!("{}", e).encode(env))
                .unwrap();
            return (atoms::error(), error_map).encode(env);
        }
    };

    let resource = ResourceArc::new(compiled);
    (atoms::ok(), resource).encode(env)
}

#[rustler::nif]
fn compile_schema_with_draft(env: Env, schema_json: String, draft: Atom) -> Term {
    let schema_value: Value = match serde_json::from_str(&schema_json) {
        Ok(value) => value,
        Err(e) => {
            let error_map = rustler::types::map::map_new(env)
                .map_put("type".encode(env), "json_parse_error".encode(env))
                .unwrap()
                .map_put(
                    "message".encode(env),
                    format!("Invalid JSON: {}", e).encode(env),
                )
                .unwrap()
                .map_put(
                    "details".encode(env),
                    format!(
                        "Failed to parse JSON at line {}, column {}",
                        e.line(),
                        e.column()
                    )
                    .encode(env),
                )
                .unwrap();
            return (atoms::error(), error_map).encode(env);
        }
    };

    let compiled = match CompiledSchema::new_with_draft(schema_value, draft) {
        Ok(compiled) => compiled,
        Err(JsonSchemaError::CompilationError(msg)) => {
            let error_map = rustler::types::map::map_new(env)
                .map_put("type".encode(env), "compilation_error".encode(env))
                .unwrap()
                .map_put(
                    "message".encode(env),
                    "Schema compilation failed".encode(env),
                )
                .unwrap()
                .map_put("details".encode(env), msg.encode(env))
                .unwrap();
            return (atoms::error(), error_map).encode(env);
        }
        Err(e) => {
            let error_map = rustler::types::map::map_new(env)
                .map_put("type".encode(env), "compilation_error".encode(env))
                .unwrap()
                .map_put(
                    "message".encode(env),
                    "Unknown compilation error".encode(env),
                )
                .unwrap()
                .map_put("details".encode(env), format!("{}", e).encode(env))
                .unwrap();
            return (atoms::error(), error_map).encode(env);
        }
    };

    let resource = ResourceArc::new(compiled);
    (atoms::ok(), resource).encode(env)
}

#[rustler::nif]
fn validate(compiled_schema: ResourceArc<CompiledSchema>, instance_json: String) -> Atom {
    let instance_value: Value = match serde_json::from_str(&instance_json) {
        Ok(value) => value,
        Err(_) => return atoms::error(),
    };

    match compiled_schema.validate(&instance_value) {
        Ok(_) => atoms::ok(),
        Err(_) => atoms::error(),
    }
}

#[rustler::nif]
fn validate_detailed(
    env: Env,
    compiled_schema: ResourceArc<CompiledSchema>,
    instance_json: String,
) -> Term {
    let instance_value: Value = match serde_json::from_str(&instance_json) {
        Ok(value) => value,
        Err(_) => return (atoms::error(), atoms::json_parse_error()).encode(env),
    };

    match compiled_schema.validate(&instance_value) {
        Ok(_) => atoms::ok().encode(env),
        Err(JsonSchemaError::ValidationError(errors)) => {
            let error_terms: Vec<Term> = errors
                .iter()
                .map(|error| {
                    let error_map = rustler::types::map::map_new(env)
                        .map_put("instance_path".encode(env), error.instance_path.encode(env))
                        .unwrap()
                        .map_put("schema_path".encode(env), error.schema_path.encode(env))
                        .unwrap()
                        .map_put("message".encode(env), error.message.encode(env))
                        .unwrap();
                    error_map
                })
                .collect();

            (atoms::error(), error_terms).encode(env)
        }
        Err(_) => (atoms::error(), atoms::validation_error()).encode(env),
    }
}

#[rustler::nif]
fn valid(compiled_schema: ResourceArc<CompiledSchema>, instance_json: String) -> bool {
    let instance_value: Value = serde_json::from_str(&instance_json).unwrap_or(Value::Null);

    compiled_schema.is_valid(&instance_value)
}

#[rustler::nif]
fn detect_draft_from_schema(env: Env, schema_json: String) -> Term {
    let schema_value: Value = match serde_json::from_str(&schema_json) {
        Ok(value) => value,
        Err(e) => {
            let error_map = rustler::types::map::map_new(env)
                .map_put("type".encode(env), "json_parse_error".encode(env))
                .unwrap()
                .map_put("message".encode(env), "Invalid JSON".encode(env))
                .unwrap()
                .map_put(
                    "details".encode(env),
                    format!("Failed to parse JSON: {}", e).encode(env),
                )
                .unwrap();
            return (atoms::error(), error_map).encode(env);
        }
    };

    // Try to detect draft from $schema property
    if let Some(schema_url) = schema_value.get("$schema") {
        if let Some(url_str) = schema_url.as_str() {
            let draft = match url_str {
                url if url.contains("draft-04") || url.contains("draft/04") => atoms::draft4(),
                url if url.contains("draft-06") || url.contains("draft/06") => atoms::draft6(),
                url if url.contains("draft-07") || url.contains("draft/07") => atoms::draft7(),
                url if url.contains("2019-09") => atoms::draft201909(),
                url if url.contains("2020-12") => atoms::draft202012(),
                _ => atoms::draft202012(), // Default to latest
            };
            return (atoms::ok(), draft).encode(env);
        }
    }

    // Default to latest draft if no $schema or unrecognized
    (atoms::ok(), atoms::draft202012()).encode(env)
}

#[rustler::nif]
fn validate_verbose(
    env: Env,
    compiled_schema: ResourceArc<CompiledSchema>,
    instance_json: String,
) -> Term {
    let instance_value: Value = match serde_json::from_str(&instance_json) {
        Ok(value) => value,
        Err(_) => return (atoms::error(), atoms::json_parse_error()).encode(env),
    };

    match compiled_schema.validate_verbose(&instance_value) {
        Ok(_) => atoms::ok().encode(env),
        Err(verbose_errors) => {
            let error_terms: Vec<Term> = verbose_errors
                .iter()
                .map(|error| {
                    // Convert HashMap<String, Value> to Elixir map
                    let mut context_map = rustler::types::map::map_new(env);
                    for (key, value) in &error.context {
                        context_map = context_map
                            .map_put(key.encode(env), encode_json_value(env, value))
                            .unwrap();
                    }

                    let mut annotations_map = rustler::types::map::map_new(env);
                    for (key, value) in &error.annotations {
                        annotations_map = annotations_map
                            .map_put(key.encode(env), encode_json_value(env, value))
                            .unwrap();
                    }

                    let suggestions_list: Vec<Term> =
                        error.suggestions.iter().map(|s| s.encode(env)).collect();

                    let error_map = rustler::types::map::map_new(env)
                        .map_put("instance_path".encode(env), error.instance_path.encode(env))
                        .unwrap()
                        .map_put("schema_path".encode(env), error.schema_path.encode(env))
                        .unwrap()
                        .map_put("message".encode(env), error.message.encode(env))
                        .unwrap()
                        .map_put("keyword".encode(env), error.keyword.encode(env))
                        .unwrap()
                        .map_put(
                            "instance_value".encode(env),
                            encode_json_value(env, &error.instance_value),
                        )
                        .unwrap()
                        .map_put(
                            "schema_value".encode(env),
                            encode_json_value(env, &error.schema_value),
                        )
                        .unwrap()
                        .map_put("context".encode(env), context_map)
                        .unwrap()
                        .map_put("annotations".encode(env), annotations_map)
                        .unwrap()
                        .map_put("suggestions".encode(env), suggestions_list)
                        .unwrap();
                    error_map
                })
                .collect();

            (atoms::error(), error_terms).encode(env)
        }
    }
}

// Helper function to encode serde_json::Value to Rustler Term
fn encode_json_value<'a>(env: Env<'a>, value: &Value) -> Term<'a> {
    match value {
        Value::Null => atoms::nil().encode(env),
        Value::Bool(b) => b.encode(env),
        Value::Number(n) => {
            if let Some(i) = n.as_i64() {
                i.encode(env)
            } else if let Some(f) = n.as_f64() {
                f.encode(env)
            } else {
                atoms::nil().encode(env)
            }
        }
        Value::String(s) => s.encode(env),
        Value::Array(arr) => {
            let terms: Vec<Term> = arr.iter().map(|v| encode_json_value(env, v)).collect();
            terms.encode(env)
        }
        Value::Object(obj) => {
            let mut map = rustler::types::map::map_new(env);
            for (key, val) in obj {
                map = map
                    .map_put(key.encode(env), encode_json_value(env, val))
                    .unwrap();
            }
            map
        }
    }
}

// Helper functions for verbose error enhancement

fn extract_keyword_from_error(error: &jsonschema::ValidationError) -> String {
    error.kind().keyword().to_string()
}

fn extract_values_from_error(
    error: &jsonschema::ValidationError,
    _instance: &Value,
    _schema: &Value,
) -> (Value, Value) {
    // Instance value: directly from the error (no more tree navigation)
    let instance_value = error.instance().as_ref().clone();

    // Schema/constraint value: extracted from the structured error kind
    let schema_value = extract_constraint_from_kind(error.kind());

    (instance_value, schema_value)
}

/// Extracts the constraint value from a `ValidationErrorKind` variant.
///
/// Each variant carries its own structured data (limits, patterns, expected
/// values, etc.) so we no longer need to navigate the raw schema JSON tree.
fn extract_constraint_from_kind(kind: &jsonschema::error::ValidationErrorKind) -> Value {
    use jsonschema::error::ValidationErrorKind::*;
    match kind {
        Minimum { limit }
        | Maximum { limit }
        | ExclusiveMinimum { limit }
        | ExclusiveMaximum { limit } => limit.clone(),

        MinLength { limit } | MaxLength { limit } => json!(limit),
        MinItems { limit } | MaxItems { limit } => json!(limit),
        MinProperties { limit } | MaxProperties { limit } => json!(limit),
        AdditionalItems { limit } => json!(limit),

        MultipleOf { multiple_of } => json!(multiple_of),

        Enum { options } => options.clone(),
        Constant { expected_value } => expected_value.clone(),
        Pattern { pattern } => json!(pattern),
        Format { format } => json!(format),
        Required { property } => property.clone(),
        Not { schema } => schema.clone(),

        Type { kind: type_kind } => match type_kind {
            jsonschema::error::TypeKind::Single(t) => Value::String(t.to_string()),
            jsonschema::error::TypeKind::Multiple(ts) => {
                let types: Vec<Value> = ts.iter().map(|t| Value::String(t.to_string())).collect();
                Value::Array(types)
            }
        },

        AdditionalProperties { unexpected }
        | UnevaluatedProperties { unexpected }
        | UnevaluatedItems { unexpected } => json!(unexpected),

        _ => Value::Null,
    }
}

fn get_value_at_path(value: &Value, path: &str) -> Option<Value> {
    if path.is_empty() || path == "/" {
        return Some(value.clone());
    }

    let segments: Vec<&str> = path.trim_start_matches('/').split('/').collect();
    let mut current = value;

    for segment in segments {
        match current {
            Value::Object(obj) => {
                current = obj.get(segment)?;
            }
            Value::Array(arr) => {
                if let Ok(index) = segment.parse::<usize>() {
                    current = arr.get(index)?;
                } else {
                    return None;
                }
            }
            _ => return None,
        }
    }

    Some(current.clone())
}

fn build_error_context(
    error: &jsonschema::ValidationError,
    instance_value: &Value,
    schema_value: &Value,
    keyword: &str,
) -> HashMap<String, Value> {
    let mut context = HashMap::new();

    // Add instance path and schema path for reference
    context.insert(
        "instance_path".to_string(),
        Value::String(error.instance_path().to_string()),
    );
    context.insert(
        "schema_path".to_string(),
        Value::String(error.schema_path().to_string()),
    );

    // Add expected and actual values based on error type
    match keyword {
        "type" => {
            context.insert("expected_type".to_string(), schema_value.clone());
            context.insert(
                "actual_type".to_string(),
                Value::String(
                    match instance_value {
                        Value::String(_) => "string",
                        Value::Number(_) => "number",
                        Value::Bool(_) => "boolean",
                        Value::Array(_) => "array",
                        Value::Object(_) => "object",
                        Value::Null => "null",
                    }
                    .to_string(),
                ),
            );
            context.insert(
                "expected".to_string(),
                Value::String(format!("type: {}", schema_value)),
            );
            context.insert("actual".to_string(), instance_value.clone());
        }
        "minimum" => {
            context.insert("minimum_value".to_string(), schema_value.clone());
            context.insert("actual_value".to_string(), instance_value.clone());
            context.insert(
                "expected".to_string(),
                Value::String(format!("value >= {}", schema_value)),
            );
            context.insert("actual".to_string(), instance_value.clone());
        }
        "maximum" => {
            context.insert("maximum_value".to_string(), schema_value.clone());
            context.insert("actual_value".to_string(), instance_value.clone());
            context.insert(
                "expected".to_string(),
                Value::String(format!("value <= {}", schema_value)),
            );
            context.insert("actual".to_string(), instance_value.clone());
        }
        "minLength" => {
            let actual_length = if let Value::String(s) = instance_value {
                s.len()
            } else {
                0
            };
            context.insert("minimum_length".to_string(), schema_value.clone());
            context.insert(
                "actual_length".to_string(),
                Value::Number(actual_length.into()),
            );
            context.insert(
                "expected".to_string(),
                Value::String(format!("length >= {}", schema_value)),
            );
            context.insert(
                "actual".to_string(),
                Value::String(format!("length: {}", actual_length)),
            );
        }
        "maxLength" => {
            let actual_length = if let Value::String(s) = instance_value {
                s.len()
            } else {
                0
            };
            context.insert("maximum_length".to_string(), schema_value.clone());
            context.insert(
                "actual_length".to_string(),
                Value::Number(actual_length.into()),
            );
            context.insert(
                "expected".to_string(),
                Value::String(format!("length <= {}", schema_value)),
            );
            context.insert(
                "actual".to_string(),
                Value::String(format!("length: {}", actual_length)),
            );
        }
        "pattern" => {
            context.insert("pattern".to_string(), schema_value.clone());
            context.insert("value".to_string(), instance_value.clone());
            context.insert(
                "expected".to_string(),
                Value::String(format!("match pattern: {}", schema_value)),
            );
            context.insert("actual".to_string(), instance_value.clone());
        }
        "required" => {
            context.insert("required_properties".to_string(), schema_value.clone());
            context.insert(
                "expected".to_string(),
                Value::String("all required properties present".to_string()),
            );
            context.insert(
                "actual".to_string(),
                Value::String("missing required property".to_string()),
            );
        }
        "minItems" | "maxItems" => {
            let actual_length = if let Value::Array(arr) = instance_value {
                arr.len()
            } else {
                0
            };
            context.insert(
                format!(
                    "{}_items",
                    if keyword == "minItems" {
                        "minimum"
                    } else {
                        "maximum"
                    }
                )
                .to_string(),
                schema_value.clone(),
            );
            context.insert(
                "actual_items".to_string(),
                Value::Number(actual_length.into()),
            );
            let op = if keyword == "minItems" { ">=" } else { "<=" };
            context.insert(
                "expected".to_string(),
                Value::String(format!("items {} {}", op, schema_value)),
            );
            context.insert("actual".to_string(), instance_value.clone()); // Use actual array value
        }
        _ => {
            context.insert("constraint".to_string(), schema_value.clone());
            context.insert(
                "expected".to_string(),
                Value::String("constraint satisfied".to_string()),
            );
            context.insert("actual".to_string(), instance_value.clone());
        }
    }

    context
}

fn extract_annotations_from_error(
    error: &jsonschema::ValidationError,
    schema: &Value,
) -> HashMap<String, Value> {
    let mut annotations = HashMap::new();

    // Get the schema location where the error occurred
    let schema_path = error.schema_path().to_string();
    if let Some(Value::Object(schema_obj)) = get_value_at_path(schema, &schema_path) {
        // Extract common annotations that might be present
        // Add title annotation if present
        if let Some(title) = schema_obj.get("title") {
            annotations.insert("title".to_string(), title.clone());
        }

        // Add description annotation if present
        if let Some(description) = schema_obj.get("description") {
            annotations.insert("description".to_string(), description.clone());
        }

        // Add examples if present
        if let Some(examples) = schema_obj.get("examples") {
            annotations.insert("examples".to_string(), examples.clone());
        }

        // Add default value if present
        if let Some(default) = schema_obj.get("default") {
            annotations.insert("default".to_string(), default.clone());
        }
    }

    // For parent schema annotations, check one level up
    let parent_path = schema_path.rsplit_once('/').map(|x| x.0).unwrap_or("");
    if !parent_path.is_empty() {
        if let Some(Value::Object(parent_obj)) = get_value_at_path(schema, parent_path) {
            // Add parent title/description with "parent_" prefix
            if let Some(parent_title) = parent_obj.get("title") {
                annotations.insert("parent_title".to_string(), parent_title.clone());
            }
            if let Some(parent_description) = parent_obj.get("description") {
                annotations.insert("parent_description".to_string(), parent_description.clone());
            }
        }
    }

    // Add error location metadata
    annotations.insert(
        "error_keyword".to_string(),
        Value::String(extract_keyword_from_error(error)),
    );
    annotations.insert(
        "validation_failed_at".to_string(),
        Value::String(error.instance_path().to_string()),
    );

    annotations
}

fn generate_suggestions_for_error(
    error: &jsonschema::ValidationError,
    keyword: &str,
    _instance_value: &Value,
    schema_value: &Value,
) -> Vec<String> {
    match keyword {
        "type" => {
            let expected = schema_value.as_str().unwrap_or("unknown");
            vec![format!("Expected type: {}", expected)]
        }
        "minimum" => vec![format!("Value must be >= {}", schema_value)],
        "maximum" => vec![format!("Value must be <= {}", schema_value)],
        "minLength" => vec![format!(
            "String must be at least {} characters",
            schema_value
        )],
        "maxLength" => vec![format!(
            "String must be at most {} characters",
            schema_value
        )],
        "pattern" => vec![format!("String must match pattern: {}", schema_value)],
        "format" => {
            let message = error.to_string();
            if message.contains("email") {
                vec!["Use valid email format: user@domain.com".to_string()]
            } else {
                vec!["Check the format requirements".to_string()]
            }
        }
        "required" => vec!["Add the missing required property".to_string()],
        "minItems" => vec![format!("Array must have at least {} items", schema_value)],
        "maxItems" => vec![format!("Array must have at most {} items", schema_value)],
        "enum" => vec![format!("Value must be one of: {}", schema_value)],
        "const" => vec![format!("Value must be exactly: {}", schema_value)],
        "uniqueItems" => vec!["Array items must be unique".to_string()],
        "multipleOf" => vec![format!("Value must be a multiple of {}", schema_value)],
        _ => {
            // Provide helpful default suggestions for unhandled keywords
            let mut suggestions = vec![
                format!("Validation failed for '{}' constraint", keyword),
                format!("Expected: {}", schema_value),
            ];

            // Add generic troubleshooting advice
            suggestions.push("Check the schema documentation for this constraint".to_string());
            suggestions.push("Verify your data matches the expected format".to_string());

            // If we can extract useful info from the error message, add it
            let message = error.to_string();
            if !message.is_empty() && message.len() < 200 {
                suggestions.push(format!("Error details: {}", message));
            }

            suggestions
        }
    }
}

// Meta-validation functions
#[rustler::nif]
fn meta_is_valid(env: Env, schema_json: String) -> Term {
    let schema_value: Value = match serde_json::from_str(&schema_json) {
        Ok(value) => value,
        Err(e) => {
            let error_map = rustler::types::map::map_new(env)
                .map_put("type".encode(env), "json_parse_error".encode(env))
                .unwrap()
                .map_put("message".encode(env), "Invalid JSON".encode(env))
                .unwrap()
                .map_put(
                    "details".encode(env),
                    format!("Failed to parse JSON: {}", e).encode(env),
                )
                .unwrap();
            return (atoms::error(), error_map).encode(env);
        }
    };

    // Use jsonschema::meta::is_valid to check if schema is valid
    // Handle potential panic with catch_unwind
    let result = std::panic::catch_unwind(|| jsonschema::meta::is_valid(&schema_value));

    match result {
        Ok(is_valid) => (atoms::ok(), is_valid).encode(env),
        Err(_) => {
            // If panic occurred, assume invalid schema
            (atoms::ok(), false).encode(env)
        }
    }
}

#[rustler::nif]
fn meta_validate(env: Env, schema_json: String) -> Term {
    let schema_value: Value = match serde_json::from_str(&schema_json) {
        Ok(value) => value,
        Err(e) => {
            let error_map = rustler::types::map::map_new(env)
                .map_put("type".encode(env), "json_parse_error".encode(env))
                .unwrap()
                .map_put("message".encode(env), "Invalid JSON".encode(env))
                .unwrap()
                .map_put(
                    "details".encode(env),
                    format!("Failed to parse JSON: {}", e).encode(env),
                )
                .unwrap();
            return (atoms::error(), error_map).encode(env);
        }
    };

    // Use jsonschema::meta::validate to get detailed validation results
    // Handle potential panic with catch_unwind
    let result = std::panic::catch_unwind(|| jsonschema::meta::validate(&schema_value));

    match result {
        Ok(Ok(_)) => atoms::ok().encode(env),
        Ok(Err(error)) => {
            let error_map = rustler::types::map::map_new(env)
                .map_put("type".encode(env), "meta_validation_error".encode(env))
                .unwrap()
                .map_put(
                    "message".encode(env),
                    "Schema meta-validation failed".encode(env),
                )
                .unwrap()
                .map_put("details".encode(env), error.to_string().encode(env))
                .unwrap();
            (atoms::error(), error_map).encode(env)
        }
        Err(_) => {
            let error_map = rustler::types::map::map_new(env)
                .map_put("type".encode(env), "meta_validation_error".encode(env))
                .unwrap()
                .map_put(
                    "message".encode(env),
                    "Meta-validation not supported for this schema format".encode(env),
                )
                .unwrap()
                .map_put(
                    "details".encode(env),
                    "Unknown or unsupported $schema specification".encode(env),
                )
                .unwrap();
            (atoms::error(), error_map).encode(env)
        }
    }
}

#[rustler::nif]
fn meta_validate_detailed(env: Env, schema_json: String) -> Term {
    let schema_value: Value = match serde_json::from_str(&schema_json) {
        Ok(value) => value,
        Err(e) => {
            let error_map = rustler::types::map::map_new(env)
                .map_put("type".encode(env), "json_parse_error".encode(env))
                .unwrap()
                .map_put("message".encode(env), "Invalid JSON".encode(env))
                .unwrap()
                .map_put(
                    "details".encode(env),
                    format!("Failed to parse JSON: {}", e).encode(env),
                )
                .unwrap();
            return (atoms::error(), error_map).encode(env);
        }
    };

    // Try to compile as a validator to get detailed meta-validation errors
    let compilation_result = std::panic::catch_unwind(|| jsonschema::validator_for(&schema_value));

    match compilation_result {
        Ok(Ok(_validator)) => {
            // Schema is valid for compilation, now check meta-validation
            let meta_result =
                std::panic::catch_unwind(|| jsonschema::meta::validate(&schema_value));

            match meta_result {
                Ok(Ok(_)) => atoms::ok().encode(env),
                Ok(Err(error)) => {
                    // Create a detailed error response
                    let error_details = rustler::types::map::map_new(env)
                        .map_put("instance_path".encode(env), "".encode(env))
                        .unwrap()
                        .map_put("schema_path".encode(env), "".encode(env))
                        .unwrap()
                        .map_put("message".encode(env), error.to_string().encode(env))
                        .unwrap()
                        .map_put("keyword".encode(env), "meta".encode(env))
                        .unwrap();

                    (atoms::error(), vec![error_details]).encode(env)
                }
                Err(_) => {
                    // Meta-validation panicked (unsupported $schema)
                    let error_details = rustler::types::map::map_new(env)
                        .map_put("instance_path".encode(env), "".encode(env))
                        .unwrap()
                        .map_put("schema_path".encode(env), "".encode(env))
                        .unwrap()
                        .map_put(
                            "message".encode(env),
                            "Meta-validation not supported for this schema format".encode(env),
                        )
                        .unwrap()
                        .map_put("keyword".encode(env), "meta".encode(env))
                        .unwrap();

                    (atoms::error(), vec![error_details]).encode(env)
                }
            }
        }
        Ok(Err(compilation_error)) => {
            // Schema has compilation errors, create detailed error response
            let error_details = rustler::types::map::map_new(env)
                .map_put("instance_path".encode(env), "".encode(env))
                .unwrap()
                .map_put("schema_path".encode(env), "".encode(env))
                .unwrap()
                .map_put(
                    "message".encode(env),
                    compilation_error.to_string().encode(env),
                )
                .unwrap()
                .map_put("keyword".encode(env), "compilation".encode(env))
                .unwrap();

            (atoms::error(), vec![error_details]).encode(env)
        }
        Err(_) => {
            // Compilation panicked
            let error_details = rustler::types::map::map_new(env)
                .map_put("instance_path".encode(env), "".encode(env))
                .unwrap()
                .map_put("schema_path".encode(env), "".encode(env))
                .unwrap()
                .map_put(
                    "message".encode(env),
                    "Schema compilation failed due to unsupported format".encode(env),
                )
                .unwrap()
                .map_put("keyword".encode(env), "compilation".encode(env))
                .unwrap();

            (atoms::error(), vec![error_details]).encode(env)
        }
    }
}

#[rustler::nif]
fn compile_schema_with_options(
    env: Env,
    schema_json: String,
    options: ValidationOptionsStruct,
) -> Term {
    let schema_value: Value = match serde_json::from_str(&schema_json) {
        Ok(value) => value,
        Err(e) => {
            let error_map = rustler::types::map::map_new(env)
                .map_put("type".encode(env), "json_parse_error".encode(env))
                .unwrap()
                .map_put("message".encode(env), e.to_string().encode(env))
                .unwrap();
            return (atoms::error(), error_map).encode(env);
        }
    };

    let compiled = match CompiledSchema::new_with_options(schema_value, options) {
        Ok(compiled) => compiled,
        Err(e) => {
            let error_map = rustler::types::map::map_new(env)
                .map_put("type".encode(env), "compilation_error".encode(env))
                .unwrap()
                .map_put("message".encode(env), e.to_string().encode(env))
                .unwrap();
            return (atoms::error(), error_map).encode(env);
        }
    };

    let resource = ResourceArc::new(compiled);
    (atoms::ok(), resource).encode(env)
}

#[rustler::nif]
fn compile_schema_with_resolved_schemas(
    env: Env,
    schema_json: String,
    options: ValidationOptionsStruct,
    resolved_schemas: HashMap<String, String>,
) -> Term {
    let schema_value: Value = match serde_json::from_str(&schema_json) {
        Ok(value) => value,
        Err(e) => {
            let error_map = rustler::types::map::map_new(env)
                .map_put("type".encode(env), "json_parse_error".encode(env))
                .unwrap()
                .map_put("message".encode(env), e.to_string().encode(env))
                .unwrap();
            return (atoms::error(), error_map).encode(env);
        }
    };

    let parsed_schemas = match parse_resolved_schemas(resolved_schemas) {
        Ok(parsed) => parsed,
        Err(message) => {
            let error_map = rustler::types::map::map_new(env)
                .map_put("type".encode(env), "json_parse_error".encode(env))
                .unwrap()
                .map_put("message".encode(env), message.encode(env))
                .unwrap();
            return (atoms::error(), error_map).encode(env);
        }
    };

    let compiled =
        match CompiledSchema::new_with_resolved_schemas(schema_value, options, parsed_schemas) {
            Ok(compiled) => compiled,
            Err(e) => {
                let error_map = rustler::types::map::map_new(env)
                    .map_put("type".encode(env), "compilation_error".encode(env))
                    .unwrap()
                    .map_put("message".encode(env), e.to_string().encode(env))
                    .unwrap();
                return (atoms::error(), error_map).encode(env);
            }
        };

    let resource = ResourceArc::new(compiled);
    (atoms::ok(), resource).encode(env)
}

/// Parses each JSON string in a resolved-schemas map.
fn parse_resolved_schemas(
    resolved_schemas: HashMap<String, String>,
) -> Result<HashMap<String, Value>, String> {
    resolved_schemas
        .into_iter()
        .map(|(url, json_str)| {
            serde_json::from_str::<Value>(&json_str)
                .map(|value| (url.clone(), value))
                .map_err(|e| format!("Invalid JSON in resolved schema for '{}': {}", url, e))
        })
        .collect()
}

/// Builds a validator against `resolved_schemas` and returns the external
/// URIs it asked for that the map did not contain, sorted and deduplicated.
///
/// The validator resolves each `$ref` against its base URI, drops fragments,
/// only follows real subschema locations and serves the official meta-schemas
/// itself, so these are exactly the documents a later
/// `compile_schema_with_resolved_schemas/3` call needs.  Build errors are not
/// reported here; the compile reports them.
#[rustler::nif]
fn unresolved_refs(
    env: Env,
    schema_json: String,
    options: ValidationOptionsStruct,
    resolved_schemas: HashMap<String, String>,
) -> Term {
    let parsed = serde_json::from_str::<Value>(&schema_json)
        .map_err(|e| ("json_parse_error", e.to_string()))
        .and_then(|schema| {
            parse_resolved_schemas(resolved_schemas)
                .map(|resolved| (schema, resolved))
                .map_err(|message| ("json_parse_error", message))
        });

    let (schema_value, parsed_schemas) = match parsed {
        Ok(parsed) => parsed,
        Err((error_type, message)) => {
            let error_map = rustler::types::map::map_new(env)
                .map_put("type".encode(env), error_type.encode(env))
                .unwrap()
                .map_put("message".encode(env), message.encode(env))
                .unwrap();
            return (atoms::error(), error_map).encode(env);
        }
    };

    let retriever = PreloadedRetriever::new(parsed_schemas);
    let missing = Arc::clone(&retriever.missing);
    let _ = configured_options(&options)
        .with_retriever(retriever)
        .build(&schema_value);

    let mut uris = missing.lock().map(|m| m.clone()).unwrap_or_default();
    uris.sort();
    uris.dedup();
    (atoms::ok(), uris).encode(env)
}

rustler::init!("Elixir.ExJsonschema.Native");
