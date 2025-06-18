defmodule ExJsonschema.CompilationError do
  @moduledoc """
  Represents an error that occurred during JSON Schema compilation.

  This struct provides detailed information about what went wrong during 
  schema compilation, including the error type, message, and any additional context.
  """

  @type t :: %__MODULE__{
          type: :json_parse_error | :schema_validation_error | :compilation_error,
          message: String.t(),
          details: String.t() | nil
        }

  defstruct [:type, :message, :details]

  @doc """
  Creates a CompilationError from a map returned by the NIF.
  """
  @spec from_map(map()) :: t()
  def from_map(%{"type" => type_str, "message" => message, "details" => details}) do
    type =
      case type_str do
        "json_parse_error" -> :json_parse_error
        "schema_validation_error" -> :schema_validation_error
        "compilation_error" -> :compilation_error
        _ -> :compilation_error
      end

    %__MODULE__{
      type: type,
      message: message,
      details: details
    }
  end

  def from_map(%{"type" => type_str, "message" => message}) do
    from_map(%{"type" => type_str, "message" => message, "details" => nil})
  end

  defimpl String.Chars do
    def to_string(%ExJsonschema.CompilationError{type: type, message: message, details: nil}) do
      "CompilationError(#{type}): #{message}"
    end

    def to_string(%ExJsonschema.CompilationError{type: type, message: message, details: details}) do
      "CompilationError(#{type}): #{message}\nDetails: #{details}"
    end
  end

  defimpl Inspect do
    def inspect(%ExJsonschema.CompilationError{} = error, _opts) do
      "#CompilationError<#{error.type}: #{error.message}>"
    end
  end
end
