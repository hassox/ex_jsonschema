defmodule ExJsonschema.BehaviorsTest do
  use ExUnit.Case
  doctest ExJsonschema.Cache
  doctest ExJsonschema.Retriever
  doctest ExJsonschema.ReferenceCache

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

  describe "ExJsonschema.Retriever behavior" do
    test "defines required callbacks" do
      assert_callback(ExJsonschema.Retriever, :retrieve, 2)
    end

    test "defines optional callbacks" do
      assert_optional_callback(ExJsonschema.Retriever, :retrieve_async, 2)
    end

    test "has correct type specifications" do
      assert :erlang.function_exported(ExJsonschema.Retriever, :behaviour_info, 1)
      assert is_list(ExJsonschema.Retriever.behaviour_info(:callbacks))
    end
  end

  describe "ExJsonschema.ReferenceCache behavior" do
    test "defines required callbacks" do
      assert_callback(ExJsonschema.ReferenceCache, :get, 2)
      assert_callback(ExJsonschema.ReferenceCache, :put, 3)
      assert_callback(ExJsonschema.ReferenceCache, :delete, 2)
    end

    test "defines optional callbacks" do
      assert_optional_callback(ExJsonschema.ReferenceCache, :clear, 1)
    end

    test "has correct type specifications" do
      assert :erlang.function_exported(ExJsonschema.ReferenceCache, :behaviour_info, 1)
      assert is_list(ExJsonschema.ReferenceCache.behaviour_info(:callbacks))
    end
  end

  # Helper functions for testing behavior definitions
  defp assert_callback(behavior, function, arity) do
    callbacks = behavior.behaviour_info(:callbacks)

    assert {function, arity} in callbacks,
           "Expected #{behavior} to define callback #{function}/#{arity}"
  end

  defp assert_optional_callback(behavior, function, arity) do
    optional_callbacks = behavior.behaviour_info(:optional_callbacks)

    assert {function, arity} in optional_callbacks,
           "Expected #{behavior} to define optional callback #{function}/#{arity}"
  end
end
