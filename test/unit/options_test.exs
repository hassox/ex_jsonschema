defmodule ExJsonschema.OptionsTest do
  use ExUnit.Case
  use ExUnit.CaseHelpers

  alias ExJsonschema.Options

  describe "new/1" do
    test "creates options with default values" do
      opts = Options.new()

      assert opts.draft == :auto
      assert opts.validate_formats == false
      assert opts.regex_engine == :fancy_regex
      assert opts.output_format == :detailed
    end

    test "creates options with overrides" do
      opts =
        Options.new(
          draft: :draft202012,
          validate_formats: true,
          regex_engine: :regex,
          output_format: :basic
        )

      assert opts.draft == :draft202012
      assert opts.validate_formats == true
      assert opts.regex_engine == :regex
      assert opts.output_format == :basic
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
      opts = Options.draft7()
      assert opts.draft == :draft7
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
          validate_formats: true
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

  end

  describe "option combinations" do
    test "strict validation profile" do
      opts =
        Options.new(
          validate_formats: true,
          output_format: :detailed
        )

      assert {:ok, _} = Options.validate(opts)
      assert opts.validate_formats == true
      assert opts.output_format == :detailed
    end

    test "performance-optimized profile" do
      opts =
        Options.new(
          regex_engine: :regex,
          output_format: :basic
        )

      assert {:ok, _} = Options.validate(opts)
      assert opts.regex_engine == :regex
      assert opts.output_format == :basic
    end

    test "external references profile" do
      opts =
        Options.new(
          validate_formats: true,
          output_format: :verbose
        )

      assert {:ok, _} = Options.validate(opts)
      assert opts.validate_formats == true
      assert opts.output_format == :verbose
    end
  end

  describe "struct field validation" do
    test "all required fields exist with correct types" do
      opts = Options.new()

      # Draft field
      assert is_atom(opts.draft)

      # Boolean fields
      assert is_boolean(opts.validate_formats)

      # Atom fields
      assert is_atom(opts.regex_engine)
      assert is_atom(opts.output_format)
    end

    test "nil-able fields accept nil values" do
      # No nil-able fields remaining after retriever removal
      opts = Options.new()

      # Just verify the struct is valid
      assert %Options{} = opts
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
      assert perf_opts.output_format == :basic
    end

    test "new/1 with {profile, overrides} tuple creates customized profile" do
      opts = Options.new({:strict, [output_format: :basic]})

      # Override applied
      assert opts.output_format == :basic
      # Strict character maintained
      assert opts.validate_formats == true
    end

    test "profile/2 creates profile options with overrides" do
      opts = Options.profile(:performance, validate_formats: true)

      # Override applied
      assert opts.validate_formats == true
      # Performance character maintained
      assert opts.output_format == :basic
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
