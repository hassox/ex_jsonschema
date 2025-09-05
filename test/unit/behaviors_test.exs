defmodule ExJsonschema.BehaviorsTest do
  use ExUnit.Case
  doctest ExJsonschema.Cache

  describe "ExJsonschema.Cache behavior" do
    test "defines required callbacks" do
      assert_callback(ExJsonschema.Cache, :get, 1)
      assert_callback(ExJsonschema.Cache, :put, 2)
      assert_callback(ExJsonschema.Cache, :delete, 1)
      assert_callback(ExJsonschema.Cache, :clear, 0)
    end

    test "has correct type specifications" do
      # This test ensures the behavior module loads without compilation errors
      # which verifies the type specs are syntactically correct
      assert :erlang.function_exported(ExJsonschema.Cache, :behaviour_info, 1)
      assert is_list(ExJsonschema.Cache.behaviour_info(:callbacks))
    end
  end

  # Helper functions for testing behavior definitions
  defp assert_callback(behavior, function, arity) do
    callbacks = behavior.behaviour_info(:callbacks)

    assert {function, arity} in callbacks,
           "Expected #{behavior} to define callback #{function}/#{arity}"
  end
end
