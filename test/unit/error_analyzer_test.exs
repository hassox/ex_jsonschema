defmodule ExJsonschema.ErrorAnalyzerTest do
  @moduledoc """
  Tests for M3.4 Error Analysis and Suggestion System.

  Tests the advanced error analysis utilities including categorization,
  severity analysis, pattern detection, and comprehensive recommendations.
  """

  use ExUnit.Case

  alias ExJsonschema.{ErrorAnalyzer, ValidationError}

  describe "analyze/1" do
    test "returns comprehensive analysis for mixed error types" do
      errors = [
        %ValidationError{keyword: "type", instance_path: "/name", message: "not string"},
        %ValidationError{keyword: "minimum", instance_path: "/age", message: "less than 18"},
        %ValidationError{keyword: "required", instance_path: "", message: "missing email"},
        %ValidationError{keyword: "format", instance_path: "/phone", message: "invalid format"}
      ]

      analysis = ErrorAnalyzer.analyze(errors)

      assert analysis.total_errors == 4
      assert analysis.categories[:type_mismatch] == 1
      assert analysis.categories[:constraint_violation] == 1
      assert analysis.categories[:structural] == 1
      assert analysis.categories[:format] == 1

      assert is_list(analysis.patterns)
      assert is_list(analysis.most_common_paths)
      assert is_list(analysis.recommendations)
      assert length(analysis.recommendations) > 0
    end

    test "handles empty error list" do
      analysis = ErrorAnalyzer.analyze([])

      assert analysis.total_errors == 0
      assert analysis.categories == %{}
      assert analysis.patterns == []
      assert analysis.most_common_paths == []
      # Should have default recommendation
      assert length(analysis.recommendations) == 1
    end

    test "detects missing properties pattern" do
      errors = [
        %ValidationError{keyword: "required", instance_path: "/user", message: "missing name"},
        %ValidationError{keyword: "required", instance_path: "/user", message: "missing email"}
      ]

      analysis = ErrorAnalyzer.analyze(errors)

      assert :missing_properties in analysis.patterns
      assert Enum.any?(analysis.recommendations, &String.contains?(&1, "required fields"))
    end

    test "detects type conflicts pattern" do
      errors = [
        %ValidationError{keyword: "type", instance_path: "/user/name", message: "not string"},
        %ValidationError{keyword: "type", instance_path: "/user/age", message: "not number"},
        %ValidationError{keyword: "type", instance_path: "/user/active", message: "not boolean"}
      ]

      analysis = ErrorAnalyzer.analyze(errors)

      assert :type_conflicts in analysis.patterns
      assert Enum.any?(analysis.recommendations, &String.contains?(&1, "type mismatches"))
    end

    test "detects range violations pattern" do
      errors = [
        %ValidationError{keyword: "minimum", instance_path: "/age", message: "too small"},
        %ValidationError{keyword: "maxLength", instance_path: "/bio", message: "too long"}
      ]

      analysis = ErrorAnalyzer.analyze(errors)

      assert :range_violations in analysis.patterns
      assert Enum.any?(analysis.recommendations, &String.contains?(&1, "range/length violations"))
    end

    test "detects format issues pattern" do
      errors = [
        %ValidationError{keyword: "format", instance_path: "/email", message: "invalid email"},
        %ValidationError{keyword: "pattern", instance_path: "/phone", message: "invalid pattern"}
      ]

      analysis = ErrorAnalyzer.analyze(errors)

      assert :format_issues in analysis.patterns
      assert Enum.any?(analysis.recommendations, &String.contains?(&1, "format violations"))
    end
  end

  describe "group_by_type/1" do
    test "groups errors by category correctly" do
      errors = [
        %ValidationError{keyword: "type", instance_path: "/name"},
        %ValidationError{keyword: "minimum", instance_path: "/age"},
        %ValidationError{keyword: "type", instance_path: "/email"},
        %ValidationError{keyword: "format", instance_path: "/phone"}
      ]

      grouped = ErrorAnalyzer.group_by_type(errors)

      assert length(grouped[:type_mismatch]) == 2
      assert length(grouped[:constraint_violation]) == 1
      assert length(grouped[:format]) == 1
    end

    test "handles unknown keywords as custom category" do
      errors = [
        %ValidationError{keyword: "customKeyword", instance_path: "/data"}
      ]

      grouped = ErrorAnalyzer.group_by_type(errors)

      assert length(grouped[:custom]) == 1
    end
  end

  describe "group_by_path/1" do
    test "groups errors by instance path" do
      errors = [
        %ValidationError{keyword: "type", instance_path: "/user/name"},
        %ValidationError{keyword: "format", instance_path: "/user/name"},
        %ValidationError{keyword: "minimum", instance_path: "/user/age"}
      ]

      grouped = ErrorAnalyzer.group_by_path(errors)

      assert length(grouped["/user/name"]) == 2
      assert length(grouped["/user/age"]) == 1
    end
  end

  describe "analyze_severity/1" do
    test "classifies severity correctly for different error types" do
      errors = [
        # critical
        %ValidationError{keyword: "type", instance_path: "/name"},
        # critical
        %ValidationError{keyword: "required", instance_path: ""},
        # high
        %ValidationError{keyword: "minimum", instance_path: "/age"},
        # medium
        %ValidationError{keyword: "format", instance_path: "/email"}
      ]

      severities = ErrorAnalyzer.analyze_severity(errors)

      assert severities[:critical] == 2
      assert severities[:high] == 1
      assert severities[:medium] == 1
    end

    test "considers root path errors as higher severity" do
      errors = [
        # high (root)
        %ValidationError{keyword: "enum", instance_path: "/"},
        # high (same keyword)
        %ValidationError{keyword: "enum", instance_path: "/user/role"}
      ]

      severities = ErrorAnalyzer.analyze_severity(errors)

      assert severities[:high] == 2
    end
  end

  describe "suggest_fixes/1" do
    test "provides specific recommendations for error patterns" do
      errors = [
        %ValidationError{keyword: "required", instance_path: "/user"},
        %ValidationError{keyword: "type", instance_path: "/name"},
        %ValidationError{keyword: "format", instance_path: "/email"}
      ]

      suggestions = ErrorAnalyzer.suggest_fixes(errors)

      assert is_list(suggestions)
      assert length(suggestions) > 0

      # Should include pattern-specific suggestions
      suggestion_text = Enum.join(suggestions, " ")
      assert String.contains?(suggestion_text, "required fields")

      assert String.contains?(suggestion_text, "data transformation") or
               String.contains?(suggestion_text, "type")

      assert String.contains?(suggestion_text, "format")
    end

    test "provides general recommendations for many errors" do
      # Create many errors to trigger high-volume recommendations
      errors =
        Enum.map(1..12, fn i ->
          %ValidationError{keyword: "type", instance_path: "/item#{i}"}
        end)

      suggestions = ErrorAnalyzer.suggest_fixes(errors)

      suggestion_text = Enum.join(suggestions, " ")

      assert String.contains?(suggestion_text, "systematic data issues") or
               String.contains?(suggestion_text, "validate data closer")
    end

    test "always provides at least one recommendation" do
      errors = [%ValidationError{keyword: "unknown", instance_path: "/test"}]

      suggestions = ErrorAnalyzer.suggest_fixes(errors)

      assert length(suggestions) >= 1
    end
  end

  describe "detect_error_patterns/1" do
    test "detects all major patterns in complex error set" do
      errors = [
        # Missing properties pattern
        %ValidationError{keyword: "required", instance_path: "/user"},

        # Type conflicts pattern
        %ValidationError{keyword: "type", instance_path: "/name"},
        %ValidationError{keyword: "type", instance_path: "/age"},

        # Range violations pattern
        %ValidationError{keyword: "minimum", instance_path: "/score"},

        # Format issues pattern
        %ValidationError{keyword: "format", instance_path: "/email"},
        %ValidationError{keyword: "pattern", instance_path: "/phone"}
      ]

      patterns = ErrorAnalyzer.detect_error_patterns(errors)

      assert :missing_properties in patterns
      assert :type_conflicts in patterns
      assert :range_violations in patterns
      assert :format_issues in patterns
    end

    test "returns empty list when no patterns detected" do
      errors = [%ValidationError{keyword: "customKeyword", instance_path: "/test"}]

      patterns = ErrorAnalyzer.detect_error_patterns(errors)

      assert patterns == []
    end
  end

  describe "summarize/1" do
    test "produces comprehensive human-readable summary" do
      errors = [
        %ValidationError{keyword: "type", instance_path: "/name"},
        %ValidationError{keyword: "required", instance_path: "/user"},
        %ValidationError{keyword: "minimum", instance_path: "/age"},
        %ValidationError{keyword: "format", instance_path: "/email"}
      ]

      summary = ErrorAnalyzer.summarize(errors)

      assert is_binary(summary)
      assert String.contains?(summary, "4 validation errors")
      assert String.contains?(summary, "Categories:")
      assert String.contains?(summary, "Severity:")
      assert String.contains?(summary, "recommendations:")

      # Should mention specific categories
      assert String.contains?(summary, "type mismatch") or String.contains?(summary, "type")
      assert String.contains?(summary, "structural") or String.contains?(summary, "required")
    end

    test "handles empty error list gracefully" do
      summary = ErrorAnalyzer.summarize([])

      assert is_binary(summary)
      assert String.contains?(summary, "0 validation errors")
    end

    test "formats patterns and recommendations correctly" do
      errors = [
        %ValidationError{keyword: "required", instance_path: "/name"},
        %ValidationError{keyword: "type", instance_path: "/age"},
        %ValidationError{keyword: "type", instance_path: "/email"}
      ]

      summary = ErrorAnalyzer.summarize(errors)

      # Should detect and mention patterns
      assert String.contains?(summary, "missing required") or
               String.contains?(summary, "type conflicts") or
               String.contains?(summary, "conflicting data types")

      # Should provide numbered recommendations
      assert String.contains?(summary, "1.")
      assert String.contains?(summary, "2.")
    end
  end

  describe "integration with real validation errors" do
    test "analyzes errors from actual validation" do
      schema = ~s({
        "type": "object",
        "required": ["name", "age", "email"],
        "properties": {
          "name": {"type": "string", "minLength": 2},
          "age": {"type": "number", "minimum": 18},
          "email": {"type": "string", "format": "email"}
        }
      })

      {:ok, validator} = ExJsonschema.compile(schema)

      # Invalid instance with multiple error types
      invalid_instance = ~s({
        "name": 1,
        "age": 15,
        "phone": "invalid-email-format"
      })

      assert {:error, errors} =
               ExJsonschema.validate(validator, invalid_instance, output: :verbose)

      # Analyze the real validation errors
      analysis = ErrorAnalyzer.analyze(errors)

      assert analysis.total_errors > 0
      assert map_size(analysis.categories) > 0
      assert map_size(analysis.severities) > 0
      assert length(analysis.recommendations) > 0

      # Should detect patterns from real errors
      patterns = ErrorAnalyzer.detect_error_patterns(errors)
      assert is_list(patterns)

      # Summary should be meaningful
      summary = ErrorAnalyzer.summarize(errors)
      assert String.contains?(summary, "validation errors")
      # Should be reasonably detailed
      assert String.length(summary) > 50
    end
  end
end
