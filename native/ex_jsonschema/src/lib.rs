use rustler::{Atom, Encoder, Env, ResourceArc, Term};
use serde_json::Value;
use std::panic::AssertUnwindSafe;
use std::collections::HashMap;
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

pub struct CompiledSchema {
    validator: AssertUnwindSafe<jsonschema::Validator>,
    schema: Value,
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

    fn validate(&self, instance: &Value) -> Result<(), JsonSchemaError> {
        if self.validator.is_valid(instance) {
            Ok(())
        } else {
            let error_details: Vec<ValidationErrorDetail> = self.validator
                .iter_errors(instance)
                .map(|error| ValidationErrorDetail {
                    instance_path: error.instance_path.to_string(),
                    schema_path: error.schema_path.to_string(),
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
            let verbose_errors: Vec<VerboseValidationErrorDetail> = self.validator
                .iter_errors(instance)
                .map(|error| {
                    let keyword = extract_keyword_from_error(&error);
                    let (instance_value, schema_value) = extract_values_from_error(&error, instance, &self.schema);
                    let context = build_error_context(&error, &instance_value, &schema_value, &keyword);
                    let annotations = extract_annotations_from_error(&error, &self.schema);
                    let suggestions = generate_suggestions_for_error(&error, &keyword, &instance_value, &schema_value);

                    VerboseValidationErrorDetail {
                        instance_path: error.instance_path.to_string(),
                        schema_path: error.schema_path.to_string(),
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
                .map_put("details".encode(env), format!("Failed to parse JSON: {}", e).encode(env))
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

                    let suggestions_list: Vec<Term> = error.suggestions
                        .iter()
                        .map(|s| s.encode(env))
                        .collect();

                    let error_map = rustler::types::map::map_new(env)
                        .map_put("instance_path".encode(env), error.instance_path.encode(env))
                        .unwrap()
                        .map_put("schema_path".encode(env), error.schema_path.encode(env))
                        .unwrap()
                        .map_put("message".encode(env), error.message.encode(env))
                        .unwrap()
                        .map_put("keyword".encode(env), error.keyword.encode(env))
                        .unwrap()
                        .map_put("instance_value".encode(env), encode_json_value(env, &error.instance_value))
                        .unwrap()
                        .map_put("schema_value".encode(env), encode_json_value(env, &error.schema_value))
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
    // Extract the keyword from the schema path or error kind
    let schema_path = error.schema_path.to_string();
    if let Some(last_segment) = schema_path.split('/').last() {
        match last_segment {
            "type" => "type".to_string(),
            "minimum" => "minimum".to_string(),
            "maximum" => "maximum".to_string(),
            "minLength" => "minLength".to_string(),
            "maxLength" => "maxLength".to_string(),
            "pattern" => "pattern".to_string(),
            "format" => "format".to_string(),
            "required" => "required".to_string(),
            "minItems" => "minItems".to_string(),
            "maxItems" => "maxItems".to_string(),
            "enum" => "enum".to_string(),
            "const" => "const".to_string(),
            "uniqueItems" => "uniqueItems".to_string(),
            "multipleOf" => "multipleOf".to_string(),
            _ => last_segment.to_string(), // Return the actual keyword instead of "unknown"
        }
    } else {
        "unknown".to_string()
    }
}

fn extract_values_from_error(error: &jsonschema::ValidationError, instance: &Value, schema: &Value) -> (Value, Value) {
    // Get the instance value at the error path
    let instance_value = get_value_at_path(instance, &error.instance_path.to_string())
        .unwrap_or(Value::Null);
    
    // Extract schema constraint value based on the keyword
    let schema_value = get_schema_constraint_value(error, schema);
    
    (instance_value, schema_value)
}

fn get_schema_constraint_value(error: &jsonschema::ValidationError, schema: &Value) -> Value {
    let schema_path = error.schema_path.to_string();
    let keyword = extract_keyword_from_error(error);
    
    // Navigate to the schema location where the constraint is defined
    if let Some(schema_location) = get_value_at_path(schema, &schema_path) {
        // For simple constraints, return the constraint value directly
        match keyword.as_str() {
            "minimum" | "maximum" | "minLength" | "maxLength" | "minItems" | "maxItems" | "const" | "enum" | "multipleOf" => {
                schema_location.clone()
            }
            "type" => {
                // Navigate up one level to get the type constraint
                let parent_path = schema_path.rsplitn(2, '/').nth(1).unwrap_or("");
                if let Some(parent) = get_value_at_path(schema, parent_path) {
                    if let Some(type_val) = parent.get("type") {
                        return type_val.clone();
                    }
                }
                Value::String("unknown".to_string())
            }
            "pattern" => {
                // Navigate up to get the pattern value
                let parent_path = schema_path.rsplitn(2, '/').nth(1).unwrap_or("");
                if let Some(parent) = get_value_at_path(schema, parent_path) {
                    if let Some(pattern_val) = parent.get("pattern") {
                        return pattern_val.clone();
                    }
                }
                Value::String("unknown pattern".to_string())
            }
            "required" => {
                // Get the required property list
                let parent_path = schema_path.rsplitn(2, '/').nth(1).unwrap_or("");
                if let Some(parent) = get_value_at_path(schema, parent_path) {
                    if let Some(required_val) = parent.get("required") {
                        return required_val.clone();
                    }
                }
                Value::Array(vec![])
            }
            _ => Value::String(format!("constraint: {}", keyword))
        }
    } else {
        Value::String("unknown constraint".to_string())
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
    context.insert("instance_path".to_string(), Value::String(error.instance_path.to_string()));
    context.insert("schema_path".to_string(), Value::String(error.schema_path.to_string()));
    
    // Add expected and actual values based on error type
    match keyword {
        "type" => {
            context.insert("expected_type".to_string(), schema_value.clone());
            context.insert("actual_type".to_string(), Value::String(
                match instance_value {
                    Value::String(_) => "string",
                    Value::Number(_) => "number", 
                    Value::Bool(_) => "boolean",
                    Value::Array(_) => "array",
                    Value::Object(_) => "object",
                    Value::Null => "null",
                }.to_string()
            ));
            context.insert("expected".to_string(), Value::String(format!("type: {}", schema_value)));
            context.insert("actual".to_string(), instance_value.clone());
        }
        "minimum" => {
            context.insert("minimum_value".to_string(), schema_value.clone());
            context.insert("actual_value".to_string(), instance_value.clone());
            context.insert("expected".to_string(), Value::String(format!("value >= {}", schema_value)));
            context.insert("actual".to_string(), instance_value.clone());
        }
        "maximum" => {
            context.insert("maximum_value".to_string(), schema_value.clone());
            context.insert("actual_value".to_string(), instance_value.clone());
            context.insert("expected".to_string(), Value::String(format!("value <= {}", schema_value)));
            context.insert("actual".to_string(), instance_value.clone());
        }
        "minLength" => {
            let actual_length = if let Value::String(s) = instance_value {
                s.len()
            } else { 0 };
            context.insert("minimum_length".to_string(), schema_value.clone());
            context.insert("actual_length".to_string(), Value::Number(actual_length.into()));
            context.insert("expected".to_string(), Value::String(format!("length >= {}", schema_value)));
            context.insert("actual".to_string(), Value::String(format!("length: {}", actual_length)));
        }
        "maxLength" => {
            let actual_length = if let Value::String(s) = instance_value {
                s.len()
            } else { 0 };
            context.insert("maximum_length".to_string(), schema_value.clone());
            context.insert("actual_length".to_string(), Value::Number(actual_length.into()));
            context.insert("expected".to_string(), Value::String(format!("length <= {}", schema_value)));
            context.insert("actual".to_string(), Value::String(format!("length: {}", actual_length)));
        }
        "pattern" => {
            context.insert("pattern".to_string(), schema_value.clone());
            context.insert("value".to_string(), instance_value.clone());
            context.insert("expected".to_string(), Value::String(format!("match pattern: {}", schema_value)));
            context.insert("actual".to_string(), instance_value.clone());
        }
        "required" => {
            context.insert("required_properties".to_string(), schema_value.clone());
            context.insert("expected".to_string(), Value::String("all required properties present".to_string()));
            context.insert("actual".to_string(), Value::String("missing required property".to_string()));
        }
        "minItems" | "maxItems" => {
            let actual_length = if let Value::Array(arr) = instance_value {
                arr.len()
            } else { 0 };
            context.insert(format!("{}_items", if keyword == "minItems" { "minimum" } else { "maximum" }).to_string(), schema_value.clone());
            context.insert("actual_items".to_string(), Value::Number(actual_length.into()));
            let op = if keyword == "minItems" { ">=" } else { "<=" };
            context.insert("expected".to_string(), Value::String(format!("items {} {}", op, schema_value)));
            context.insert("actual".to_string(), instance_value.clone()); // Use actual array value
        }
        _ => {
            context.insert("constraint".to_string(), schema_value.clone());
            context.insert("expected".to_string(), Value::String("constraint satisfied".to_string()));
            context.insert("actual".to_string(), instance_value.clone());
        }
    }
    
    context
}

fn extract_annotations_from_error(error: &jsonschema::ValidationError, schema: &Value) -> HashMap<String, Value> {
    let mut annotations = HashMap::new();
    
    // Get the schema location where the error occurred
    let schema_path = error.schema_path.to_string();
    if let Some(schema_location) = get_value_at_path(schema, &schema_path) {
        // Extract common annotations that might be present
        if let Value::Object(schema_obj) = schema_location {
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
    }
    
    // For parent schema annotations, check one level up
    let parent_path = schema_path.rsplitn(2, '/').nth(1).unwrap_or("");
    if !parent_path.is_empty() {
        if let Some(parent_location) = get_value_at_path(schema, parent_path) {
            if let Value::Object(parent_obj) = parent_location {
                // Add parent title/description with "parent_" prefix
                if let Some(parent_title) = parent_obj.get("title") {
                    annotations.insert("parent_title".to_string(), parent_title.clone());
                }
                if let Some(parent_description) = parent_obj.get("description") {
                    annotations.insert("parent_description".to_string(), parent_description.clone());
                }
            }
        }
    }
    
    // Add error location metadata
    annotations.insert("error_keyword".to_string(), Value::String(extract_keyword_from_error(error)));
    annotations.insert("validation_failed_at".to_string(), Value::String(error.instance_path.to_string()));
    
    annotations
}

fn generate_suggestions_for_error(
    error: &jsonschema::ValidationError, 
    keyword: &str, 
    _instance_value: &Value, 
    schema_value: &Value
) -> Vec<String> {
    match keyword {
        "type" => {
            let expected = schema_value.as_str().unwrap_or("unknown");
            vec![format!("Expected type: {}", expected)]
        }
        "minimum" => vec![format!("Value must be >= {}", schema_value)],
        "maximum" => vec![format!("Value must be <= {}", schema_value)],
        "minLength" => vec![format!("String must be at least {} characters", schema_value)],
        "maxLength" => vec![format!("String must be at most {} characters", schema_value)],
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

rustler::init!("Elixir.ExJsonschema.Native");
