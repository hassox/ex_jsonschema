use rustler::{Atom, Encoder, Env, ResourceArc, Term};
use serde_json::Value;
use std::panic::AssertUnwindSafe;
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

rustler::init!("Elixir.ExJsonschema.Native");
