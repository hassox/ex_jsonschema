ExUnit.start()

# Load test support modules
Code.require_file("support/test_helpers.ex", __DIR__)
Code.require_file("support/fixtures.ex", __DIR__)

# Configure test environment  
Application.put_env(:ex_jsonschema, :test_mode, true)

# Import test helpers globally for convenience
defmodule ExUnit.CaseHelpers do
  defmacro __using__(_) do
    quote do
      import ExJsonschema.TestHelpers
      alias ExJsonschema.TestFixtures
    end
  end
end
