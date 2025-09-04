defmodule ExJsonschema.ValidationError do
  @moduledoc """
  Represents a JSON Schema validation error with detailed path and message information.
  """

  @type t :: %__MODULE__{
          instance_path: String.t(),
          schema_path: String.t(),
          message: String.t(),
          keyword: String.t() | nil,
          instance_value: any() | nil,
          schema_value: any() | nil,
          context: map() | nil,
          annotations: map() | nil,
          suggestions: [String.t()] | nil
        }

  defstruct [
    :instance_path,
    :schema_path,
    :message,
    :keyword,
    :instance_value,
    :schema_value,
    :context,
    :annotations,
    :suggestions
  ]

  @doc """
  Creates a ValidationError from a map returned by the NIF.

  Supports both detailed format (basic fields only) and verbose format 
  (with additional context, values, and suggestions).
  """
  @spec from_map(map()) :: t()
  def from_map(error_map) when is_map(error_map) do
    %__MODULE__{
      instance_path: Map.get(error_map, "instance_path"),
      schema_path: Map.get(error_map, "schema_path"),
      message: Map.get(error_map, "message"),
      keyword: Map.get(error_map, "keyword"),
      instance_value: Map.get(error_map, "instance_value"),
      schema_value: Map.get(error_map, "schema_value"),
      context: Map.get(error_map, "context", %{}),
      annotations: Map.get(error_map, "annotations", %{}),
      suggestions: Map.get(error_map, "suggestions", [])
    }
  end

  @doc """
  Creates a detailed ValidationError (backward compatibility).
  Only includes basic error information without verbose context.
  """
  @spec from_detailed_map(map()) :: t()
  def from_detailed_map(%{
        "instance_path" => instance_path,
        "schema_path" => schema_path,
        "message" => message
      }) do
    %__MODULE__{
      instance_path: instance_path,
      schema_path: schema_path,
      message: message,
      keyword: nil,
      instance_value: nil,
      schema_value: nil,
      context: nil,
      annotations: nil,
      suggestions: nil
    }
  end

  defimpl String.Chars do
    def to_string(%ExJsonschema.ValidationError{} = error) do
      "ValidationError at #{error.instance_path}: #{error.message}"
    end
  end

  defimpl Inspect do
    def inspect(%ExJsonschema.ValidationError{} = error, _opts) do
      "#ValidationError<#{error.instance_path}: #{error.message}>"
    end
  end
end

defmodule ExJsonschema.ValidationError.Exception do
  @moduledoc """
  Exception raised when validation fails using validate!/2.
  """

  defexception [:errors]

  @type t :: %__MODULE__{
          errors: [ExJsonschema.ValidationError.t()]
        }

  def message(%__MODULE__{errors: errors}) do
    case errors do
      [error] ->
        "JSON Schema validation failed: #{error.message} at #{error.instance_path}"

      multiple_errors ->
        error_messages =
          multiple_errors
          |> Enum.map(&"#{&1.message} at #{&1.instance_path}")
          |> Enum.join("; ")

        "JSON Schema validation failed with #{length(multiple_errors)} errors: #{error_messages}"
    end
  end
end
