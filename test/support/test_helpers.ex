defmodule ExJsonschema.TestHelpers do
  @moduledoc """
  Helper functions for testing ExJsonschema functionality.

  Provides utilities for:
  - Asserting validation outcomes
  - Performance benchmarking  
  - Error analysis
  - Test data generation
  """

  use ExUnit.Case

  @doc """
  Asserts that validation succeeds for the given validator and instance.
  """
  def assert_valid_validation(validator, instance) do
    case ExJsonschema.validate(validator, instance) do
      :ok ->
        :ok

      {:error, errors} ->
        ExUnit.Assertions.flunk("Expected validation to succeed, got errors: #{inspect(errors)}")
    end
  end

  @doc """
  Asserts that validation fails for the given validator and instance.
  Optionally checks for a specific error keyword.
  """
  def assert_invalid_validation(validator, instance, expected_keyword \\ nil) do
    case ExJsonschema.validate(validator, instance) do
      :ok ->
        ExUnit.Assertions.flunk("Expected validation to fail")

      {:error, errors} ->
        if expected_keyword do
          assert Enum.any?(errors, &(&1.keyword == expected_keyword)),
                 "Expected error with keyword '#{expected_keyword}', got: #{inspect(errors)}"
        end

        errors
    end
  end

  @doc """
  Benchmarks validation throughput and asserts minimum performance.

  ## Options
    * `:min_throughput` - Minimum validations per second (default: 1000)
    * `:samples` - Number of samples to average (default: 5)
  """
  def benchmark_validation(validator, instances, opts \\ []) do
    min_throughput = Keyword.get(opts, :min_throughput, 1000)
    samples = Keyword.get(opts, :samples, 5)

    times =
      for _ <- 1..samples do
        {time_us, _results} =
          :timer.tc(fn ->
            Enum.map(instances, &ExJsonschema.validate(validator, &1))
          end)

        time_us
      end

    avg_time_us = Enum.sum(times) / length(times)
    throughput = 1_000_000 * length(instances) / avg_time_us

    if throughput < min_throughput do
      ExUnit.Assertions.flunk(
        "Throughput #{Float.round(throughput, 2)} below minimum #{min_throughput} validations/second"
      )
    end

    %{throughput: throughput, avg_time_us: avg_time_us}
  end

  @doc """
  Measures memory usage during validation.
  """
  def measure_memory_usage(fun) do
    :erlang.garbage_collect()
    memory_before = :erlang.memory(:total)

    result = fun.()

    :erlang.garbage_collect()
    memory_after = :erlang.memory(:total)

    {result, memory_after - memory_before}
  end

  @doc """
  Asserts that a validation error contains expected fields.
  """
  def assert_validation_error(error, opts \\ []) do
    expected_keyword = Keyword.get(opts, :keyword)
    expected_path = Keyword.get(opts, :instance_path)
    expected_message_pattern = Keyword.get(opts, :message_pattern)

    if expected_keyword do
      assert error.keyword == expected_keyword,
             "Expected keyword '#{expected_keyword}', got '#{error.keyword}'"
    end

    if expected_path do
      assert error.instance_path == expected_path,
             "Expected instance path '#{expected_path}', got '#{error.instance_path}'"
    end

    if expected_message_pattern do
      assert error.message =~ expected_message_pattern,
             "Expected message to match pattern, got '#{error.message}'"
    end

    error
  end

  @doc """
  Creates a test validator from schema JSON string.
  """
  def test_validator(schema_json) do
    case ExJsonschema.compile(schema_json) do
      {:ok, validator} ->
        validator

      {:error, error} ->
        ExUnit.Assertions.flunk("Failed to compile test schema: #{inspect(error)}")
    end
  end
end
