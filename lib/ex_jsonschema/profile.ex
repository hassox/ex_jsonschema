defmodule ExJsonschema.Profile do
  @moduledoc """
  Predefined configuration profiles for common JSON Schema validation scenarios.
  
  This module provides three carefully crafted configuration profiles that optimize
  ExJsonschema for different use cases:
  
  - **:strict** - Maximum validation rigor with security-focused settings
  - **:lenient** - Flexible validation that's forgiving for common user errors  
  - **:performance** - Speed-optimized configuration for high-throughput scenarios
  
  Profiles provide sensible defaults while remaining fully customizable through
  option overrides. Each profile balances validation quality, error reporting,
  and performance for its intended use case.
  
  ## Examples
  
      # Use strict profile for API validation
      strict_opts = ExJsonschema.Profile.strict()
      {:ok, validator} = ExJsonschema.compile(schema, strict_opts)
      
      # Use lenient profile for user input forms
      lenient_opts = ExJsonschema.Profile.lenient()
      result = ExJsonschema.validate(validator, user_data, lenient_opts)
      
      # Use performance profile for high-volume batch processing  
      perf_opts = ExJsonschema.Profile.performance()
      results = Enum.map(large_dataset, &ExJsonschema.valid?(validator, &1, perf_opts))
      
      # Customize any profile with overrides
      custom_strict = ExJsonschema.Profile.strict(output_format: :verbose)
      
  ## Creating Custom Profiles
  
  While the built-in profiles cover most use cases, you can easily create your own 
  custom profiles using `ExJsonschema.Options.new/1`:
  
      # API validation profile
      api_profile = ExJsonschema.Options.new(
        validate_formats: true,
        output_format: :detailed,
        stop_on_first_error: true,
        draft: :draft7
      )
      
      # Development/debugging profile  
      debug_profile = ExJsonschema.Options.new(
        output_format: :verbose,
        include_schema_path: true,
        include_instance_path: true,
        collect_annotations: true
      )
      
      # Production microservice profile
      micro_profile = ExJsonschema.Options.new(
        output_format: :basic,
        stop_on_first_error: true,
        cache_compiled_schemas: true,
        regex_engine: :regex
      )
      
  You can then use custom profiles anywhere Options are accepted:
  
      {:ok, validator} = ExJsonschema.compile(schema, api_profile)
      result = ExJsonschema.validate(validator, data, debug_profile)
  """
  
  alias ExJsonschema.Options
  
  @typedoc """
  Available configuration profiles.
  """
  @type profile_name :: :strict | :lenient | :performance
  
  @doc """
  Returns the strict validation profile.
  
  The strict profile maximizes validation rigor and security, making it ideal
  for API validation, data integrity checks, and scenarios where compliance
  is critical.
  
  ## Configuration Highlights
  
  - **Maximum validation**: All formats validated, unknown formats rejected
  - **Security-focused**: Remote references disabled, limited reference depth
  - **Comprehensive errors**: Verbose output with full context and suggestions
  - **Annotation collection**: Enabled for complete schema information
  - **No performance shortcuts**: Quality over speed
  
  ## Use Cases
  
  - REST API request/response validation
  - Configuration file validation  
  - Data import/export validation
  - Compliance and audit scenarios
  - Development and testing environments
  
  ## Options
  
  You can override any option while maintaining the strict profile's character:
  
      # Strict but with basic error format for performance
      ExJsonschema.Profile.strict(output_format: :basic)
      
      # Strict but stop on first error
      ExJsonschema.Profile.strict(stop_on_first_error: true)
  
  ## Examples
  
      schema = ~s({"type": "object", "properties": {"email": {"type": "string", "format": "email"}}})
      {:ok, validator} = ExJsonschema.compile(schema, ExJsonschema.Profile.strict())
      
      # Will catch format violations
      ExJsonschema.validate(validator, ~s({"email": "invalid-email"}))
      #=> {:error, [%ValidationError{message: "invalid-email is not a valid email format", ...}]}
  """
  def strict(overrides \\ []) do
    strict_defaults = [
      # Validation behavior - maximum rigor
      validate_formats: true,
      ignore_unknown_formats: false,
      collect_annotations: true,
      stop_on_first_error: false,
      
      # Output - comprehensive error information
      output_format: :verbose,
      include_schema_path: true,
      include_instance_path: true,
      
      # External references - security-focused  
      resolve_external_refs: false,
      allow_remote_references: false,
      max_reference_depth: 5,  # Conservative limit
      trusted_domains: [],
      
      # Performance - quality over speed
      regex_engine: :fancy_regex,
      cache_compiled_schemas: true,  # Good for repeated validation
      
      # Draft - latest and most rigorous
      draft: :draft202012
    ]
    
    strict_defaults
    |> Keyword.merge(overrides)
    |> Options.new()
  end
  
  @doc """
  Returns the lenient validation profile.
  
  The lenient profile balances validation quality with user-friendliness, making 
  it ideal for user-facing forms, content management, and scenarios where some
  flexibility improves user experience.
  
  ## Configuration Highlights
  
  - **Forgiving validation**: Unknown formats ignored, less strict parsing
  - **User-friendly errors**: Detailed format with helpful messages
  - **Flexible drafts**: Automatic draft detection for mixed schemas
  - **Moderate security**: Controlled external reference resolution
  - **Balanced performance**: Good speed without sacrificing essential features
  
  ## Use Cases
  
  - Web form validation
  - User-generated content validation
  - Content management systems
  - Mobile app data validation
  - Prototyping and development
  
  ## Options
  
  Override options to fine-tune the lenient behavior:
  
      # Lenient but with format validation for critical fields
      ExJsonschema.Profile.lenient(validate_formats: true)
      
      # Lenient but disable annotations for better performance
      ExJsonschema.Profile.lenient(collect_annotations: false)
  
  ## Examples
  
      schema = ~s({"type": "object", "properties": {"age": {"type": "number", "custom-format": "range"}}})
      {:ok, validator} = ExJsonschema.compile(schema, ExJsonschema.Profile.lenient())
      
      # Will ignore unknown custom format
      ExJsonschema.validate(validator, ~s({"age": 25}))
      #=> :ok
  """
  def lenient(overrides \\ []) do
    lenient_defaults = [
      # Validation behavior - user-friendly
      validate_formats: false,  # Less strict for user input
      ignore_unknown_formats: true,  # Ignore custom formats
      collect_annotations: true,  # Helpful for UX
      stop_on_first_error: false,  # Show all issues
      
      # Output - informative but not overwhelming
      output_format: :detailed,
      include_schema_path: true,
      include_instance_path: true,
      
      # External references - controlled flexibility
      resolve_external_refs: false,  # Conservative default
      allow_remote_references: false,  # Can be overridden
      max_reference_depth: 8,  # Slightly more generous
      trusted_domains: [],
      
      # Performance - balanced approach
      regex_engine: :fancy_regex,  # Better user experience
      cache_compiled_schemas: true,
      
      # Draft - automatic detection for mixed environments
      draft: :auto
    ]
    
    lenient_defaults
    |> Keyword.merge(overrides) 
    |> Options.new()
  end
  
  @doc """
  Returns the performance-optimized validation profile.
  
  The performance profile prioritizes speed and throughput, making it ideal
  for high-volume batch processing, real-time validation, and scenarios where
  validation happens in tight loops.
  
  ## Configuration Highlights
  
  - **Maximum speed**: Minimal validation features, fast-fail behavior
  - **Lightweight errors**: Basic error format, essential information only
  - **Performance shortcuts**: Simple regex engine, no annotations
  - **Minimal overhead**: Disabled features that impact throughput
  - **Memory efficient**: Optimized for high-volume processing
  
  ## Use Cases
  
  - High-frequency API endpoints
  - Stream processing and ETL pipelines
  - Batch data validation jobs
  - Real-time event validation
  - Performance-critical microservices
  
  ## Options
  
  You can selectively enable features when performance allows:
  
      # Performance profile but collect errors for debugging
      ExJsonschema.Profile.performance(output_format: :detailed)
      
      # Performance profile but validate critical formats
      ExJsonschema.Profile.performance(validate_formats: true)
  
  ## Examples
  
      schema = ~s({"type": "object", "required": ["id"]})
      {:ok, validator} = ExJsonschema.compile(schema, ExJsonschema.Profile.performance())
      
      # Fast validation with minimal error details
      ExJsonschema.valid?(validator, ~s({"id": "123"}))
      #=> true
      
      ExJsonschema.validate(validator, ~s({}))
      #=> {:error, :validation_failed}  # Basic error format
  """
  def performance(overrides \\ []) do
    performance_defaults = [
      # Validation behavior - speed focused
      validate_formats: false,  # Skip expensive format checks
      ignore_unknown_formats: true,  # Don't process unknown formats
      collect_annotations: false,  # Skip annotation collection
      stop_on_first_error: true,  # Fast-fail behavior
      
      # Output - minimal information
      output_format: :basic,
      include_schema_path: false,  # Reduce processing
      include_instance_path: false,
      
      # External references - disabled for speed
      resolve_external_refs: false,
      allow_remote_references: false, 
      max_reference_depth: 3,  # Conservative to prevent deep recursion
      trusted_domains: [],
      
      # Performance - maximum optimization
      regex_engine: :regex,  # Faster regex engine
      cache_compiled_schemas: true,  # Essential for performance
      
      # Draft - explicit for consistency
      draft: :draft202012  # Avoid auto-detection overhead
    ]
    
    performance_defaults
    |> Keyword.merge(overrides)
    |> Options.new()
  end
  
  @doc """
  Returns the options for the specified profile name.
  
  This function provides a convenient way to access profiles by name,
  useful for configuration-driven applications.
  
  ## Examples
  
      opts = ExJsonschema.Profile.get(:strict)
      # Same as: ExJsonschema.Profile.strict()
      
      opts = ExJsonschema.Profile.get(:performance, output_format: :detailed)
      # Same as: ExJsonschema.Profile.performance(output_format: :detailed)
  """
  def get(profile_name, overrides \\ [])
  
  def get(:strict, overrides), do: strict(overrides)
  def get(:lenient, overrides), do: lenient(overrides)
  def get(:performance, overrides), do: performance(overrides)
  
  def get(profile_name, _overrides) do
    raise ArgumentError, """
    Unknown profile: #{inspect(profile_name)}
    
    Available profiles: :strict, :lenient, :performance
    
    Examples:
      ExJsonschema.Profile.get(:strict)
      ExJsonschema.Profile.get(:lenient, validate_formats: true)
      ExJsonschema.Profile.get(:performance, output_format: :detailed)
    """
  end
  
  @doc """
  Lists all available profile names.
  
  ## Examples
  
      ExJsonschema.Profile.list()
      #=> [:strict, :lenient, :performance]
  """
  def list do
    [:strict, :lenient, :performance]
  end
  
  @doc """
  Compares two profiles and returns the differences in their configurations.
  
  This function is useful for understanding how profiles differ and for
  documentation or debugging purposes.
  
  ## Examples
  
      ExJsonschema.Profile.compare(:strict, :performance)
      #=> %{
      #     validate_formats: {true, false},
      #     output_format: {:verbose, :basic},
      #     stop_on_first_error: {false, true},
      #     collect_annotations: {true, false},
      #     regex_engine: {:fancy_regex, :regex}
      #   }
  """
  def compare(profile1, profile2) when profile1 in [:strict, :lenient, :performance] and 
                                       profile2 in [:strict, :lenient, :performance] do
    opts1 = get(profile1) |> Map.from_struct()
    opts2 = get(profile2) |> Map.from_struct()
    
    opts1
    |> Map.keys()
    |> Enum.reduce(%{}, fn key, acc ->
      val1 = Map.get(opts1, key)
      val2 = Map.get(opts2, key)
      
      if val1 != val2 do
        Map.put(acc, key, {val1, val2})
      else
        acc
      end
    end)
  end
  
  def compare(profile1, profile2) do
    valid_profiles = list()
    
    raise ArgumentError, """
    Invalid profile name(s): #{inspect([profile1, profile2])}
    
    Available profiles: #{inspect(valid_profiles)}
    """
  end
end