import Config

# Production configuration for ExJsonschema
#
# This configuration focuses on essential logging only, optimizing for performance
# and reducing log volume in production environments. Only warnings and errors
# are logged by default.

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :error_count, :format]

# Set log level to warning to reduce log volume in production
# This captures only important warnings and errors
config :logger, level: :warning

# ExJsonschema-specific production logging configuration
config :ex_jsonschema,
  # Only log warnings and errors in production
  log_level: :warning,
  # Disable performance metric logging for better performance
  log_compilation_time: false,
  # Disable validation performance logging
  log_validation_time: false,
  # Reduce error detail logging to essential information only
  log_error_details: false

# Optional: Uncomment to completely disable ExJsonschema library logging in production
# if you prefer to only rely on application-level logging
# config :logger, compile_time_purge_matching: [
#   [application: :ex_jsonschema]
# ]
