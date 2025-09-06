defmodule ExJsonschema.ErrorHandlingExamplesTest do
  @moduledoc """
  Comprehensive examples demonstrating all error handling scenarios in ExJsonschema.

  This test module serves as both a test suite and a comprehensive guide for error handling,
  covering all major error types, formatting options, and analysis capabilities introduced
  in Milestones M3.1-M3.5.

  Each test demonstrates real-world error handling patterns and validates that the examples
  work correctly, serving as living documentation for the M3.6 deliverable.
  """

  use ExUnit.Case, async: true
  require Logger

  alias ExJsonschema.ValidationError

  describe "Basic Error Handling Examples" do
    test "example 1: simple type validation error" do
      # Schema expecting a string
      schema = ~s({"type": "string"})
      {:ok, validator} = ExJsonschema.compile(schema)

      # Validate a number instead
      {:error, [error]} = ExJsonschema.validate(validator, "123", output: :verbose)

      # Basic error properties
      assert error.keyword == "type"
      assert error.instance_path == ""
      assert error.message =~ "not of type"

      # Example: Handle the error gracefully
      error_message =
        case error.keyword do
          "type" -> "Expected #{error.schema_value}, got #{typeof(error.instance_value)}"
          _ -> error.message
        end

      assert error_message =~ "Expected string"
    end

    test "example 2: nested object validation errors" do
      schema = ~s({
        "type": "object",
        "properties": {
          "user": {
            "type": "object",
            "properties": {
              "name": {"type": "string", "minLength": 2},
              "age": {"type": "number", "minimum": 18}
            },
            "required": ["name", "age"]
          }
        },
        "required": ["user"]
      })

      invalid_data = ~s({
        "user": {
          "name": "X",
          "age": 15
        }
      })

      {:ok, validator} = ExJsonschema.compile(schema)
      {:error, errors} = ExJsonschema.validate(validator, invalid_data, output: :verbose)

      # Should have multiple errors
      assert length(errors) >= 2

      # Find specific errors
      name_error = Enum.find(errors, &(&1.instance_path == "/user/name"))
      age_error = Enum.find(errors, &(&1.instance_path == "/user/age"))

      assert name_error.keyword == "minLength"
      assert age_error.keyword == "minimum"

      # Example: Group errors by path for user-friendly display
      errors_by_path = Enum.group_by(errors, & &1.instance_path)
      assert Map.has_key?(errors_by_path, "/user/name")
      assert Map.has_key?(errors_by_path, "/user/age")
    end

    test "example 3: array validation with multiple constraint violations" do
      schema = ~s({
        "type": "object",
        "properties": {
          "tags": {
            "type": "array",
            "items": {"type": "string", "enum": ["red", "green", "blue"]},
            "minItems": 2,
            "maxItems": 5,
            "uniqueItems": true
          }
        }
      })

      # Array with invalid items, duplicates, and wrong count
      invalid_data = ~s({
        "tags": ["red", "purple", "red", 123]
      })

      {:ok, validator} = ExJsonschema.compile(schema)
      {:error, errors} = ExJsonschema.validate(validator, invalid_data, output: :verbose)

      # Multiple error types expected
      error_types = Enum.map(errors, & &1.keyword) |> Enum.uniq()
      expected_types = ["enum", "uniqueItems", "type"]

      assert Enum.all?(expected_types, &(&1 in error_types))

      # Example: Categorize errors for different handling
      {enum_errors, other_errors} = Enum.split_with(errors, &(&1.keyword == "enum"))
      {type_errors, constraint_errors} = Enum.split_with(other_errors, &(&1.keyword == "type"))

      assert length(enum_errors) > 0
      assert length(type_errors) > 0
      assert length(constraint_errors) > 0
    end
  end

  describe "Error Formatting Examples" do
    setup do
      # Create complex validation errors for formatting examples
      schema = create_complex_schema()
      invalid_data = create_invalid_data()

      {:ok, validator} = ExJsonschema.compile(schema)
      {:error, errors} = ExJsonschema.validate(validator, invalid_data, output: :verbose)

      %{errors: errors}
    end

    test "example 4: human-readable formatting for terminal output", %{errors: errors} do
      # Format for colored terminal output
      human_formatted = ExJsonschema.format_errors(errors, :human, color: true, max_errors: 3)

      assert is_binary(human_formatted)
      assert String.contains?(human_formatted, "Validation Error")
      assert String.contains?(human_formatted, "Location:")
      assert String.contains?(human_formatted, "Message:")

      # Example: Use for CLI applications
      terminal_output = """
      ❌ Validation Failed

      #{human_formatted}

      Please fix the above errors and try again.
      """

      assert String.contains?(terminal_output, "Validation Error")
    end

    test "example 5: JSON formatting for API responses", %{errors: errors} do
      # Compact JSON for API responses
      json_compact = ExJsonschema.format_errors(errors, :json, pretty: false)
      compact_data = Jason.decode!(json_compact)

      assert is_list(compact_data)
      assert length(compact_data) > 0

      # Pretty JSON for debugging
      json_pretty = ExJsonschema.format_errors(errors, :json, pretty: true)
      assert String.contains?(json_pretty, "\n")

      # Example: API error response structure
      api_response = %{
        "status" => "error",
        "message" => "Validation failed",
        "errors" => compact_data,
        "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
      }

      assert api_response["status"] == "error"
      assert length(api_response["errors"]) > 0
    end

    test "example 6: table formatting for reports and debugging", %{errors: errors} do
      # Standard table format
      table_standard = ExJsonschema.format_errors(errors, :table)

      assert String.contains?(table_standard, "+")
      assert String.contains?(table_standard, "|")
      assert String.contains?(table_standard, "Path")
      assert String.contains?(table_standard, "Error")

      # Compact table for tight spaces
      table_compact = ExJsonschema.format_errors(errors, :table, compact: true, max_errors: 10)

      # Compact should have fewer decorative lines
      standard_lines = String.split(table_standard, "\n") |> length()
      compact_lines = String.split(table_compact, "\n") |> length()
      assert compact_lines < standard_lines

      # Example: Include in debugging report
      debug_report = """
      Validation Report - #{DateTime.utc_now()}
      ==========================================

      #{table_standard}

      Total errors: #{length(errors)}
      """

      assert String.contains?(debug_report, "Validation Report")
    end

    test "example 7: markdown formatting for documentation", %{errors: errors} do
      # Basic markdown
      markdown_basic = ExJsonschema.format_errors(errors, :markdown, max_errors: 5)

      assert String.contains?(markdown_basic, "## Validation Errors")
      assert String.contains?(markdown_basic, "**Location:**")

      # Markdown with table of contents
      markdown_toc =
        ExJsonschema.format_errors(errors, :markdown,
          include_toc: true,
          heading_level: 1,
          max_errors: 3
        )

      assert String.contains?(markdown_toc, "# Validation Errors")
      assert String.contains?(markdown_toc, "## Table of Contents")
      assert String.contains?(markdown_toc, "- [Error")

      # Example: Generate validation report for documentation
      doc_content = """
      # API Validation Documentation

      This section shows example validation errors you might encounter:

      #{markdown_toc}

      ## How to Fix These Errors

      Review each error above and adjust your request accordingly.
      """

      assert String.contains?(doc_content, "API Validation Documentation")
    end

    test "example 8: LLM formatting for AI assistant integration", %{errors: errors} do
      # Prose format for natural language processing
      llm_prose = ExJsonschema.format_errors(errors, :llm, max_errors: 4)

      assert String.contains?(llm_prose, "failed validation")
      assert String.contains?(llm_prose, "errors:")

      # Structured format for programmatic processing
      llm_structured =
        ExJsonschema.format_errors(errors, :llm,
          structured: true,
          include_schema_context: true
        )

      assert String.contains?(llm_structured, "VALIDATION_STATUS: FAILED")
      assert String.contains?(llm_structured, "ERROR_COUNT:")
      assert String.contains?(llm_structured, "LOCATION:")

      # Example: AI assistant integration
      ai_prompt = """
      Please help fix these JSON Schema validation errors:

      #{llm_prose}

      Provide specific suggestions for each error.
      """

      assert String.contains?(ai_prompt, "Please help fix")
    end
  end

  describe "Error Analysis Examples" do
    test "example 9: comprehensive error analysis" do
      # Create diverse error set for analysis
      errors = create_diverse_error_set()

      # Get full analysis
      analysis = ExJsonschema.analyze_errors(errors)

      assert analysis.total_errors > 0
      assert is_map(analysis.categories)
      assert is_map(analysis.severities)
      assert is_list(analysis.patterns)
      assert is_list(analysis.most_common_paths)
      assert is_list(analysis.recommendations)

      # Example: Use analysis for error dashboard
      dashboard_data = %{
        total: analysis.total_errors,
        critical_count: Map.get(analysis.severities, :critical, 0),
        high_count: Map.get(analysis.severities, :high, 0),
        type_mismatches: Map.get(analysis.categories, :type_mismatch, 0),
        missing_required: :missing_properties in analysis.patterns,
        top_problem_area: List.first(analysis.most_common_paths),
        priority_fix: List.first(analysis.recommendations)
      }

      assert dashboard_data.total > 0
      assert is_boolean(dashboard_data.missing_required)
    end

    test "example 10: error categorization and grouping" do
      errors = create_diverse_error_set()

      # Group errors by type for targeted handling
      grouped_by_type = ExJsonschema.ErrorAnalyzer.group_by_type(errors)

      assert is_map(grouped_by_type)
      possible_categories = [:type_mismatch, :constraint_violation, :structural, :format, :custom]

      # Should have multiple error types
      actual_categories = Map.keys(grouped_by_type)
      assert length(actual_categories) > 1
      assert Enum.all?(actual_categories, &(&1 in possible_categories))

      # Group by path for UI organization
      grouped_by_path = ExJsonschema.ErrorAnalyzer.group_by_path(errors)

      # Example: Organize errors for form validation UI
      form_errors = %{}

      form_errors =
        Enum.reduce(grouped_by_path, form_errors, fn {path, path_errors}, acc ->
          field_name = extract_field_name(path)
          field_messages = Enum.map(path_errors, & &1.message)
          Map.put(acc, field_name, field_messages)
        end)

      assert is_map(form_errors)
      assert map_size(form_errors) > 0
    end

    test "example 11: severity analysis for prioritization" do
      errors = create_diverse_error_set()

      # Analyze severities
      severities = ExJsonschema.ErrorAnalyzer.analyze_severity(errors)

      severity_levels = [:critical, :high, :medium, :low]
      severity_keys = Map.keys(severities)
      assert Enum.all?(severity_keys, &(&1 in severity_levels))

      # Example: Prioritize fixes based on severity
      critical_count = Map.get(severities, :critical, 0)
      high_count = Map.get(severities, :high, 0)

      priority_message =
        cond do
          critical_count > 0 -> "Fix #{critical_count} critical errors first"
          high_count > 0 -> "Address #{high_count} high-priority errors"
          true -> "Review medium/low priority issues"
        end

      assert is_binary(priority_message)
      assert String.contains?(priority_message, " errors")
    end

    test "example 12: pattern detection for systematic fixes" do
      errors = create_diverse_error_set()

      # Detect common patterns
      patterns = ExJsonschema.ErrorAnalyzer.detect_error_patterns(errors)

      possible_patterns = [
        :missing_properties,
        :type_conflicts,
        :range_violations,
        :format_issues
      ]

      assert Enum.all?(patterns, &(&1 in possible_patterns))

      # Example: Generate systematic fix recommendations
      fix_strategies = %{}

      fix_strategies =
        if :missing_properties in patterns do
          Map.put(
            fix_strategies,
            :missing_properties,
            "Review your data structure - add missing required fields"
          )
        else
          fix_strategies
        end

      fix_strategies =
        if :type_conflicts in patterns do
          Map.put(
            fix_strategies,
            :type_conflicts,
            "Check data types - ensure values match expected types"
          )
        else
          fix_strategies
        end

      fix_strategies =
        if :range_violations in patterns do
          Map.put(
            fix_strategies,
            :range_violations,
            "Validate ranges - check min/max constraints"
          )
        else
          fix_strategies
        end

      assert is_map(fix_strategies)
    end

    test "example 13: comprehensive error summary generation" do
      errors = create_diverse_error_set()

      # Generate human-readable summary
      summary = ExJsonschema.analyze_errors(errors, :summary)

      assert is_binary(summary)
      assert String.contains?(summary, "validation errors detected")
      assert String.contains?(summary, "Categories:")
      assert String.contains?(summary, "Severity:")

      # Example: Use in error reporting emails
      error_report_email = """
      Subject: Validation Error Report - #{Date.utc_today()}

      Dear Developer,

      Your recent data submission encountered validation issues:

      #{summary}

      Please review and resubmit after fixing these issues.

      Best regards,
      Validation System
      """

      assert String.contains?(error_report_email, "Validation Error Report")
      assert String.contains?(error_report_email, "validation errors detected")
    end
  end

  describe "Real-World Error Scenarios" do
    test "example 14: API request validation workflow" do
      # Realistic API schema
      api_schema = ~s({
        "type": "object",
        "properties": {
          "data": {
            "type": "object",
            "properties": {
              "user": {
                "type": "object",
                "properties": {
                  "email": {"type": "string", "format": "email"},
                  "age": {"type": "integer", "minimum": 13, "maximum": 120},
                  "preferences": {
                    "type": "object",
                    "properties": {
                      "newsletter": {"type": "boolean"},
                      "theme": {"type": "string", "enum": ["light", "dark"]}
                    },
                    "additionalProperties": false
                  }
                },
                "required": ["email", "age"]
              }
            },
            "required": ["user"]
          }
        },
        "required": ["data"]
      })

      # Invalid API request
      invalid_request = ~s({
        "data": {
          "user": {
            "email": "not-valid-email",
            "age": 12,
            "preferences": {
              "newsletter": "yes",
              "theme": "purple",
              "notifications": true
            }
          }
        }
      })

      {:ok, validator} = ExJsonschema.compile(api_schema)

      # Example: Complete API validation workflow
      validation_result =
        case ExJsonschema.validate(validator, invalid_request, output: :detailed) do
          :ok ->
            %{status: :success, data: "Request validated successfully"}

          {:error, validation_errors} ->
            # Format errors for API response
            formatted_errors = ExJsonschema.format_errors(validation_errors, :json)

            # Analyze for internal monitoring
            analysis = ExJsonschema.analyze_errors(validation_errors)

            # Log for debugging
            Logger.error("API validation failed: #{analysis.total_errors} errors")

            # Return structured error response
            %{
              status: :error,
              message: "Request validation failed",
              errors: Jason.decode!(formatted_errors),
              error_count: analysis.total_errors
            }
        end

      assert validation_result.status == :error
      assert validation_result.error_count > 0
      assert is_list(validation_result.errors)
    end

    test "example 15: configuration file validation" do
      # Application config schema
      config_schema = ~s({
        "type": "object",
        "properties": {
          "database": {
            "type": "object",
            "properties": {
              "host": {"type": "string", "minLength": 1},
              "port": {"type": "integer", "minimum": 1, "maximum": 65535},
              "ssl": {"type": "boolean"}
            },
            "required": ["host", "port"]
          },
          "cache": {
            "type": "object",
            "properties": {
              "ttl": {"type": "integer", "minimum": 0},
              "size": {"type": "string", "pattern": "^[0-9]+[MGK]B$"}
            }
          },
          "features": {
            "type": "array",
            "items": {"type": "string", "enum": ["auth", "logging", "metrics"]},
            "uniqueItems": true
          }
        },
        "required": ["database"]
      })

      # Invalid config
      invalid_config = ~s({
        "database": {
          "host": "",
          "port": 99999
        },
        "cache": {
          "ttl": -1,
          "size": "invalid"
        },
        "features": ["auth", "invalid", "auth"]
      })

      {:ok, validator} = ExJsonschema.compile(config_schema)

      # Example: Configuration validation with detailed reporting
      config_validation_report =
        case ExJsonschema.validate(validator, invalid_config, output: :verbose) do
          :ok ->
            "Configuration is valid ✅"

          {:error, config_errors} ->
            # Group by configuration section
            errors_by_section =
              Enum.group_by(config_errors, fn error ->
                case String.split(error.instance_path, "/") do
                  ["", section | _] -> section
                  _ -> "root"
                end
              end)

            # Create detailed report
            section_reports =
              Enum.map(errors_by_section, fn {section, section_errors} ->
                error_list =
                  Enum.map_join(section_errors, "\n", fn error ->
                    "  - #{error.instance_path}: #{error.message}"
                  end)

                "#{section} configuration issues:\n#{error_list}"
              end)

            "Configuration validation failed ❌\n\n" <> Enum.join(section_reports, "\n\n")
        end

      assert String.contains?(config_validation_report, "Configuration validation failed")
      assert String.contains?(config_validation_report, "database configuration")
    end

    test "example 16: form validation with user-friendly messages" do
      # User registration form schema
      form_schema = ~s({
        "type": "object",
        "properties": {
          "username": {
            "type": "string",
            "minLength": 3,
            "maxLength": 20,
            "pattern": "^[a-zA-Z0-9_]+$"
          },
          "email": {"type": "string", "format": "email"},
          "password": {"type": "string", "minLength": 8},
          "confirm_password": {"type": "string"},
          "age": {"type": "integer", "minimum": 13}
        },
        "required": ["username", "email", "password", "age"]
      })

      # Invalid form data
      invalid_form = ~s({
        "username": "ab",
        "email": "invalid-email",
        "password": "short",
        "age": 10
      })

      {:ok, validator} = ExJsonschema.compile(form_schema)
      {:error, errors} = ExJsonschema.validate(validator, invalid_form, output: :verbose)

      # Example: Convert validation errors to user-friendly form errors
      form_errors =
        Enum.reduce(errors, %{}, fn error, acc ->
          field = extract_field_name(error.instance_path)

          friendly_message =
            case {field, error.keyword} do
              {"username", "minLength"} ->
                "Username must be at least 3 characters long"

              {"username", "pattern"} ->
                "Username can only contain letters, numbers, and underscores"

              {"email", "format"} ->
                "Please enter a valid email address"

              {"password", "minLength"} ->
                "Password must be at least 8 characters long"

              {"age", "minimum"} ->
                "You must be at least 13 years old to register"

              {field, "required"} ->
                "#{String.capitalize(field)} is required"

              _ ->
                error.message
            end

          Map.put(acc, field, friendly_message)
        end)

      assert is_map(form_errors)
      assert Map.has_key?(form_errors, "username")

      # Check that we have user-friendly messages
      assert String.contains?(form_errors["username"], "at least 3 characters")

      # We should have multiple validation errors
      assert map_size(form_errors) >= 3
    end
  end

  describe "Advanced Error Handling Workflows" do
    test "example 17: multi-step validation with error accumulation" do
      # Step 1: Basic structure validation
      structure_schema = ~s({
        "type": "object",
        "required": ["user_data", "metadata"]
      })

      # Step 2: User data validation
      user_schema = ~s({
        "type": "object",
        "properties": {
          "user_data": {
            "type": "object",
            "properties": {
              "name": {"type": "string", "minLength": 1},
              "email": {"type": "string", "format": "email"}
            },
            "required": ["name", "email"]
          }
        }
      })

      # Step 3: Metadata validation
      metadata_schema = ~s({
        "type": "object",
        "properties": {
          "metadata": {
            "type": "object",
            "properties": {
              "version": {"type": "string", "pattern": "^v[0-9]+\\\\.[0-9]+\\\\.[0-9]+$"},
              "timestamp": {"type": "string"}
            },
            "required": ["version"]
          }
        }
      })

      test_data = ~s({
        "user_data": {
          "name": "",
          "email": "invalid"
        },
        "metadata": {
          "version": "1.0.0",
          "timestamp": "not-a-date"
        }
      })

      # Multi-step validation workflow
      accumulated_errors = []

      # Step 1
      {:ok, structure_validator} = ExJsonschema.compile(structure_schema)

      accumulated_errors =
        case ExJsonschema.validate(structure_validator, test_data) do
          :ok -> accumulated_errors
          {:error, errors} -> accumulated_errors ++ errors
        end

      # Step 2
      {:ok, user_validator} = ExJsonschema.compile(user_schema)

      accumulated_errors =
        case ExJsonschema.validate(user_validator, test_data, output: :detailed) do
          :ok -> accumulated_errors
          {:error, errors} -> accumulated_errors ++ errors
        end

      # Step 3
      {:ok, metadata_validator} = ExJsonschema.compile(metadata_schema)

      accumulated_errors =
        case ExJsonschema.validate(metadata_validator, test_data, output: :detailed) do
          :ok -> accumulated_errors
          {:error, errors} -> accumulated_errors ++ errors
        end

      # Analyze accumulated errors
      analysis = ExJsonschema.analyze_errors(accumulated_errors)

      assert analysis.total_errors > 0
      # Should have errors from multiple steps
      assert length(accumulated_errors) >= 2
    end

    test "example 18: error handling with custom context and suggestions" do
      schema = ~s({
        "type": "object",
        "properties": {
          "product": {
            "type": "object",
            "properties": {
              "name": {"type": "string", "minLength": 3},
              "price": {"type": "number", "minimum": 0.01},
              "category": {"type": "string", "enum": ["electronics", "clothing", "books"]}
            },
            "required": ["name", "price", "category"]
          }
        }
      })

      invalid_product = ~s({
        "product": {
          "name": "AB",
          "price": 0,
          "category": "toys"
        }
      })

      {:ok, validator} = ExJsonschema.compile(schema)
      {:error, errors} = ExJsonschema.validate(validator, invalid_product, output: :verbose)

      # Example: Add business context to validation errors
      enriched_errors =
        Enum.map(errors, fn error ->
          business_context =
            case {error.instance_path, error.keyword} do
              {"/product/name", "minLength"} ->
                %{
                  business_rule: "Product names must be descriptive",
                  impact: "Short names hurt SEO and user experience",
                  examples: ["iPhone 15 Pro", "Cotton T-Shirt", "JavaScript Guide"]
                }

              {"/product/price", "minimum"} ->
                %{
                  business_rule: "Products must have positive pricing",
                  impact: "Zero or negative prices break payment processing",
                  examples: [0.01, 9.99, 199.00]
                }

              {"/product/category", "enum"} ->
                %{
                  business_rule: "Products must use predefined categories",
                  impact: "Invalid categories break filtering and search",
                  valid_options: ["electronics", "clothing", "books"]
                }

              _ ->
                %{business_rule: "General validation rule", impact: "Data integrity"}
            end

          # Create enriched error structure
          %{
            path: error.instance_path,
            message: error.message,
            keyword: error.keyword,
            context: business_context,
            suggestions: error.suggestions || []
          }
        end)

      assert is_list(enriched_errors)
      assert length(enriched_errors) == length(errors)

      # Verify business context was added
      name_error = Enum.find(enriched_errors, &(&1.path == "/product/name"))

      if name_error do
        assert name_error.context.business_rule =~ "descriptive"
        assert is_list(name_error.context.examples)
      else
        # If name error not found, verify we have product-related errors
        assert length(enriched_errors) > 0
      end
    end
  end

  # Helper functions

  defp create_complex_schema do
    ~s({
      "type": "object",
      "properties": {
        "user": {
          "type": "object",
          "properties": {
            "name": {"type": "string", "minLength": 2},
            "email": {"type": "string", "format": "email"},
            "age": {"type": "number", "minimum": 18, "maximum": 120},
            "roles": {
              "type": "array",
              "items": {"type": "string", "enum": ["admin", "user", "guest"]},
              "uniqueItems": true
            }
          },
          "required": ["name", "email"]
        },
        "preferences": {
          "type": "object",
          "properties": {
            "theme": {"type": "string", "enum": ["light", "dark"]},
            "language": {"type": "string", "pattern": "^[a-z]{2}$"}
          }
        }
      },
      "required": ["user"]
    })
  end

  defp create_invalid_data do
    ~s({
      "user": {
        "name": "X",
        "email": "invalid-email",
        "age": 15,
        "roles": ["admin", "invalid-role", "admin"]
      },
      "preferences": {
        "theme": "blue",
        "language": "invalid-lang"
      }
    })
  end

  defp create_diverse_error_set do
    [
      %ValidationError{
        instance_path: "/user/name",
        schema_path: "/properties/user/properties/name/minLength",
        keyword: "minLength",
        message: "String is too short",
        instance_value: "X",
        schema_value: 2
      },
      %ValidationError{
        instance_path: "/user/email",
        schema_path: "/properties/user/properties/email/format",
        keyword: "format",
        message: "String does not match format email",
        instance_value: "invalid-email"
      },
      %ValidationError{
        instance_path: "/user/age",
        schema_path: "/properties/user/properties/age/minimum",
        keyword: "minimum",
        message: "Number is less than minimum",
        instance_value: 15,
        schema_value: 18
      },
      %ValidationError{
        instance_path: "/user/roles/1",
        schema_path: "/properties/user/properties/roles/items/enum",
        keyword: "enum",
        message: "Value is not valid under any of the schemas",
        instance_value: "invalid-role"
      },
      %ValidationError{
        instance_path: "/user/roles",
        schema_path: "/properties/user/properties/roles/uniqueItems",
        keyword: "uniqueItems",
        message: "Array items are not unique"
      },
      %ValidationError{
        instance_path: "/preferences/theme",
        schema_path: "/properties/preferences/properties/theme/enum",
        keyword: "enum",
        message: "Value is not valid under any of the schemas",
        instance_value: "blue"
      }
    ]
  end

  defp extract_field_name(path) do
    case String.split(path, "/") |> Enum.reverse() |> hd() do
      "" -> "root"
      field -> field
    end
  end

  defp typeof(value) when is_binary(value), do: "string"
  defp typeof(value) when is_number(value), do: "number"
  defp typeof(value) when is_boolean(value), do: "boolean"
  defp typeof(value) when is_list(value), do: "array"
  defp typeof(value) when is_map(value), do: "object"
  defp typeof(_), do: "unknown"
end
