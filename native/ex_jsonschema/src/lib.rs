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
}

impl CompiledSchema {
    fn new(schema: Value) -> Result<Self, JsonSchemaError> {
        let validator = jsonschema::validator_for(&schema)
            .map_err(|e| JsonSchemaError::CompilationError(e.to_string()))?;

        Ok(CompiledSchema {
            validator: AssertUnwindSafe(validator),
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
                    let (instance_value, schema_value) = extract_values_from_error(&error, instance);
                    let context = build_error_context(&error, &instance_value, &schema_value);
                    let annotations = extract_annotations_from_error(&error);
                    let suggestions = generate_suggestions_for_error(&error, &keyword);

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
            _ => "unknown".to_string(),
        }
    } else {
        "unknown".to_string()
    }
}

fn extract_values_from_error(error: &jsonschema::ValidationError, instance: &Value) -> (Value, Value) {
    // Get the instance value at the error path
    let instance_value = get_value_at_path(instance, &error.instance_path.to_string())
        .unwrap_or(Value::Null);
    
    // For schema value, we'd need to navigate the schema, but for now return a placeholder
    let schema_value = Value::String("schema_constraint".to_string());
    
    (instance_value, schema_value)
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
    _schema_value: &Value,
) -> HashMap<String, Value> {
    let mut context = HashMap::new();
    
    // Add expected and actual values based on error type
    let keyword = extract_keyword_from_error(error);
    match keyword.as_str() {
        "type" => {
            context.insert("expected".to_string(), Value::String("correct type".to_string()));
            context.insert("actual".to_string(), Value::String(format!("type: {}", 
                match instance_value {
                    Value::String(_) => "string",
                    Value::Number(_) => "number", 
                    Value::Bool(_) => "boolean",
                    Value::Array(_) => "array",
                    Value::Object(_) => "object",
                    Value::Null => "null",
                }
            )));
        }
        "minimum" => {
            context.insert("expected".to_string(), Value::String("value >= minimum".to_string()));
            context.insert("actual".to_string(), instance_value.clone());
        }
        "minLength" => {
            let length = if let Value::String(s) = instance_value {
                s.len()
            } else { 0 };
            context.insert("expected".to_string(), Value::String("length >= minimum".to_string()));
            context.insert("actual".to_string(), Value::String(format!("length: {}", length)));
        }
        _ => {
            context.insert("expected".to_string(), Value::String("constraint satisfied".to_string()));
            context.insert("actual".to_string(), instance_value.clone());
        }
    }
    
    context
}

fn extract_annotations_from_error(_error: &jsonschema::ValidationError) -> HashMap<String, Value> {
    // For M2.1, return empty annotations - full implementation would extract schema annotations
    HashMap::new()
}

fn generate_suggestions_for_error(error: &jsonschema::ValidationError, keyword: &str) -> Vec<String> {
    match keyword {
        "type" => vec!["Check the data type of the value".to_string()],
        "minimum" => vec!["Ensure the value meets the minimum requirement".to_string()],
        "maximum" => vec!["Ensure the value does not exceed the maximum".to_string()],
        "minLength" => vec!["Ensure the string meets the minimum length requirement".to_string()],
        "maxLength" => vec!["Ensure the string does not exceed the maximum length".to_string()],
        "pattern" => vec!["Check that the string matches the required pattern".to_string()],
        "format" => {
            let message = error.to_string();
            if message.contains("email") {
                vec!["Check email format: should contain @ and valid domain".to_string()]
            } else {
                vec!["Check the format of the value".to_string()]
            }
        }
        "required" => vec!["Add the required property to the object".to_string()],
        "minItems" => vec!["Add more items to meet the minimum requirement".to_string()],
        "maxItems" => vec!["Remove items to not exceed the maximum".to_string()],
        _ => vec![],
    }
}

rustler::init!("Elixir.ExJsonschema.Native");
