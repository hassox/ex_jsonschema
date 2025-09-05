defmodule ExJsonschema.Native.ValidationOptions do
  @moduledoc """
  Native validation options struct for passing options to Rust jsonschema library.

  This struct maps directly to the Rust ValidationOptionsStruct and allows
  fine-grained control over validation behavior including security settings.
  """

  @type t :: %__MODULE__{
          draft: atom(),
          validate_formats: boolean(),
          regex_engine: atom()
        }

  defstruct draft: :auto,
            validate_formats: false,
            regex_engine: :fancy_regex

  @doc """
  Convert ExJsonschema.Options to native validation options.

  This is the single transformation point - all Options get converted here.
  """
  def from_options(%ExJsonschema.Options{} = opts) do
    %__MODULE__{
      draft: opts.draft,
      validate_formats: opts.validate_formats,
      regex_engine: opts.regex_engine
    }
  end
end
