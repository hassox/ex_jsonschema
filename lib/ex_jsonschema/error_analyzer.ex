defmodule ExJsonschema.ErrorAnalyzer do
  @moduledoc """
  Advanced error analysis utilities for JSON Schema validation errors.

  Provides higher-level analysis and insights into validation errors including:
  - Error categorization and grouping
  - Severity analysis and prioritization
  - Pattern detection across multiple errors
  - Comprehensive fix recommendations
  - Error statistics and summaries

  ## Usage

      errors = [%ValidationError{...}, ...]

      # Get error summary
      summary = ExJsonschema.ErrorAnalyzer.analyze(errors)

      # Group errors by type
      grouped = ExJsonschema.ErrorAnalyzer.group_by_type(errors)

      # Get fix recommendations
      fixes = ExJsonschema.ErrorAnalyzer.suggest_fixes(errors)

  """

  require Logger
  alias ExJsonschema.ValidationError

  @type error_category :: :type_mismatch | :constraint_violation | :structural | :format | :custom
  @type error_severity :: :critical | :high | :medium | :low
  @type error_pattern ::
          :missing_properties | :type_conflicts | :range_violations | :format_issues

  @type error_analysis :: %{
          total_errors: non_neg_integer(),
          categories: %{error_category() => non_neg_integer()},
          severities: %{error_severity() => non_neg_integer()},
          patterns: [error_pattern()],
          most_common_paths: [String.t()],
          recommendations: [String.t()]
        }

  @type grouped_errors :: %{error_category() => [ValidationError.t()]}

  @doc """
  Analyzes a list of validation errors and returns comprehensive insights.

  ## Examples

      errors = [error1, error2, ...]
      analysis = ExJsonschema.ErrorAnalyzer.analyze(errors)

      analysis.total_errors
      #=> 2
      analysis.categories[:type_mismatch]
      #=> 1
  """
  @spec analyze([ValidationError.t()]) :: error_analysis()
  def analyze(errors) when is_list(errors) do
    Logger.debug("Starting error analysis", %{error_count: length(errors)})

    categories = categorize_errors(errors)
    severities = analyze_severities(errors)
    patterns = detect_patterns(errors)
    paths = most_common_paths(errors)
    recommendations = generate_recommendations(errors)

    Logger.info("Error analysis complete", %{
      error_count: length(errors),
      category_count: map_size(categories),
      pattern_count: length(patterns),
      recommendation_count: length(recommendations)
    })

    %{
      total_errors: length(errors),
      categories: categories,
      severities: severities,
      patterns: patterns,
      most_common_paths: paths,
      recommendations: recommendations
    }
  end

  @doc """
  Groups errors by category for easier processing.

  ## Examples

      errors = [error1, error2, ...]
      grouped = ExJsonschema.ErrorAnalyzer.group_by_type(errors)
      Map.has_key?(grouped, :type_mismatch)
      #=> true
  """
  @spec group_by_type([ValidationError.t()]) :: grouped_errors()
  def group_by_type(errors) when is_list(errors) do
    Enum.group_by(errors, &categorize_error/1)
  end

  @doc """
  Groups errors by their instance path for structural analysis.

  ## Examples

      errors = [error1, error2, ...]
      grouped = ExJsonschema.ErrorAnalyzer.group_by_path(errors)
      length(grouped["/user/name"])
      #=> 1
  """
  @spec group_by_path([ValidationError.t()]) :: %{String.t() => [ValidationError.t()]}
  def group_by_path(errors) when is_list(errors) do
    Enum.group_by(errors, & &1.instance_path)
  end

  @doc """
  Analyzes error severity and returns prioritized recommendations.

  ## Examples

      errors = [error1, error2, ...]
      severities = ExJsonschema.ErrorAnalyzer.analyze_severity(errors)
      severities[:critical] >= 0
      #=> true
  """
  @spec analyze_severity([ValidationError.t()]) :: %{error_severity() => non_neg_integer()}
  def analyze_severity(errors) when is_list(errors) do
    analyze_severities(errors)
  end

  @doc """
  Generates comprehensive fix suggestions based on error patterns.

  ## Examples

      errors = [error1, ...]
      suggestions = ExJsonschema.ErrorAnalyzer.suggest_fixes(errors)
      is_list(suggestions) && length(suggestions) > 0
      #=> true
  """
  @spec suggest_fixes([ValidationError.t()]) :: [String.t()]
  def suggest_fixes(errors) when is_list(errors) do
    generate_recommendations(errors)
  end

  @doc """
  Detects common error patterns across multiple validation errors.

  ## Examples

      errors = [error1, ...]
      patterns = ExJsonschema.ErrorAnalyzer.detect_error_patterns(errors)
      is_list(patterns)
      #=> true
  """
  @spec detect_error_patterns([ValidationError.t()]) :: [error_pattern()]
  def detect_error_patterns(errors) when is_list(errors) do
    detect_patterns(errors)
  end

  @doc """
  Returns a human-readable summary of the error analysis.

  ## Examples

      errors = [error1, error2, ...]
      summary = ExJsonschema.ErrorAnalyzer.summarize(errors)
      String.contains?(summary, "validation errors")
      #=> true
  """
  @spec summarize([ValidationError.t()]) :: String.t()
  def summarize(errors) when is_list(errors) do
    analysis = analyze(errors)

    summary_parts =
      [
        "#{analysis.total_errors} validation errors detected",
        format_category_summary(analysis.categories),
        format_severity_summary(analysis.severities),
        format_pattern_summary(analysis.patterns),
        format_top_recommendations(analysis.recommendations)
      ]
      |> Enum.reject(&(&1 == ""))

    Enum.join(summary_parts, "\n\n")
  end

  # Private helper functions

  @spec categorize_errors([ValidationError.t()]) :: %{error_category() => non_neg_integer()}
  defp categorize_errors(errors) do
    errors
    |> Enum.map(&categorize_error/1)
    |> Enum.frequencies()
  end

  @spec categorize_error(ValidationError.t()) :: error_category()
  defp categorize_error(%ValidationError{keyword: keyword}) do
    case keyword do
      k when k in ["type"] ->
        :type_mismatch

      k
      when k in [
             "minimum",
             "maximum",
             "minLength",
             "maxLength",
             "minItems",
             "maxItems",
             "multipleOf"
           ] ->
        :constraint_violation

      k when k in ["required", "additionalProperties", "properties", "items", "uniqueItems"] ->
        :structural

      k when k in ["format", "pattern", "enum", "const"] ->
        :format

      _ ->
        :custom
    end
  end

  @spec analyze_severities([ValidationError.t()]) :: %{error_severity() => non_neg_integer()}
  defp analyze_severities(errors) do
    errors
    |> Enum.map(&classify_severity/1)
    |> Enum.frequencies()
  end

  @spec classify_severity(ValidationError.t()) :: error_severity()
  defp classify_severity(%ValidationError{keyword: keyword, instance_path: path}) do
    case keyword do
      # Type mismatches are always critical
      "type" -> :critical
      # Missing required fields are critical
      "required" -> :critical
      k when k in ["minimum", "maximum", "minLength", "maxLength"] -> :high
      # Format issues can often be fixed
      k when k in ["format", "pattern"] -> :medium
      # Value must be exact
      k when k in ["enum", "const"] -> :high
      # Root errors are more severe
      _ -> if String.length(path) <= 1, do: :high, else: :medium
    end
  end

  @spec detect_patterns([ValidationError.t()]) :: [error_pattern()]
  defp detect_patterns(errors) do
    patterns = []

    # Check for missing required properties pattern
    patterns =
      if has_missing_properties?(errors), do: [:missing_properties | patterns], else: patterns

    # Check for type conflict patterns
    patterns = if has_type_conflicts?(errors), do: [:type_conflicts | patterns], else: patterns

    # Check for range/constraint violation patterns
    patterns =
      if has_range_violations?(errors), do: [:range_violations | patterns], else: patterns

    # Check for format issue patterns
    patterns = if has_format_issues?(errors), do: [:format_issues | patterns], else: patterns

    Enum.reverse(patterns)
  end

  @spec has_missing_properties?([ValidationError.t()]) :: boolean()
  defp has_missing_properties?(errors) do
    Enum.any?(errors, &(&1.keyword == "required"))
  end

  @spec has_type_conflicts?([ValidationError.t()]) :: boolean()
  defp has_type_conflicts?(errors) do
    type_errors = Enum.filter(errors, &(&1.keyword == "type"))
    length(type_errors) > 1
  end

  @spec has_range_violations?([ValidationError.t()]) :: boolean()
  defp has_range_violations?(errors) do
    range_keywords = ["minimum", "maximum", "minLength", "maxLength", "minItems", "maxItems"]
    Enum.any?(errors, &(&1.keyword in range_keywords))
  end

  @spec has_format_issues?([ValidationError.t()]) :: boolean()
  defp has_format_issues?(errors) do
    format_keywords = ["format", "pattern", "enum", "const"]
    Enum.any?(errors, &(&1.keyword in format_keywords))
  end

  @spec most_common_paths([ValidationError.t()]) :: [String.t()]
  defp most_common_paths(errors) do
    errors
    |> Enum.map(& &1.instance_path)
    |> Enum.frequencies()
    |> Enum.sort_by(&elem(&1, 1), :desc)
    |> Enum.take(5)
    |> Enum.map(&elem(&1, 0))
  end

  @spec generate_recommendations([ValidationError.t()]) :: [String.t()]
  defp generate_recommendations(errors) do
    patterns = detect_patterns(errors)
    categories = categorize_errors(errors)

    recommendations = []

    # Pattern-based recommendations
    recommendations =
      if :missing_properties in patterns do
        [
          "Review required fields - ensure all mandatory properties are included"
          | recommendations
        ]
      else
        recommendations
      end

    recommendations =
      if :type_conflicts in patterns do
        [
          "Check data types - multiple type mismatches detected, verify your data structure"
          | recommendations
        ]
      else
        recommendations
      end

    recommendations =
      if :range_violations in patterns do
        [
          "Validate constraints - multiple range/length violations found, check your data bounds"
          | recommendations
        ]
      else
        recommendations
      end

    recommendations =
      if :format_issues in patterns do
        [
          "Verify formats - format violations detected, ensure data matches expected patterns"
          | recommendations
        ]
      else
        recommendations
      end

    # Category-based recommendations
    recommendations =
      if Map.get(categories, :type_mismatch, 0) > 0 do
        ["Consider data transformation - convert values to expected types" | recommendations]
      else
        recommendations
      end

    recommendations =
      if Map.get(categories, :structural, 0) > 0 do
        ["Review object structure - check object properties and array items" | recommendations]
      else
        recommendations
      end

    # General recommendations if we have many errors
    recommendations =
      if length(errors) > 5 do
        [
          "Consider validation early - validate data closer to its source to catch issues sooner"
          | recommendations
        ]
      else
        recommendations
      end

    recommendations =
      if length(errors) > 10 do
        [
          "Implement data quality checks - high error count suggests systematic data issues"
          | recommendations
        ]
      else
        recommendations
      end

    # Always provide at least one recommendation
    if recommendations == [] do
      ["Review the validation errors above and adjust your data to match the schema requirements"]
    else
      Enum.reverse(recommendations)
    end
  end

  # Summary formatting helpers

  @spec format_category_summary(%{error_category() => non_neg_integer()}) :: String.t()
  defp format_category_summary(categories) when map_size(categories) == 0, do: ""

  defp format_category_summary(categories) do
    category_names = %{
      type_mismatch: "type mismatches",
      constraint_violation: "constraint violations",
      structural: "structural issues",
      format: "format violations",
      custom: "custom validation failures"
    }

    category_list =
      categories
      |> Enum.filter(fn {_category, count} -> count > 0 end)
      |> Enum.map(fn {category, count} ->
        name = Map.get(category_names, category, Atom.to_string(category))
        "#{count} #{name}"
      end)
      |> Enum.join(", ")

    "Categories: #{category_list}"
  end

  @spec format_severity_summary(%{error_severity() => non_neg_integer()}) :: String.t()
  defp format_severity_summary(severities) when map_size(severities) == 0, do: ""

  defp format_severity_summary(severities) do
    severity_list =
      severities
      |> Enum.filter(fn {_severity, count} -> count > 0 end)
      |> Enum.map(fn {severity, count} -> "#{count} #{severity}" end)
      |> Enum.join(", ")

    "Severity: #{severity_list}"
  end

  @spec format_pattern_summary([error_pattern()]) :: String.t()
  defp format_pattern_summary([]), do: ""

  defp format_pattern_summary(patterns) do
    pattern_names = %{
      missing_properties: "missing required properties",
      type_conflicts: "conflicting data types",
      range_violations: "constraint violations",
      format_issues: "format/pattern mismatches"
    }

    pattern_list =
      patterns
      |> Enum.map(&Map.get(pattern_names, &1, Atom.to_string(&1)))
      |> Enum.join(", ")

    "Detected patterns: #{pattern_list}"
  end

  @spec format_top_recommendations([String.t()]) :: String.t()
  defp format_top_recommendations([]), do: ""

  defp format_top_recommendations(recommendations) do
    top_3 = recommendations |> Enum.take(3) |> Enum.with_index(1)

    recommendation_lines =
      Enum.map(top_3, fn {rec, idx} ->
        "#{idx}. #{rec}"
      end)

    "Top recommendations:\n" <> Enum.join(recommendation_lines, "\n")
  end
end
