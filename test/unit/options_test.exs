defmodule ExJsonschema.OptionsTest do
  use ExUnit.Case
  use ExUnit.CaseHelpers

  alias ExJsonschema.Options

  describe "new/1" do
    test "creates options with default values" do
      opts = Options.new()

      assert opts.draft == :auto
      assert opts.validate_formats == false
      assert opts.ignore_unknown_formats == true
      assert opts.collect_annotations == true
      assert opts.stop_on_first_error == false
      assert opts.resolve_external_refs == false
      assert opts.retriever == nil
      assert opts.reference_cache == nil
      assert opts.regex_engine == :fancy_regex
      assert opts.cache_compiled_schemas == false
      assert opts.output_format == :basic
      assert opts.include_schema_path == true
      assert opts.include_instance_path == true
      assert opts.max_reference_depth == 10
      assert opts.allow_remote_references == false
      assert opts.trusted_domains == []
    end

    test "creates options with overrides" do
      opts =
        Options.new(
          draft: :draft202012,
          validate_formats: true,
          ignore_unknown_formats: false,
          regex_engine: :regex,
          max_reference_depth: 5
        )

      assert opts.draft == :draft202012
      assert opts.validate_formats == true
      assert opts.ignore_unknown_formats == false
      assert opts.regex_engine == :regex
      assert opts.max_reference_depth == 5

      # Other fields should remain default
      assert opts.collect_annotations == true
      assert opts.stop_on_first_error == false
    end
  end

  describe "draft-specific constructors" do
    test "draft4/1 creates draft 4 options" do
      opts = Options.draft4(validate_formats: true)

      assert opts.draft == :draft4
      assert opts.validate_formats == true
    end

    test "draft6/1 creates draft 6 options" do
      opts = Options.draft6()
      assert opts.draft == :draft6
    end

    test "draft7/1 creates draft 7 options" do
      opts = Options.draft7(collect_annotations: false)

      assert opts.draft == :draft7
      assert opts.collect_annotations == false
    end

    test "draft201909/1 creates draft 2019-09 options" do
      opts = Options.draft201909()
      assert opts.draft == :draft201909
    end

    test "draft202012/1 creates draft 2020-12 options" do
      opts = Options.draft202012(output_format: :detailed)

      assert opts.draft == :draft202012
      assert opts.output_format == :detailed
    end
  end

  describe "validate/1" do
    test "validates correct options" do
      opts =
        Options.new(
          draft: :draft202012,
          regex_engine: :fancy_regex,
          output_format: :detailed,
          max_reference_depth: 15,
          trusted_domains: ["example.com", "api.service.org"]
        )

      assert {:ok, ^opts} = Options.validate(opts)
    end

    test "rejects invalid draft" do
      opts = %Options{draft: :invalid_draft}

      assert {:error, "Invalid draft version: :invalid_draft"} = Options.validate(opts)
    end

    test "rejects invalid regex engine" do
      opts = %Options{regex_engine: :invalid_engine}

      assert {:error, "Invalid regex engine: :invalid_engine"} = Options.validate(opts)
    end

    test "rejects invalid output format" do
      opts = %Options{output_format: :invalid_format}

      assert {:error, "Invalid output format: :invalid_format"} = Options.validate(opts)
    end

    test "rejects negative reference depth" do
      opts = %Options{max_reference_depth: -1}

      assert {:error, "Reference depth must be a non-negative integer, got: -1"} =
               Options.validate(opts)
    end

    test "rejects invalid trusted domains" do
      opts = %Options{trusted_domains: ["valid.com", 123]}

      assert {:error, "Trusted domains must be a list of strings"} = Options.validate(opts)
    end

    test "rejects non-list trusted domains" do
      opts = %Options{trusted_domains: "not a list"}

      assert {:error, "Trusted domains must be a list, got: \"not a list\""} =
               Options.validate(opts)
    end
  end

  describe "option combinations" do
    test "strict validation profile" do
      opts =
        Options.new(
          validate_formats: true,
          ignore_unknown_formats: false,
          resolve_external_refs: true,
          collect_annotations: true,
          output_format: :detailed
        )

      assert {:ok, _} = Options.validate(opts)
      assert opts.validate_formats == true
      assert opts.ignore_unknown_formats == false
      assert opts.resolve_external_refs == true
      assert opts.output_format == :detailed
    end

    test "performance-optimized profile" do
      opts =
        Options.new(
          regex_engine: :regex,
          collect_annotations: false,
          stop_on_first_error: true,
          cache_compiled_schemas: true,
          output_format: :flag
        )

      assert {:ok, _} = Options.validate(opts)
      assert opts.regex_engine == :regex
      assert opts.collect_annotations == false
      assert opts.stop_on_first_error == true
      assert opts.cache_compiled_schemas == true
      assert opts.output_format == :flag
    end

    test "security-focused profile" do
      opts =
        Options.new(
          allow_remote_references: true,
          trusted_domains: ["api.trusted.com", "schemas.mycompany.org"],
          max_reference_depth: 3,
          resolve_external_refs: true
        )

      assert {:ok, _} = Options.validate(opts)
      assert opts.allow_remote_references == true
      assert opts.trusted_domains == ["api.trusted.com", "schemas.mycompany.org"]
      assert opts.max_reference_depth == 3
      assert opts.resolve_external_refs == true
    end
  end

  describe "struct field validation" do
    test "all required fields exist with correct types" do
      opts = Options.new()

      # Draft field
      assert is_atom(opts.draft)

      # Boolean fields
      assert is_boolean(opts.validate_formats)
      assert is_boolean(opts.ignore_unknown_formats)
      assert is_boolean(opts.collect_annotations)
      assert is_boolean(opts.stop_on_first_error)
      assert is_boolean(opts.resolve_external_refs)
      assert is_boolean(opts.cache_compiled_schemas)
      assert is_boolean(opts.include_schema_path)
      assert is_boolean(opts.include_instance_path)
      assert is_boolean(opts.allow_remote_references)

      # Atom fields
      assert is_atom(opts.regex_engine)
      assert is_atom(opts.output_format)

      # Numeric fields
      assert is_integer(opts.max_reference_depth)
      assert opts.max_reference_depth >= 0

      # List fields
      assert is_list(opts.trusted_domains)
    end

    test "nil-able fields accept nil values" do
      opts = Options.new(retriever: nil, reference_cache: nil)

      assert opts.retriever == nil
      assert opts.reference_cache == nil
    end
  end

  describe "profile integration" do
    test "new/1 with profile atom creates profile options" do
      strict_opts = Options.new(:strict)
      assert strict_opts.validate_formats == true
      assert strict_opts.output_format == :verbose

      lenient_opts = Options.new(:lenient)
      assert lenient_opts.validate_formats == false
      assert lenient_opts.output_format == :detailed

      perf_opts = Options.new(:performance)
      assert perf_opts.collect_annotations == false
      assert perf_opts.output_format == :basic
    end

    test "new/1 with {profile, overrides} tuple creates customized profile" do
      opts = Options.new({:strict, [output_format: :basic]})

      # Override applied
      assert opts.output_format == :basic
      # Strict character maintained
      assert opts.validate_formats == true
      assert opts.ignore_unknown_formats == false
    end

    test "profile/2 creates profile options with overrides" do
      opts = Options.profile(:performance, validate_formats: true)

      # Override applied
      assert opts.validate_formats == true
      # Performance character maintained
      assert opts.collect_annotations == false
      assert opts.stop_on_first_error == true
    end

    test "profile/1 creates profile options without overrides" do
      strict_opts = Options.profile(:strict)
      lenient_opts = Options.profile(:lenient)
      perf_opts = Options.profile(:performance)

      # Should match direct profile creation
      assert strict_opts == ExJsonschema.Profile.strict()
      assert lenient_opts == ExJsonschema.Profile.lenient()
      assert perf_opts == ExJsonschema.Profile.performance()
    end
  end
end
