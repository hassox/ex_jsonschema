defmodule Mix.Tasks.Benchmark do
  @moduledoc """
  Benchmarks ExJsonschema performance across different output formats.
  
  Usage:
  
      mix benchmark
      mix benchmark --format verbose
      mix benchmark --iterations 1000
  
  """
  
  use Mix.Task
  
  @shortdoc "Runs ExJsonschema performance benchmarks"

  def run(args) do
    {parsed, _, _} = OptionParser.parse(args, 
      switches: [format: :string, iterations: :integer, help: :boolean],
      aliases: [h: :help, f: :format, i: :iterations]
    )
    
    if parsed[:help] do
      print_help()
    else
      Mix.Task.run("app.start")
      run_benchmarks(parsed)
    end
  end
  
  defp print_help do
    IO.puts("""
    Benchmarks ExJsonschema performance across different output formats.
    
    Options:
      --format FORMAT     Run benchmarks for specific format (basic, detailed, verbose, all)
      --iterations NUM    Number of iterations to run (default: 1000)
      --help, -h         Show this help
      
    Examples:
      mix benchmark
      mix benchmark --format verbose --iterations 500
    """)
  end
  
  defp run_benchmarks(opts) do
    format = Keyword.get(opts, :format, "all")
    iterations = Keyword.get(opts, :iterations, 1000)
    
    IO.puts("ExJsonschema Performance Benchmark")
    IO.puts("==================================")
    IO.puts("Iterations: #{iterations}")
    IO.puts("")
    
    # Setup test data
    schema = ~s({
      "type": "object",
      "properties": {
        "name": {"type": "string", "minLength": 2},
        "age": {"type": "number", "minimum": 0, "maximum": 150}
      },
      "required": ["name"]
    })
    
    {:ok, validator} = ExJsonschema.compile(schema)
    
    valid_instances = Enum.map(1..iterations, fn i ->
      ~s({"name": "User #{i}", "age": #{20 + rem(i, 50)}})
    end)
    
    invalid_instances = Enum.map(1..(div(iterations, 10)), fn i ->
      ~s({"name": "x", "age": #{rem(i, 3) - 1}}) # Name too short, age might be negative
    end)
    
    case format do
      "basic" -> benchmark_format(:basic, validator, valid_instances, invalid_instances)
      "detailed" -> benchmark_format(:detailed, validator, valid_instances, invalid_instances)
      "verbose" -> benchmark_format(:verbose, validator, valid_instances, invalid_instances)
      _ -> benchmark_all_formats(validator, valid_instances, invalid_instances)
    end
  end
  
  defp benchmark_all_formats(validator, valid_instances, invalid_instances) do
    [:basic, :detailed, :verbose]
    |> Enum.each(&benchmark_format(&1, validator, valid_instances, invalid_instances))
    
    IO.puts("")
    benchmark_comparison(validator, valid_instances)
  end
  
  defp benchmark_format(format, validator, valid_instances, invalid_instances) do
    IO.puts("#{String.capitalize(to_string(format))} Format Benchmark:")
    IO.puts("#{String.duplicate("-", 30)}")
    
    # Valid instances benchmark
    {time_valid, _results} = :timer.tc(fn ->
      Enum.map(valid_instances, &ExJsonschema.validate(validator, &1, output: format))
    end)
    
    valid_throughput = 1_000_000 * length(valid_instances) / time_valid
    
    # Invalid instances benchmark  
    {time_invalid, _results} = :timer.tc(fn ->
      Enum.map(invalid_instances, &ExJsonschema.validate(validator, &1, output: format))
    end)
    
    invalid_throughput = 1_000_000 * length(invalid_instances) / time_invalid
    
    IO.puts("Valid instances:   #{format_number(round(valid_throughput))} validations/sec")
    IO.puts("Invalid instances: #{format_number(round(invalid_throughput))} validations/sec")
    IO.puts("Average time:      #{Float.round(time_valid / length(valid_instances), 2)}μs per validation")
    IO.puts("")
  end
  
  defp benchmark_comparison(validator, instances) do
    IO.puts("Performance Comparison:")
    IO.puts("=======================")
    
    sample_instances = Enum.take(instances, 200)
    
    formats = [:basic, :detailed, :verbose]
    times = Enum.map(formats, fn format ->
      {time, _} = :timer.tc(fn ->
        Enum.each(sample_instances, &ExJsonschema.validate(validator, &1, output: format))
      end)
      {format, time}
    end)
    
    [{:basic, basic_time}, {:detailed, detailed_time}, {:verbose, verbose_time}] = times
    
    IO.puts("Relative performance (#{length(sample_instances)} validations):")
    IO.puts("  Basic:    #{basic_time}μs    (1.00x)")
    IO.puts("  Detailed: #{detailed_time}μs    (#{Float.round(detailed_time / basic_time, 2)}x)")
    IO.puts("  Verbose:  #{verbose_time}μs    (#{Float.round(verbose_time / basic_time, 2)}x)")
    IO.puts("")
    
    # Memory usage test
    memory_before = :erlang.memory(:total)
    
    _error_results = Enum.map(1..50, fn _i ->
      ExJsonschema.validate(validator, ~s({"name": "x"}), output: :verbose)
    end)
    
    :erlang.garbage_collect()
    memory_after = :erlang.memory(:total)
    memory_used = memory_after - memory_before
    
    IO.puts("Memory usage (50 verbose errors): #{format_bytes(memory_used)}")
  end
  
  defp format_number(num) when num >= 1_000_000 do
    "#{Float.round(num / 1_000_000, 1)}M"
  end
  defp format_number(num) when num >= 1_000 do
    "#{Float.round(num / 1_000, 1)}K"
  end
  defp format_number(num), do: to_string(num)
  
  defp format_bytes(bytes) when bytes >= 1024 * 1024 do
    "#{Float.round(bytes / (1024 * 1024), 2)} MB"
  end
  defp format_bytes(bytes) when bytes >= 1024 do
    "#{Float.round(bytes / 1024, 2)} KB"
  end
  defp format_bytes(bytes), do: "#{bytes} bytes"
end