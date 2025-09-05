# Streaming Validation

ExJsonschema works great with Elixir's Stream module for processing large datasets without loading everything into memory. Here are some simple patterns to get you started.

## Basic File Streaming

Process a file line by line:

```elixir
# Compile your schema once
schema = ~s({"type": "object", "properties": {"name": {"type": "string"}}})
{:ok, validator} = ExJsonschema.compile(schema)

# Stream and validate each line
results = 
  "data.jsonl"
  |> File.stream!()
  |> Stream.map(&String.trim/1)
  |> Stream.map(fn line ->
    case ExJsonschema.validate(validator, line) do
      :ok -> :valid
      {:error, _errors} -> :invalid
    end
  end)
  |> Enum.frequencies()

IO.inspect(results)  # %{valid: 1500, invalid: 23}
```

## Concurrent Processing

Use `Task.async_stream/3` for parallel validation:

```elixir
data_stream = File.stream!("large_file.jsonl")

results = 
  data_stream
  |> Task.async_stream(fn line ->
    ExJsonschema.validate(validator, String.trim(line))
  end, max_concurrency: 8)
  |> Stream.map(fn {:ok, result} -> result end)
  |> Enum.frequencies()
```

## JSON Arrays

Stream elements from a large JSON array:

```elixir
# Load and parse the array
{:ok, big_array} = "large_dataset.json" |> File.read!() |> Jason.decode()

# Stream individual elements
valid_items = 
  big_array
  |> Stream.map(&Jason.encode!/1)
  |> Stream.filter(fn item_json ->
    ExJsonschema.valid?(validator, item_json)
  end)
  |> Enum.to_list()
```

## Memory-Friendly Processing

Process without accumulating results:

```elixir
# Just count, don't store results
{valid_count, invalid_count} = 
  File.stream!("huge_file.jsonl")
  |> Stream.map(&String.trim/1)
  |> Enum.reduce({0, 0}, fn line, {valid, invalid} ->
    case ExJsonschema.validate(validator, line) do
      :ok -> {valid + 1, invalid}
      {:error, _} -> {valid, invalid + 1}
    end
  end)

IO.puts("Processed: #{valid_count + invalid_count} total")
```

## That's It

Streams work exactly as you'd expect with ExJsonschema. The validation functions are designed to work seamlessly in stream pipelines, so you can build whatever processing patterns make sense for your use case.

For more complex scenarios, check out:
- **[Performance & Production Guide](performance_production.html)** - Optimization techniques
- **[Advanced Features Guide](advanced_features.html)** - Configuration options