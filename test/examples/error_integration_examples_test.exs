defmodule ExJsonschema.ErrorIntegrationExamplesTest do
  @moduledoc """
  Integration examples demonstrating error handling in real-world scenarios.

  This module provides comprehensive examples of integrating ExJsonschema error handling
  with web frameworks, databases, logging systems, and other common Elixir ecosystem
  components.

  These examples serve as both tests and documentation for M3.6 deliverable,
  showing practical integration patterns for production applications.
  """

  use ExUnit.Case, async: true
  require Logger

  alias ExJsonschema.ValidationError

  describe "Phoenix/Web Framework Integration Examples" do
    test "example 1: Phoenix controller with comprehensive error handling" do
      # Simulate Phoenix controller action with JSON Schema validation
      request_schema = ~s({
        "type": "object",
        "properties": {
          "email": {"type": "string", "format": "email"},
          "password": {"type": "string", "minLength": 8},
          "name": {"type": "string", "minLength": 2, "maxLength": 50}
        },
        "required": ["email", "password", "name"]
      })

      # Simulate invalid request params
      invalid_params = %{
        "email" => "invalid-email",
        "password" => "short",
        "name" => "X"
      }

      {:ok, validator} = ExJsonschema.compile(request_schema)
      params_json = Jason.encode!(invalid_params)

      # Phoenix controller-style error handling
      response =
        case ExJsonschema.validate(validator, params_json, output: :detailed) do
          :ok ->
            # Success response
            %{
              status: 200,
              body: %{status: "success", message: "User created successfully"}
            }

          {:error, validation_errors} ->
            # Convert to Phoenix-style changeset-like errors
            field_errors =
              Enum.reduce(validation_errors, %{}, fn error, acc ->
                field = extract_field_from_path(error.instance_path)
                message = convert_to_user_friendly_message(error)

                existing_errors = Map.get(acc, field, [])
                Map.put(acc, field, [message | existing_errors])
              end)

            # Return validation error response
            %{
              status: 422,
              body: %{
                status: "error",
                message: "Validation failed",
                errors: field_errors
              }
            }
        end

      assert response.status == 422
      assert response.body.status == "error"
      assert Map.has_key?(response.body.errors, "password")
      assert Map.has_key?(response.body.errors, "name")

      # Should have multiple validation errors
      assert map_size(response.body.errors) >= 2
    end

    test "example 2: API middleware for automatic validation" do
      # Schema for API endpoint
      endpoint_schema = ~s({
        "type": "object",
        "properties": {
          "user_id": {"type": "integer", "minimum": 1},
          "action": {"type": "string", "enum": ["create", "update", "delete"]},
          "data": {"type": "object"}
        },
        "required": ["user_id", "action"]
      })

      # Simulate middleware validation function
      validate_request = fn request_body, schema ->
        case ExJsonschema.compile(schema) do
          {:ok, validator} ->
            case ExJsonschema.validate(validator, request_body, output: :detailed) do
              :ok ->
                {:ok, Jason.decode!(request_body)}

              {:error, errors} ->
                # Format errors for API response
                api_errors = ExJsonschema.format_errors(errors, :json)
                parsed_errors = Jason.decode!(api_errors)

                {:error,
                 %{
                   type: "validation_error",
                   message: "Request validation failed",
                   details: parsed_errors,
                   count: length(errors)
                 }}
            end

          {:error, compilation_error} ->
            {:error,
             %{
               type: "schema_error",
               message: "Invalid schema configuration",
               details: compilation_error
             }}
        end
      end

      # Test invalid request
      invalid_request = ~s({
        "user_id": -1,
        "action": "invalid_action",
        "data": null
      })

      result = validate_request.(invalid_request, endpoint_schema)

      assert {:error, error_response} = result
      assert error_response.type == "validation_error"
      assert error_response.count > 0
      assert is_list(error_response.details)
    end
  end

  describe "Logging and Monitoring Integration Examples" do
    test "example 3: structured logging with error analysis" do
      # Create validation errors for logging example
      errors = create_sample_errors()

      # Analyze errors for structured logging
      analysis = ExJsonschema.analyze_errors(errors)

      # Example: Create structured log entry
      log_entry = %{
        timestamp: DateTime.utc_now(),
        level: "error",
        component: "validation",
        event: "schema_validation_failed",
        metrics: %{
          total_errors: analysis.total_errors,
          critical_errors: Map.get(analysis.severities, :critical, 0),
          high_errors: Map.get(analysis.severities, :high, 0),
          error_categories: analysis.categories
        },
        patterns: analysis.patterns,
        recommendations: Enum.take(analysis.recommendations, 3),
        context: %{
          most_common_paths: analysis.most_common_paths,
          error_distribution: analysis.categories
        }
      }

      # Simulate logging with Logger
      # Logger.error("Schema validation failed", log_entry)

      assert log_entry.event == "schema_validation_failed"
      assert log_entry.metrics.total_errors > 0
      assert is_list(log_entry.patterns)
      assert is_list(log_entry.recommendations)
    end

    test "example 4: metrics collection for monitoring" do
      errors = create_sample_errors()
      analysis = ExJsonschema.analyze_errors(errors)

      # Example: Collect metrics for monitoring system (like Telemetry)
      metrics = %{
        "validation.errors.total" => analysis.total_errors,
        "validation.errors.critical" => Map.get(analysis.severities, :critical, 0),
        "validation.errors.high" => Map.get(analysis.severities, :high, 0),
        "validation.errors.medium" => Map.get(analysis.severities, :medium, 0),
        "validation.errors.low" => Map.get(analysis.severities, :low, 0),
        "validation.categories.type_mismatch" => Map.get(analysis.categories, :type_mismatch, 0),
        "validation.categories.constraint_violation" =>
          Map.get(analysis.categories, :constraint_violation, 0),
        "validation.categories.structural" => Map.get(analysis.categories, :structural, 0),
        "validation.categories.format" => Map.get(analysis.categories, :format, 0)
      }

      # Simulate sending metrics
      # :telemetry.execute([:ex_jsonschema, :validation, :failed], metrics)

      assert metrics["validation.errors.total"] > 0
      assert is_integer(metrics["validation.errors.critical"])
      assert Map.has_key?(metrics, "validation.categories.type_mismatch")
    end
  end

  describe "Database Integration Examples" do
    test "example 5: Ecto changeset integration pattern" do
      # Simulate integrating JSON Schema validation with Ecto changeset
      user_schema = ~s({
        "type": "object",
        "properties": {
          "email": {"type": "string", "format": "email"},
          "name": {"type": "string", "minLength": 2, "maxLength": 100},
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
        "required": ["email", "name", "age"]
      })

      # Invalid user data
      invalid_data = %{
        "email" => "not-an-email",
        "name" => "X",
        "age" => 10,
        "preferences" => %{
          # should be boolean
          "newsletter" => "yes",
          # invalid enum
          "theme" => "purple",
          # additional property
          "extra" => "not allowed"
        }
      }

      # Function to add JSON Schema validation to changeset
      add_json_schema_validation = fn changeset, data, schema ->
        case ExJsonschema.compile(schema) do
          {:ok, validator} ->
            data_json = Jason.encode!(data)

            case ExJsonschema.validate(validator, data_json, output: :detailed) do
              :ok ->
                changeset

              {:error, validation_errors} ->
                # Convert JSON Schema errors to changeset errors
                Enum.reduce(validation_errors, changeset, fn error, acc ->
                  field = extract_field_from_path(error.instance_path)
                  field_atom = String.to_atom(field)
                  message = convert_to_user_friendly_message(error)

                  # Simulate Ecto.Changeset.add_error/3
                  Map.update(acc, :errors, [{field_atom, {message, []}}], fn errors ->
                    [{field_atom, {message, []}} | errors]
                  end)
                end)
            end

          {:error, _compilation_error} ->
            # Add schema compilation error
            Map.put(changeset, :errors, [{:base, {"Schema validation failed", []}}])
        end
      end

      # Simulate initial changeset
      initial_changeset = %{valid?: true, errors: []}

      # Add JSON Schema validation
      result_changeset = add_json_schema_validation.(initial_changeset, invalid_data, user_schema)

      assert length(result_changeset.errors) > 0

      # Verify specific field errors
      error_fields = Enum.map(result_changeset.errors, fn {field, _} -> field end)
      assert :name in error_fields
      assert :age in error_fields

      # Should have multiple field errors
      assert length(error_fields) >= 2
    end

    test "example 6: JSON column validation in database" do
      # Schema for JSON column data
      json_column_schema = ~s({
        "type": "object",
        "properties": {
          "settings": {
            "type": "object",
            "properties": {
              "notifications": {"type": "boolean"},
              "privacy_level": {"type": "string", "enum": ["public", "friends", "private"]},
              "language": {"type": "string", "pattern": "^[a-z]{2}$"}
            },
            "required": ["notifications", "privacy_level"]
          },
          "metadata": {
            "type": "object",
            "properties": {
              "created_at": {"type": "string", "format": "date-time"},
              "version": {"type": "integer", "minimum": 1}
            }
          }
        },
        "required": ["settings"]
      })

      # Function to validate JSON column before database insert/update
      validate_json_column = fn column_data, schema ->
        case ExJsonschema.compile(schema) do
          {:ok, validator} ->
            json_string =
              if is_binary(column_data) do
                column_data
              else
                Jason.encode!(column_data)
              end

            case ExJsonschema.validate(validator, json_string, output: :detailed) do
              :ok ->
                {:ok, Jason.decode!(json_string)}

              {:error, errors} ->
                # Create database-friendly error format
                error_summary = ExJsonschema.analyze_errors(errors, :summary)

                {:error,
                 %{
                   type: :validation_error,
                   field: :json_data,
                   message: "JSON column validation failed",
                   details: error_summary,
                   error_count: length(errors)
                 }}
            end

          {:error, compilation_error} ->
            {:error,
             %{
               type: :schema_error,
               message: "JSON schema compilation failed",
               details: compilation_error
             }}
        end
      end

      # Test with invalid JSON data
      invalid_json_data = %{
        "settings" => %{
          # should be boolean
          "notifications" => "yes",
          # invalid enum
          "privacy_level" => "custom",
          # invalid pattern
          "language" => "eng"
        },
        "metadata" => %{
          "created_at" => "not-a-date",
          # below minimum
          "version" => 0
        }
      }

      result = validate_json_column.(invalid_json_data, json_column_schema)

      assert {:error, error_data} = result
      assert error_data.type == :validation_error
      assert error_data.field == :json_data
      assert error_data.error_count > 0
    end
  end

  describe "Configuration and Environment Integration Examples" do
    test "example 7: application configuration validation at startup" do
      # Application configuration schema
      config_schema = ~s({
        "type": "object",
        "properties": {
          "database": {
            "type": "object",
            "properties": {
              "url": {"type": "string", "minLength": 10},
              "pool_size": {"type": "integer", "minimum": 1, "maximum": 100},
              "timeout": {"type": "integer", "minimum": 1000}
            },
            "required": ["url", "pool_size"]
          },
          "web": {
            "type": "object",
            "properties": {
              "port": {"type": "integer", "minimum": 1, "maximum": 65535},
              "host": {"type": "string", "minLength": 1}
            },
            "required": ["port"]
          },
          "external_services": {
            "type": "object",
            "properties": {
              "redis_url": {"type": "string", "pattern": "^redis://"},
              "api_key": {"type": "string", "minLength": 20}
            }
          }
        },
        "required": ["database", "web"]
      })

      # Function to validate application configuration
      validate_app_config = fn config ->
        # Convert config to JSON for validation
        config_json = Jason.encode!(config)

        case ExJsonschema.compile(config_schema) do
          {:ok, validator} ->
            case ExJsonschema.validate(validator, config_json, output: :verbose) do
              :ok ->
                {:ok, "Configuration is valid"}

              {:error, errors} ->
                # Format errors for startup logging
                formatted_errors = ExJsonschema.format_errors(errors, :human, color: false)
                analysis = ExJsonschema.analyze_errors(errors)

                startup_error = """
                Application Configuration Validation Failed!

                #{formatted_errors}

                Summary: #{analysis.total_errors} configuration errors found.
                Critical issues: #{Map.get(analysis.severities, :critical, 0)}

                Please fix these configuration issues before starting the application.
                """

                {:error, startup_error}
            end

          {:error, compilation_error} ->
            {:error, "Configuration schema is invalid: #{compilation_error}"}
        end
      end

      # Test with invalid configuration
      invalid_config = %{
        database: %{
          # too short
          url: "short",
          # below minimum
          pool_size: 0,
          # below minimum
          timeout: 500
        },
        web: %{
          # above maximum
          port: 99_999,
          # empty string
          host: ""
        },
        external_services: %{
          # wrong pattern
          redis_url: "invalid://url",
          # too short
          api_key: "short"
        }
      }

      result = validate_app_config.(invalid_config)

      assert {:error, error_message} = result
      assert String.contains?(error_message, "Configuration Validation Failed")
      assert String.contains?(error_message, "configuration errors found")
    end

    test "example 8: environment variable validation" do
      # Schema for environment configuration
      env_schema = ~s({
        "type": "object",
        "properties": {
          "DATABASE_URL": {"type": "string", "pattern": "^postgres://"},
          "REDIS_URL": {"type": "string", "pattern": "^redis://"},
          "SECRET_KEY_BASE": {"type": "string", "minLength": 64},
          "PORT": {"type": "string", "pattern": "^[0-9]+$"},
          "MIX_ENV": {"type": "string", "enum": ["dev", "test", "prod"]},
          "LOG_LEVEL": {"type": "string", "enum": ["debug", "info", "warn", "error"]}
        },
        "required": ["DATABASE_URL", "SECRET_KEY_BASE", "MIX_ENV"]
      })

      # Function to validate environment variables
      validate_environment = fn env_vars ->
        env_json = Jason.encode!(env_vars)

        case ExJsonschema.compile(env_schema) do
          {:ok, validator} ->
            case ExJsonschema.validate(validator, env_json, output: :detailed) do
              :ok ->
                {:ok, "Environment configuration is valid"}

              {:error, errors} ->
                # Group errors by environment variable
                errors_by_var =
                  Enum.group_by(errors, fn error ->
                    case String.split(error.instance_path, "/") do
                      ["", var] -> var
                      _ -> "unknown"
                    end
                  end)

                # Format for environment validation report
                var_reports =
                  Enum.map(errors_by_var, fn {var, var_errors} ->
                    error_messages = Enum.map_join(var_errors, ", ", & &1.message)
                    "#{var}: #{error_messages}"
                  end)

                env_error = """
                Environment Variable Validation Failed:

                #{Enum.join(var_reports, "\n")}

                Please check your environment configuration.
                """

                {:error, env_error}
            end

          {:error, compilation_error} ->
            {:error, "Environment schema compilation failed: #{compilation_error}"}
        end
      end

      # Test with invalid environment variables
      invalid_env = %{
        # wrong pattern
        "DATABASE_URL" => "mysql://invalid",
        # wrong pattern
        "REDIS_URL" => "http://wrong-protocol",
        # too short
        "SECRET_KEY_BASE" => "too_short",
        # invalid pattern
        "PORT" => "invalid_port",
        # invalid enum
        "MIX_ENV" => "development",
        # invalid enum
        "LOG_LEVEL" => "verbose"
      }

      result = validate_environment.(invalid_env)

      assert {:error, error_message} = result
      assert String.contains?(error_message, "Environment Variable Validation Failed")
      assert String.contains?(error_message, "DATABASE_URL:")
      assert String.contains?(error_message, "SECRET_KEY_BASE:")
    end
  end

  describe "Testing and Development Integration Examples" do
    test "example 9: test data validation in test suites" do
      # Schema for test fixtures
      test_user_schema = ~s({
        "type": "object",
        "properties": {
          "id": {"type": "integer", "minimum": 1},
          "username": {"type": "string", "minLength": 3, "maxLength": 20},
          "email": {"type": "string", "format": "email"},
          "profile": {
            "type": "object",
            "properties": {
              "first_name": {"type": "string", "minLength": 1},
              "last_name": {"type": "string", "minLength": 1},
              "bio": {"type": "string", "maxLength": 500}
            },
            "required": ["first_name", "last_name"]
          }
        },
        "required": ["id", "username", "email", "profile"]
      })

      # Helper function for test data validation
      validate_test_fixture = fn fixture_data, schema ->
        case ExJsonschema.compile(schema) do
          {:ok, validator} ->
            fixture_json = Jason.encode!(fixture_data)

            case ExJsonschema.validate(validator, fixture_json) do
              :ok ->
                :ok

              {:error, errors} ->
                # Format errors for test failure messages
                error_summary = ExJsonschema.analyze_errors(errors, :summary)

                flunk("""
                Test fixture validation failed:

                #{error_summary}

                Please fix the test fixture data to match the expected schema.
                """)
            end

          {:error, compilation_error} ->
            flunk("Test fixture schema compilation failed: #{compilation_error}")
        end
      end

      # Valid test fixture
      valid_user = %{
        id: 1,
        username: "testuser",
        email: "test@example.com",
        profile: %{
          first_name: "Test",
          last_name: "User",
          bio: "A test user for testing purposes"
        }
      }

      # This should pass
      assert validate_test_fixture.(valid_user, test_user_schema) == :ok

      # Invalid test fixture that would cause test failure
      # Commented out to avoid actual test failure
      # invalid_user = %{
      #   id: -1,  # invalid
      #   username: "ab",  # too short
      #   email: "not-email",  # invalid format
      #   profile: %{
      #     first_name: "",  # too short
      #     # missing last_name
      #   }
      # }
      # validate_test_fixture.(invalid_user, test_user_schema)
    end

    test "example 10: development-time schema validation warnings" do
      # Function to validate schemas during development with warnings
      validate_schema_in_development = fn schema_string ->
        case ExJsonschema.compile(schema_string) do
          {:ok, _validator} ->
            :ok

          {:error, compilation_error} ->
            warning = """
            ⚠️  Schema Compilation Warning:

            #{compilation_error}

            Please review your schema definition.
            This may cause runtime validation failures.
            """

            Logger.debug(warning)
            {:error, compilation_error}
        end
      end

      # Valid schema
      valid_schema = ~s({"type": "string", "minLength": 1})
      assert validate_schema_in_development.(valid_schema) == :ok

      # Invalid schema (but we'll handle gracefully)
      invalid_schema = ~s({"type": "invalid_type"})
      result = validate_schema_in_development.(invalid_schema)
      assert {:error, _error} = result
    end
  end

  # Helper functions

  defp create_sample_errors do
    [
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
        instance_path: "/preferences/theme",
        schema_path: "/properties/preferences/properties/theme/enum",
        keyword: "enum",
        message: "Value is not valid under any of the schemas",
        instance_value: "purple"
      }
    ]
  end

  defp extract_field_from_path(instance_path) do
    case String.split(instance_path, "/") |> Enum.reverse() |> hd() do
      "" -> "root"
      field -> field
    end
  end

  defp convert_to_user_friendly_message(
         %ValidationError{keyword: keyword, message: message} = error
       ) do
    case keyword do
      "format" ->
        if String.contains?(message, "email") do
          "Please enter a valid email address"
        else
          "Invalid format"
        end

      "minLength" ->
        "This field is too short (minimum #{error.schema_value} characters)"

      "minimum" ->
        "Value must be at least #{error.schema_value}"

      "enum" ->
        "Invalid option selected"

      "required" ->
        "This field is required"

      _ ->
        message
    end
  end
end
