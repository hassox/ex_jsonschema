# Test configuration for ExJsonschema

import Config

# Recommended: Disable caching in tests for maximum reliability
# This eliminates any potential cache-related test flakiness
config :ex_jsonschema,
  cache: ExJsonschema.Cache.Noop

config :logger, level: :none

# If you need to test caching behavior specifically, use ExJsonschema.Cache.Test
# in individual test setups rather than globally
