defmodule ExJsonschema.ValidationError do
  @moduledoc """
  Represents a JSON Schema validation error with detailed path and message information.
  """

  @type t :: %__MODULE__{
          instance_path: String.t(),
          schema_path: String.t(),
          message: String.t()
        }

  defstruct [:instance_path, :schema_path, :message]

  @doc """
  Creates a ValidationError from a map returned by the NIF.
  """
  @spec from_map(map()) :: t()
  def from_map(%{"instance_path" => instance_path, "schema_path" => schema_path, "message" => message}) do
    %__MODULE__{
      instance_path: instance_path,
      schema_path: schema_path,
      message: message
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