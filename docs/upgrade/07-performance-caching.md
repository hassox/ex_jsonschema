# Surface 7: Performance & Caching

## Current State
- Basic schema compilation and validation
- No caching mechanisms
- No performance optimization options
- Single-threaded validation

## Target Capabilities (from Rust crate)
- Schema compilation caching
- Validation result caching  
- Performance tuning options (regex engines, optimization levels)
- Memory usage optimization
- Concurrent validation support
- Benchmarking and profiling tools

## Proposed Elixir API Design

### Performance Configuration
```elixir
defmodule ExJsonschema.Performance do
  @type regex_engine :: :fancy | :regex
  @type optimization_level :: :none | :basic | :aggressive
  
  @type options :: %{
    # Regex engine selection
    regex_engine: regex_engine(),
    
    # Compilation optimizations  
    optimization_level: optimization_level(),
    inline_remote_schemas: boolean(),
    precompile_patterns: boolean(),
    
    # Memory management
    max_schema_cache_size: pos_integer(),
    max_validation_cache_size: pos_integer(),
    cache_ttl_seconds: pos_integer(),
    
    # Concurrency
    enable_parallel_validation: boolean(),
    max_concurrent_validations: pos_integer(),
    
    # Debugging
    collect_metrics: boolean(),
    enable_profiling: boolean()
  }
  
  def default_options(), do: %__MODULE__{}
  def high_performance(), do: %__MODULE__{regex_engine: :regex, optimization_level: :aggressive}
  def memory_optimized(), do: %__MODULE__{max_schema_cache_size: 10, cache_ttl_seconds: 300}
end
```

### Schema Compilation Caching (Behavior-Based)
```elixir
defmodule ExJsonschema.Cache do
  @type cache_key :: String.t()
  @type cache_value :: ExJsonschema.validator()
  @type cache_opts :: keyword()
  
  @callback get(cache_key(), cache_opts()) :: {:ok, cache_value()} | {:error, :not_found}
  @callback put(cache_key(), cache_value(), cache_opts()) :: :ok | {:error, term()}
  @callback delete(cache_key(), cache_opts()) :: :ok
  @callback clear(cache_opts()) :: :ok
  @callback size(cache_opts()) :: non_neg_integer()
  @callback stats(cache_opts()) :: map()
  @optional_callbacks [stats: 1, size: 1]
end

defmodule ExJsonschema.SchemaCache do
  @cache_adapter Application.compile_env(:ex_jsonschema, :cache_adapter, ExJsonschema.Cache.Memory)
  
  @spec compile_cached(String.t(), ExJsonschema.Options.t(), keyword()) :: 
    {:ok, ExJsonschema.validator()} | {:error, term()}
  def compile_cached(schema_json, options \\ ExJsonschema.Options.new(), cache_opts \\ [])
  
  @spec invalidate(String.t(), keyword()) :: :ok
  def invalidate(cache_key, cache_opts \\ [])
  
  @spec clear(keyword()) :: :ok
  def clear(cache_opts \\ [])
  
  @spec stats(keyword()) :: map()
  def stats(cache_opts \\ [])
end
```

### Cache Implementation Options (Behavior-Based)
```elixir
# Users can implement the ExJsonschema.Cache behavior with:
# - Nebulex (distributed caching)
# - Cachex (local caching with features)
# - ETS (simple local caching) 
# - Redis adapters
# - Database-backed caching
# - Custom implementations

# Library provides configuration to specify cache adapter:
# config :ex_jsonschema,
#   cache_adapter: MyApp.SchemaCache  # must implement ExJsonschema.Cache
```

### Configuration Examples  
```elixir
# config/config.exs - User specifies their cache implementation
config :ex_jsonschema,
  cache_adapter: MyApp.SchemaCache,  # implements ExJsonschema.Cache
  default_cache_opts: [
    ttl: :timer.hours(1)
  ]

# Example user implementations:
# MyApp.NeulexCache - wraps Nebulex
# MyApp.CachexCache - wraps Cachex  
# MyApp.RedisCache - Redis-backed
# MyApp.DatabaseCache - DB-backed
```

### High-Performance API with Caching
```elixir
# High-performance compilation with caching
{:ok, validator} = ExJsonschema.SchemaCache.compile_cached(schema_json, 
  ExJsonschema.Options.new(
    optimization_level: :aggressive,
    regex_engine: :regex
  ),
  cache: MyApp.SchemaCache,
  ttl: :timer.hours(1)
)

# Batch validation with concurrency
results = ExJsonschema.validate_batch(validator, [instance1, instance2, instance3], [
  parallel: true,
  max_workers: 4,
  timeout: 5000
])

# Streaming validation for large datasets
{:ok, stream} = ExJsonschema.validate_stream(validator, json_stream, [
  batch_size: 100,
  parallel: true
])
```

### Performance Monitoring
```elixir
defmodule ExJsonschema.Metrics do
  @spec compilation_time(String.t(), ExJsonschema.Options.t()) :: {pos_integer(), ExJsonschema.validator()}
  def compilation_time(schema_json, options)
  
  @spec validation_time(ExJsonschema.validator(), String.t()) :: {pos_integer(), ExJsonschema.validation_result()}
  def validation_time(validator, instance_json)
  
  @spec memory_usage(ExJsonschema.validator()) :: non_neg_integer()
  def memory_usage(validator)
  
  @spec cache_statistics() :: %{
    schema_cache: map(),
    validation_cache: map()
  }
  def cache_statistics()
end
```

### Benchmarking Utilities
```elixir
defmodule ExJsonschema.Benchmark do
  @spec compare_regex_engines(String.t(), String.t()) :: %{fancy: float(), regex: float()}
  def compare_regex_engines(schema_json, instance_json)
  
  @spec profile_validation(ExJsonschema.validator(), String.t(), keyword()) :: map()
  def profile_validation(validator, instance_json, opts \\ [])
  
  @spec throughput_test(ExJsonschema.validator(), [String.t()], keyword()) :: %{
    validations_per_second: float(),
    average_latency_ms: float(),
    p95_latency_ms: float()
  }
  def throughput_test(validator, instances, opts \\ [])
end
```

## Implementation Plan

### Phase 1: Basic Performance Optimizations
1. Add regex engine selection support
2. Implement basic compilation caching
3. Add performance configuration options
4. Create benchmarking utilities

### Phase 2: Advanced Caching
1. Implement LRU/LFU cache with TTL
2. Add validation result caching with intelligent keys
3. Create cache invalidation strategies
4. Add cache metrics and monitoring

### Phase 3: Concurrent Validation
1. Research and implement parallel validation
2. Add batch validation support
3. Implement streaming validation for large datasets
4. Add worker pool management

### Phase 4: Monitoring and Profiling
1. Add comprehensive performance metrics
2. Implement validation profiling
3. Create performance regression testing
4. Add memory usage optimization

## Rust Integration Points
- Use Rust performance configuration options
- Implement caching at Rust level where beneficial
- Leverage Rust's parallelism for concurrent validation
- Use Rust profiling tools for performance analysis

## API Examples

### High-Performance Web API
```elixir
defmodule MyAPI.Application do
  use Application
  
  def start(_type, _args) do
    children = [
      # Start Nebulex cache for schema caching
      {MyApp.SchemaCache, []},
      # ... other children
    ]
    
    Supervisor.start_link(children, strategy: :one_for_one)
  end
end

defmodule MyApp.SchemaCache do
  use Nebulex.Cache,
    otp_app: :my_app,
    adapter: Nebulex.Adapters.Local
end

defmodule MyAPI.SchemaValidator do
  def validate_request(schema_id, json_data) do
    # Compile schema with caching and performance optimizations
    performance_opts = ExJsonschema.Performance.high_performance()
    
    case ExJsonschema.SchemaCache.compile_cached(schema_id, performance_opts,
      cache: MyApp.SchemaCache,
      ttl: :timer.hours(1)
    ) do
      {:ok, validator} ->
        ExJsonschema.validate(validator, json_data)
        
      {:error, reason} ->
        {:error, reason}
    end
  end
end
```

### Batch Data Processing
```elixir
defmodule DataPipeline.Validator do
  def process_batch(schema, json_records) do
    # Compile with aggressive optimizations
    {:ok, validator} = ExJsonschema.compile(schema, [
      optimization_level: :aggressive,
      regex_engine: :regex,
      inline_remote_schemas: true
    ])
    
    # Process in parallel batches
    results = ExJsonschema.validate_batch(validator, json_records, [
      parallel: true,
      max_workers: System.schedulers_online(),
      batch_size: 100,
      timeout: 30_000
    ])
    
    # Collect metrics
    {valid, invalid} = Enum.split_with(results, fn {result, _} -> result == :ok end)
    
    %{
      total_processed: length(json_records),
      valid_count: length(valid),
      invalid_count: length(invalid),
      processing_time: :timer.tc(fn -> results end) |> elem(0),
      throughput: length(json_records) / (:timer.tc(fn -> results end) |> elem(0) / 1_000_000)
    }
  end
end
```

### Configuration Validation with Caching
```elixir
defmodule ConfigValidator do
  @config_schema_cache :config_schema_cache
  
  def setup do
    # Create dedicated cache for configuration schemas
    :ets.new(@config_schema_cache, [:named_table, :public, :set])
    
    # Pre-warm cache with common schemas
    preload_schemas([
      "database-config",
      "redis-config", 
      "api-config"
    ])
  end
  
  def validate_config(config_type, config_json) do
    case :ets.lookup(@config_schema_cache, config_type) do
      [{^config_type, validator}] ->
        # Use cached validator
        ExJsonschema.validate(validator, config_json)
        
      [] ->
        # Compile and cache
        schema = load_schema(config_type)
        {:ok, validator} = ExJsonschema.compile(schema, [
          optimization_level: :basic,
          validate_formats: true
        ])
        
        :ets.insert(@config_schema_cache, {config_type, validator})
        ExJsonschema.validate(validator, config_json)
    end
  end
end
```

### Performance Monitoring Setup
```elixir
defmodule ValidationMetrics do
  def setup_telemetry do
    :telemetry.attach_many(
      "validation-metrics",
      [
        [:ex_jsonschema, :compilation, :duration],
        [:ex_jsonschema, :validation, :duration], 
        [:ex_jsonschema, :cache, :hit],
        [:ex_jsonschema, :cache, :miss]
      ],
      &handle_metrics/4,
      nil
    )
  end
  
  defp handle_metrics([:ex_jsonschema, :validation, :duration], %{duration: duration}, metadata, _) do
    # Send to monitoring system
    :prometheus_histogram.observe(:validation_duration_seconds, duration / 1_000_000)
    
    # Log slow validations
    if duration > 100_000 do  # > 100ms
      Logger.warning("Slow validation detected", [
        duration_ms: duration / 1000,
        schema_size: metadata[:schema_size],
        instance_size: metadata[:instance_size]
      ])
    end
  end
end
```

### Benchmark Suite
```elixir
defmodule ValidationBenchmarks do
  def run_comprehensive_benchmarks do
    schemas = load_benchmark_schemas()
    instances = load_benchmark_instances()
    
    results = %{}
    
    # Test regex engine performance
    for schema <- schemas do
      fancy_time = ExJsonschema.Benchmark.compare_regex_engines(schema, instances)
      results = Map.put(results, schema, fancy_time)
    end
    
    # Test throughput
    for {schema, instances} <- Enum.zip(schemas, instances) do
      {:ok, validator} = ExJsonschema.compile(schema)
      
      throughput = ExJsonschema.Benchmark.throughput_test(validator, instances, [
        warmup: 1000,
        iterations: 10000
      ])
      
      IO.puts("Schema throughput: #{throughput.validations_per_second} ops/sec")
    end
    
    # Memory usage analysis
    for schema <- schemas do
      {:ok, validator} = ExJsonschema.compile(schema)
      memory_kb = ExJsonschema.Metrics.memory_usage(validator) / 1024
      IO.puts("Schema memory usage: #{memory_kb} KB")
    end
  end
end
```

## Performance Optimization Strategies

### Compilation Optimizations
- Schema caching with intelligent cache keys
- Precompilation of regex patterns
- Inlining of remote schema references
- Dead code elimination for unused keywords

### Validation Optimizations
- Early termination on first error (when appropriate)
- Result caching for expensive validations
- Parallel validation of array items
- Memory pooling for temporary objects

### Caching Strategies
- Multi-level caching (memory → disk → remote)
- Cache warming and preloading
- Intelligent cache invalidation
- Cache partitioning by use case

## Memory Management
- Reference counting for shared validators
- Lazy loading of large schema components
- Memory-mapped caching for very large schemas
- Garbage collection tuning for validation workloads

## Monitoring and Observability
- Real-time validation performance metrics
- Cache hit/miss ratios and effectiveness
- Memory usage trends and leak detection
- Performance regression detection

## Backward Compatibility
- All performance optimizations are opt-in
- Default behavior maintains current performance characteristics
- No breaking changes to existing APIs
- Progressive enhancement path for applications