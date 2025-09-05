defmodule ExJsonschema.TestFixtures do
  @moduledoc """
  Centralized test data and fixtures for ExJsonschema testing.

  Provides:
  - Common schema definitions
  - Valid and invalid test instances
  - Complex nested schemas for integration testing
  """

  @doc """
  Returns a collection of valid JSON schemas for testing.
  """
  def valid_schemas do
    [
      # Basic type schemas
      ~s({"type": "string"}),
      ~s({"type": "number"}),
      ~s({"type": "integer"}),
      ~s({"type": "boolean"}),
      ~s({"type": "null"}),
      ~s({"type": "array"}),
      ~s({"type": "object"}),

      # Schemas with constraints
      ~s({"type": "string", "minLength": 1, "maxLength": 10}),
      ~s({"type": "number", "minimum": 0, "maximum": 100}),
      ~s({"type": "integer", "multipleOf": 5}),
      ~s({"type": "array", "minItems": 1, "maxItems": 5, "items": {"type": "string"}}),

      # Object schemas
      ~s({
        "type": "object",
        "properties": {
          "name": {"type": "string"},
          "age": {"type": "integer", "minimum": 0}
        },
        "required": ["name"],
        "additionalProperties": false
      }),

      # Enum schemas
      ~s({"enum": ["red", "green", "blue"]}),
      ~s({"type": "string", "enum": ["small", "medium", "large"]}),

      # Pattern schemas
      ~s({"type": "string", "pattern": "^[a-z]+$"}),

      # Format schemas
      ~s({"type": "string", "format": "email"}),
      ~s({"type": "string", "format": "date-time"}),

      # Conditional schemas
      ~s({
        "type": "object",
        "properties": {
          "type": {"enum": ["person", "company"]},
          "name": {"type": "string"}
        },
        "if": {"properties": {"type": {"const": "person"}}},
        "then": {
          "properties": {
            "age": {"type": "integer", "minimum": 0}
          },
          "required": ["age"]
        }
      }),

      # Array tuple validation
      ~s({
        "type": "array",
        "prefixItems": [
          {"type": "string"},
          {"type": "number"}
        ]
      })
    ]
  end

  @doc """
  Returns schemas that should fail compilation.
  """
  def invalid_schemas do
    [
      # Invalid JSON
      ~s({"type": "string),
      ~s({"type": string"}),

      # Invalid schema structure
      ~s({"type": "invalid_type"}),
      ~s({"type": ["string", "invalid"]}),
      ~s({"minimum": "not_a_number"}),
      ~s({"properties": "not_an_object"}),
      # conflicting keywords
      ~s({"items": true, "prefixItems": [{"type": "string"}]}),

      # Invalid format
      ~s({"format": 123}),
      ~s({"pattern": 123})
    ]
  end

  @doc """
  Returns test instances for basic type validation.
  """
  def basic_instances do
    %{
      strings: [~s("hello"), ~s(""), ~s("123"), ~s("true")],
      numbers: [~s(42), ~s(3.14), ~s(0), ~s(-1.5)],
      integers: [~s(42), ~s(0), ~s(-123)],
      booleans: [~s(true), ~s(false)],
      nulls: [~s(null)],
      arrays: [~s([]), ~s([1, 2, 3]), ~s(["a", "b"]), ~s([null])],
      objects: [~s({}), ~s({"key": "value"}), ~s({"nested": {"key": "value"}})],

      # Invalid instances
      invalid_json: [~s({"key": value}), ~s([1, 2,]), ~s(undefined)]
    }
  end

  @doc """
  Returns complex nested schema for integration testing.
  """
  def complex_schema do
    ~s({
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "type": "object",
      "properties": {
        "user": {
          "type": "object",
          "properties": {
            "id": {"type": "integer", "minimum": 1},
            "profile": {
              "type": "object",
              "properties": {
                "name": {"type": "string", "minLength": 1},
                "email": {"type": "string", "format": "email"},
                "contacts": {
                  "type": "array",
                  "items": {
                    "type": "object",
                    "properties": {
                      "type": {"enum": ["phone", "email", "address"]},
                      "value": {"type": "string", "minLength": 1}
                    },
                    "required": ["type", "value"]
                  }
                }
              },
              "required": ["name", "email"]
            }
          },
          "required": ["id", "profile"]
        },
        "metadata": {
          "type": "object",
          "additionalProperties": true
        }
      },
      "required": ["user"],
      "additionalProperties": false
    })
  end

  @doc """
  Returns valid instances for the complex schema.
  """
  def complex_valid_instances do
    [
      ~s({
        "user": {
          "id": 123,
          "profile": {
            "name": "John Doe",
            "email": "john@example.com",
            "contacts": [
              {"type": "phone", "value": "555-1234"},
              {"type": "email", "value": "john.doe@work.com"}
            ]
          }
        },
        "metadata": {
          "created_at": "2024-01-01T00:00:00Z",
          "custom_field": "value"
        }
      }),
      ~s({
        "user": {
          "id": 1,
          "profile": {
            "name": "Jane",
            "email": "jane@test.org"
          }
        }
      })
    ]
  end

  @doc """
  Returns invalid instances for the complex schema.
  """
  def complex_invalid_instances do
    [
      # Missing required user
      ~s({"metadata": {}}),

      # Invalid user id
      ~s({
        "user": {
          "id": 0,
          "profile": {"name": "John", "email": "john@example.com"}
        }
      }),

      # Invalid email format
      ~s({
        "user": {
          "id": 1,
          "profile": {"name": "John", "email": "not-an-email"}
        }
      }),

      # Missing required profile fields
      ~s({
        "user": {
          "id": 1,
          "profile": {"name": "John"}
        }
      }),

      # Additional property at root level
      ~s({
        "user": {
          "id": 1,
          "profile": {"name": "John", "email": "john@example.com"}
        },
        "extra": "not allowed"
      }),

      # Invalid contact format
      ~s({
        "user": {
          "id": 1,
          "profile": {
            "name": "John",
            "email": "john@example.com",
            "contacts": [
              {"type": "invalid", "value": "test"}
            ]
          }
        }
      })
    ]
  end

  @doc """
  Returns performance test data - large arrays and objects.
  """
  def performance_data do
    large_array = 1..1000 |> Enum.map(&"item_#{&1}") |> Jason.encode!()

    large_object =
      1..100
      |> Map.new(&{"key_#{&1}", "value_#{&1}"})
      |> Jason.encode!()

    %{
      large_array: large_array,
      large_object: large_object,
      nested_array: Jason.encode!([large_array, large_array, large_array])
    }
  end

  @doc """
  Returns schemas with different draft specifications.
  """
  def draft_schemas do
    %{
      draft4: ~s({
        "$schema": "http://json-schema.org/draft-04/schema#",
        "type": "object",
        "properties": {
          "name": {"type": "string"}
        }
      }),
      draft6: ~s({
        "$schema": "http://json-schema.org/draft-06/schema#",
        "type": "object",
        "properties": {
          "name": {"type": "string"},
          "tags": {"type": "array", "contains": {"type": "string"}}
        }
      }),
      draft7: ~s({
        "$schema": "http://json-schema.org/draft-07/schema#",
        "type": "object",
        "if": {"properties": {"type": {"const": "user"}}},
        "then": {"required": ["name"]},
        "else": {"required": ["title"]}
      }),
      draft201909: ~s({
        "$schema": "https://json-schema.org/draft/2019-09/schema",
        "type": "object",
        "properties": {
          "items": {
            "type": "array",
            "items": {"type": "string"}
          }
        }
      }),
      draft202012: ~s({
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "type": "object",
        "properties": {
          "coords": {
            "type": "array",
            "prefixItems": [
              {"type": "number"},
              {"type": "number"}
            ]
          }
        }
      })
    }
  end
end
