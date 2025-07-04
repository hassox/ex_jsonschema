defmodule ExJsonschema.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/hassox/ex_jsonschema"
  @description "High-performance JSON Schema validation for Elixir using Rust"

  def project do
    [
      app: :ex_jsonschema,
      version: @version,
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: @description,
      package: package(),
      docs: docs(),
      rustler_crates: rustler_crates(),

      # Additional metadata for better discoverability
      name: "ExJsonschema",
      source_url: @source_url,
      homepage_url: @source_url
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:rustler, "~> 0.36"},
      {:rustler_precompiled, "~> 0.8"},
      {:jason, "~> 1.4"},
      {:ex_doc, "~> 0.27", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end

  defp package do
    [
      name: "ex_jsonschema",
      files: [
        "lib",
        "native/ex_jsonschema/.cargo",
        "native/ex_jsonschema/src",
        "native/ex_jsonschema/Cargo*",
        "checksum-*.exs",
        "mix.exs",
        "README.md",
        "LICENSE*"
      ],
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Changelog" => "#{@source_url}/blob/main/CHANGELOG.md",
        "Sponsor" => "#{@source_url}/sponsors"
      },
      maintainers: ["Daniel Neighman"],
      exclude_patterns: [".DS_Store"]
    ]
  end

  defp docs do
    [
      extras: [
        "README.md": [title: "Overview"],
        "CHANGELOG.md": [title: "Changelog"]
      ],
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @source_url,
      formatters: ["html"],
      groups_for_modules: [
        Core: [ExJsonschema],
        Errors: [ExJsonschema.ValidationError, ExJsonschema.CompilationError],
        Internal: [ExJsonschema.Native]
      ]
    ]
  end

  defp rustler_crates do
    [
      ex_jsonschema: [
        path: "native/ex_jsonschema",
        mode: rustler_mode()
      ]
    ]
  end

  defp rustler_mode do
    # Use precompiled NIFs in production, compile from source in dev
    if System.get_env("EX_JSONSCHEMA_BUILD") in ["1", "true"] or Mix.env() == :dev do
      :release
    else
      {:precompiled, "#{@source_url}/releases/download/v#{@version}"}
    end
  end
end
