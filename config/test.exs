import Config

# Completely disable logger backends during tests to suppress all output
config :logger, backends: []
