defmodule ExJsonschema.ProfileTest do
  use ExUnit.Case, async: true
  
  alias ExJsonschema.Profile
  alias ExJsonschema.Options
  
  doctest ExJsonschema.Profile
  
  describe "strict/1" do
    test "returns strict profile with default options" do
      opts = Profile.strict()
      
      assert %Options{} = opts
      assert opts.validate_formats == true
      assert opts.ignore_unknown_formats == false
      assert opts.collect_annotations == true
      assert opts.stop_on_first_error == false
      assert opts.output_format == :verbose
      assert opts.include_schema_path == true
      assert opts.include_instance_path == true
      assert opts.resolve_external_refs == false
      assert opts.allow_remote_references == false
      assert opts.max_reference_depth == 5
      assert opts.trusted_domains == []
      assert opts.regex_engine == :fancy_regex
      assert opts.cache_compiled_schemas == true
      assert opts.draft == :draft202012
    end
    
    test "allows overriding options" do
      opts = Profile.strict(output_format: :basic, stop_on_first_error: true)
      
      assert opts.output_format == :basic
      assert opts.stop_on_first_error == true
      # Other strict defaults preserved
      assert opts.validate_formats == true
      assert opts.ignore_unknown_formats == false
    end
    
    test "maintains strict character with overrides" do
      opts = Profile.strict(draft: :auto, max_reference_depth: 10)
      
      # Override applied
      assert opts.draft == :auto
      assert opts.max_reference_depth == 10
      # Strict character maintained
      assert opts.validate_formats == true
      assert opts.ignore_unknown_formats == false
      assert opts.output_format == :verbose
    end
  end
  
  describe "lenient/1" do
    test "returns lenient profile with default options" do
      opts = Profile.lenient()
      
      assert %Options{} = opts
      assert opts.validate_formats == false
      assert opts.ignore_unknown_formats == true
      assert opts.collect_annotations == true
      assert opts.stop_on_first_error == false
      assert opts.output_format == :detailed
      assert opts.include_schema_path == true
      assert opts.include_instance_path == true
      assert opts.resolve_external_refs == false
      assert opts.allow_remote_references == false
      assert opts.max_reference_depth == 8
      assert opts.trusted_domains == []
      assert opts.regex_engine == :fancy_regex
      assert opts.cache_compiled_schemas == true
      assert opts.draft == :auto
    end
    
    test "allows overriding options" do
      opts = Profile.lenient(validate_formats: true, collect_annotations: false)
      
      assert opts.validate_formats == true
      assert opts.collect_annotations == false
      # Other lenient defaults preserved
      assert opts.ignore_unknown_formats == true
      assert opts.output_format == :detailed
    end
    
    test "maintains lenient character with overrides" do
      opts = Profile.lenient(output_format: :verbose, draft: :draft7)
      
      # Override applied
      assert opts.output_format == :verbose
      assert opts.draft == :draft7
      # Lenient character maintained
      assert opts.validate_formats == false
      assert opts.ignore_unknown_formats == true
    end
  end
  
  describe "performance/1" do
    test "returns performance profile with default options" do
      opts = Profile.performance()
      
      assert %Options{} = opts
      assert opts.validate_formats == false
      assert opts.ignore_unknown_formats == true
      assert opts.collect_annotations == false
      assert opts.stop_on_first_error == true
      assert opts.output_format == :basic
      assert opts.include_schema_path == false
      assert opts.include_instance_path == false
      assert opts.resolve_external_refs == false
      assert opts.allow_remote_references == false
      assert opts.max_reference_depth == 3
      assert opts.trusted_domains == []
      assert opts.regex_engine == :regex
      assert opts.cache_compiled_schemas == true
      assert opts.draft == :draft202012
    end
    
    test "allows overriding options" do
      opts = Profile.performance(output_format: :detailed, validate_formats: true)
      
      assert opts.output_format == :detailed
      assert opts.validate_formats == true
      # Other performance defaults preserved
      assert opts.collect_annotations == false
      assert opts.stop_on_first_error == true
    end
    
    test "maintains performance character with overrides" do
      opts = Profile.performance(draft: :auto, max_reference_depth: 10)
      
      # Override applied
      assert opts.draft == :auto
      assert opts.max_reference_depth == 10
      # Performance character maintained
      assert opts.collect_annotations == false
      assert opts.stop_on_first_error == true
      assert opts.regex_engine == :regex
      assert opts.output_format == :basic
    end
  end
  
  describe "get/2" do
    test "returns strict profile for :strict" do
      opts1 = Profile.get(:strict)
      opts2 = Profile.strict()
      
      assert opts1 == opts2
    end
    
    test "returns lenient profile for :lenient" do
      opts1 = Profile.get(:lenient)
      opts2 = Profile.lenient()
      
      assert opts1 == opts2
    end
    
    test "returns performance profile for :performance" do
      opts1 = Profile.get(:performance)
      opts2 = Profile.performance()
      
      assert opts1 == opts2
    end
    
    test "supports overrides for all profiles" do
      strict_opts = Profile.get(:strict, output_format: :basic)
      assert strict_opts.output_format == :basic
      assert strict_opts.validate_formats == true  # Strict character
      
      lenient_opts = Profile.get(:lenient, validate_formats: true)
      assert lenient_opts.validate_formats == true
      assert lenient_opts.ignore_unknown_formats == true  # Lenient character
      
      perf_opts = Profile.get(:performance, output_format: :verbose)
      assert perf_opts.output_format == :verbose
      assert perf_opts.collect_annotations == false  # Performance character
    end
    
    test "raises error for unknown profile" do
      assert_raise ArgumentError, ~r/Unknown profile: :unknown/, fn ->
        Profile.get(:unknown)
      end
      
      assert_raise ArgumentError, ~r/Available profiles: :strict, :lenient, :performance/, fn ->
        Profile.get(:invalid)
      end
    end
  end
  
  describe "list/0" do
    test "returns all available profiles" do
      profiles = Profile.list()
      
      assert is_list(profiles)
      assert length(profiles) == 3
      assert :strict in profiles
      assert :lenient in profiles
      assert :performance in profiles
    end
    
    test "returns profiles in consistent order" do
      profiles1 = Profile.list()
      profiles2 = Profile.list()
      
      assert profiles1 == profiles2
      assert profiles1 == [:strict, :lenient, :performance]
    end
  end
  
  describe "compare/2" do
    test "compares strict vs lenient profiles" do
      diff = Profile.compare(:strict, :lenient)
      
      # Should show key differences
      assert diff[:validate_formats] == {true, false}
      assert diff[:ignore_unknown_formats] == {false, true}
      assert diff[:output_format] == {:verbose, :detailed}
      assert diff[:max_reference_depth] == {5, 8}
      assert diff[:draft] == {:draft202012, :auto}
      
      # Should not include identical values
      refute Map.has_key?(diff, :cache_compiled_schemas)
      refute Map.has_key?(diff, :resolve_external_refs)
    end
    
    test "compares strict vs performance profiles" do
      diff = Profile.compare(:strict, :performance)
      
      # Should show major differences
      assert diff[:validate_formats] == {true, false}
      assert diff[:collect_annotations] == {true, false}
      assert diff[:stop_on_first_error] == {false, true}
      assert diff[:output_format] == {:verbose, :basic}
      assert diff[:include_schema_path] == {true, false}
      assert diff[:include_instance_path] == {true, false}
      assert diff[:regex_engine] == {:fancy_regex, :regex}
      assert diff[:max_reference_depth] == {5, 3}
    end
    
    test "compares lenient vs performance profiles" do
      diff = Profile.compare(:lenient, :performance)
      
      # Should show key differences
      assert diff[:collect_annotations] == {true, false}
      assert diff[:stop_on_first_error] == {false, true}
      assert diff[:output_format] == {:detailed, :basic}
      assert diff[:include_schema_path] == {true, false}
      assert diff[:include_instance_path] == {true, false}
      assert diff[:regex_engine] == {:fancy_regex, :regex}
      assert diff[:max_reference_depth] == {8, 3}
      assert diff[:draft] == {:auto, :draft202012}
    end
    
    test "returns empty map for identical profiles" do
      diff = Profile.compare(:strict, :strict)
      
      assert diff == %{}
    end
    
    test "raises error for invalid profile names" do
      assert_raise ArgumentError, ~r/Invalid profile name/, fn ->
        Profile.compare(:invalid, :strict)
      end
      
      assert_raise ArgumentError, ~r/Invalid profile name/, fn ->
        Profile.compare(:lenient, :unknown)
      end
      
      assert_raise ArgumentError, ~r/Available profiles/, fn ->
        Profile.compare(:bad1, :bad2)
      end
    end
  end
  
  describe "profile characteristics" do
    test "strict profile has maximum validation rigor" do
      opts = Profile.strict()
      
      # Maximum validation
      assert opts.validate_formats == true
      assert opts.ignore_unknown_formats == false
      assert opts.collect_annotations == true
      assert opts.stop_on_first_error == false
      
      # Comprehensive output
      assert opts.output_format == :verbose
      assert opts.include_schema_path == true
      assert opts.include_instance_path == true
      
      # Security-focused
      assert opts.allow_remote_references == false
      assert opts.max_reference_depth <= 5
      
      # Quality over speed
      assert opts.regex_engine == :fancy_regex
    end
    
    test "lenient profile balances validation with user-friendliness" do
      opts = Profile.lenient()
      
      # User-friendly validation
      assert opts.validate_formats == false
      assert opts.ignore_unknown_formats == true
      assert opts.collect_annotations == true
      assert opts.stop_on_first_error == false
      
      # Informative but not overwhelming
      assert opts.output_format == :detailed
      assert opts.include_schema_path == true
      assert opts.include_instance_path == true
      
      # Flexible draft handling
      assert opts.draft == :auto
      assert opts.max_reference_depth >= 5  # More generous than strict
      
      # Good user experience
      assert opts.regex_engine == :fancy_regex
    end
    
    test "performance profile prioritizes speed" do
      opts = Profile.performance()
      
      # Speed-focused validation
      assert opts.validate_formats == false
      assert opts.collect_annotations == false
      assert opts.stop_on_first_error == true
      
      # Minimal output
      assert opts.output_format == :basic
      assert opts.include_schema_path == false
      assert opts.include_instance_path == false
      
      # No external references
      assert opts.resolve_external_refs == false
      assert opts.allow_remote_references == false
      assert opts.max_reference_depth <= 5  # Conservative
      
      # Performance optimizations
      assert opts.regex_engine == :regex
      assert opts.cache_compiled_schemas == true
      assert opts.draft != :auto  # Avoid detection overhead
    end
  end
  
  describe "profile integration with Options" do
    test "profiles return valid Options structs" do
      for profile <- Profile.list() do
        opts = Profile.get(profile)
        
        assert %Options{} = opts
        assert {:ok, ^opts} = Options.validate(opts)
      end
    end
    
    test "profile overrides maintain Options validation" do
      # Valid overrides should pass
      opts = Profile.strict(draft: :draft7, output_format: :basic)
      assert {:ok, ^opts} = Options.validate(opts)
      
      # Invalid overrides should fail Options validation
      invalid_opts = Profile.lenient([{:draft, :invalid}])
      assert {:error, _reason} = Options.validate(invalid_opts)
    end
  end
end