defmodule ExJsonschema.Native do
  @moduledoc false

  version = Mix.Project.config()[:version]

  use RustlerPrecompiled,
    otp_app: :ex_jsonschema,
    crate: "ex_jsonschema",
    base_url: "https://github.com/hassox/ex_jsonschema/releases/download/v#{version}",
    force_build: System.get_env("EX_JSONSCHEMA_BUILD") in ["1", "true"],
    version: version

  @type compiled_schema :: reference()
  @type draft :: :auto | :draft4 | :draft6 | :draft7 | :draft201909 | :draft202012
  @type regex_engine :: :fancy_regex | :regex

  @type compilation_options :: %{
    draft: draft(),
    validate_formats: boolean(),
    ignore_unknown_formats: boolean(),
    collect_annotations: boolean(),
    regex_engine: regex_engine(),
    resolve_external_refs: boolean(),
    stop_on_first_error: boolean()
  }

  @type compilation_result :: {:ok, compiled_schema()} | {:error, map()}
  @type validation_result :: :ok | :error | {:error, [map()]}
  @type detection_result :: {:ok, draft()} | {:error, map()}

  # Schema compilation  
  def compile_schema(_schema_json), do: :erlang.nif_error(:nif_not_loaded)
  # TODO: Add compile_schema_with_options in future iteration
  # def compile_schema_with_options(_schema_json, _options), do: :erlang.nif_error(:nif_not_loaded)

  # Validation  
  def validate(_compiled_schema, _instance_json), do: :erlang.nif_error(:nif_not_loaded)
  def validate_detailed(_compiled_schema, _instance_json), do: :erlang.nif_error(:nif_not_loaded)
  def valid(_compiled_schema, _instance_json), do: :erlang.nif_error(:nif_not_loaded)

  # Backward compatibility
  def valid?(compiled_schema, instance_json), do: valid(compiled_schema, instance_json)
  def is_valid(compiled_schema, instance_json), do: valid(compiled_schema, instance_json)

  # Draft detection
  def detect_draft_from_schema(_schema_json), do: :erlang.nif_error(:nif_not_loaded)
end
