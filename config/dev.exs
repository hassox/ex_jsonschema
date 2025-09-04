import Config

# Development configuration for ExJsonschema
# 
# This configuration enables structured logging for development while maintaining
# good performance for benchmarks. Use :debug level only when detailed tracing
# is needed for debugging specific issues.

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :error_count, :schema_size, :instance_size, :format]

# Set log level to info for good balance of visibility and performance
# Change to :debug when you need detailed operation tracing
config :logger, level: :info

# ExJsonschema-specific logging configuration
config :ex_jsonschema,
  # Use info level for development (captures important operations without verbose tracing)
  log_level: :info,
  # Log compilation performance metrics
  log_compilation_time: true,
  # Log validation performance metrics  
  log_validation_time: true,
  # Include detailed error context in logs
  log_error_details: true
