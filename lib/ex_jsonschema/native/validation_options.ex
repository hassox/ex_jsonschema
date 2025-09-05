defmodule ExJsonschema.Native.ValidationOptions do
  @moduledoc """
  Native validation options struct for passing options to Rust jsonschema library.

  This struct maps directly to the Rust ValidationOptionsStruct and allows
  fine-grained control over validation behavior including security settings.
  """

  @type t :: %__MODULE__{
          draft: atom(),
          validate_formats: boolean(),
          ignore_unknown_formats: boolean(),
          collect_annotations: boolean(),
          regex_engine: atom(),
          resolve_external_refs: boolean(),
          stop_on_first_error: boolean()
        }

  defstruct draft: :auto,
            validate_formats: false,
            ignore_unknown_formats: true,
            collect_annotations: true,
            regex_engine: :fancy_regex,
            resolve_external_refs: false,
            stop_on_first_error: false

  @doc """
  Convert ExJsonschema.Options to native validation options.

  This is the single transformation point - all Options get converted here.
  """
  def from_options(%ExJsonschema.Options{} = opts) do
    %__MODULE__{
      draft: opts.draft,
      validate_formats: opts.validate_formats,
      ignore_unknown_formats: opts.ignore_unknown_formats,
      collect_annotations: opts.collect_annotations,
      regex_engine: opts.regex_engine,
      resolve_external_refs: opts.resolve_external_refs,
      stop_on_first_error: opts.stop_on_first_error
    }
  end
end
