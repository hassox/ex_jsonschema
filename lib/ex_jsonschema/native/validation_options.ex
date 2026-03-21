defmodule ExJsonschema.Native.ValidationOptions do
  @moduledoc """
  Native validation options struct for passing options to Rust jsonschema library.

  This struct maps directly to the Rust ValidationOptionsStruct and allows
  fine-grained control over validation behavior including security settings.
  """

  @type t :: %__MODULE__{
          draft: atom(),
          validate_formats: boolean(),
          regex_engine: atom(),
          external_schemas_mode: atom()
        }

  defstruct draft: :auto,
            validate_formats: false,
            regex_engine: :fancy_regex,
            external_schemas_mode: :ignore

  @doc """
  Convert ExJsonschema.Options to native validation options.

  This is the single transformation point - all Options get converted here.
  """
  def from_options(%ExJsonschema.Options{} = opts) do
    mode =
      case opts.external_schemas do
        :ignore -> :ignore
        :http -> :http
        # When a map or ref_resolver is used, the Elixir layer handles resolution
        # and passes pre-resolved schemas via a separate NIF. Mode is irrelevant.
        _ -> :ignore
      end

    %__MODULE__{
      draft: opts.draft,
      validate_formats: opts.validate_formats,
      regex_engine: opts.regex_engine,
      external_schemas_mode: mode
    }
  end
end
