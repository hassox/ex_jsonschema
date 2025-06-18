defmodule ExJsonschema.Native do
  @moduledoc false

  version = Mix.Project.config()[:version]

  use RustlerPrecompiled,
    otp_app: :ex_jsonschema,
    crate: "ex_jsonschema",
    base_url: "https://github.com/hassox/ex_jsonschema/releases/download/v#{version}",
    force_build: System.get_env("EX_JSONSCHEMA_BUILD") in ["1", "true"],
    version: version

  # When not available, Rustler will compile instead
  def compile_schema(_schema_json), do: :erlang.nif_error(:nif_not_loaded)
  def validate(_compiled_schema, _instance_json), do: :erlang.nif_error(:nif_not_loaded)
  def validate_detailed(_compiled_schema, _instance_json), do: :erlang.nif_error(:nif_not_loaded)
  def valid?(compiled_schema, instance_json), do: valid(compiled_schema, instance_json)
  def valid(_compiled_schema, _instance_json), do: :erlang.nif_error(:nif_not_loaded)
end
