Here's a structured Product Requirements Document (PRD) for an AI‑assisted Elixir library, idiomatically wrapping the Rust `jsonschema` crate via Rustler, shipping **precompiled NIFs**, and exposing a clean, API‑driven Elixir interface:

---

## 🎯 Goals & Overview

* **Rust-powered JSON Schema validation**: Leverage `jsonschema` crate for performance and spec completeness (supports draft2019, draft202012…) ([docs.rs][1]).
* **Elixir-first, idiomatic API**: Provide a clear, functional Elixir facade minimizing Rust exposure.
* **Zero Rust toolchain for consumers**: Use `rustler_precompiled` to publish prebuilt binaries per platform, eliminating the need for `cargo` during install ([hexdocs.pm][2]).
* **Full developer DX**: Tests, docs, CI, README, versioning, & automated release pipeline.

---

## 📦 Architecture & Components

### 1. Core NIF Module

* **Rust library** using `jsonschema` crate to:

  * Compile validator: `validator_for`, `draft202012::new`, etc.
  * Validate instances: sync & async.
  * Return structured error info.
* Expose minimal NIF methods:

  * `compile_schema(schema_json :: String.t()) :: {:ok, validator_ref} | {:error, term()}`
  * `validate(validator_ref, instance_json :: String.t()) :: :ok | {:error, errors}`
  * `is_valid?/2`, `validate_sync`, `validate_async` wrappers.

### 2. Elixir Interface

* **Module: `JsonSchema`**:

  * `compile/1`, `validate/2`, `validate!/2`, `valid?/2`.
  * Configurable draft/version/format options.
  * Error structs (with error path & message).
  * Stream validators via `Enumerable` or GenServer wrapper.

### 3. Precompiled Binaries

* **Use `rustler_precompiled`**:

  * CI builds binaries (Linux, macOS, Windows + archs, NIF versions) ([elixirforum.com][3], [crates.io][4], [docs.rs][1], [github.com][5], [hexdocs.pm][6], [hexdocs.pm][7]).
  * Publish to Hex with checksums.
  * Elixir loads correct binary per platform at install.

### 4. CI & Release Workflow

* Use GitHub Actions:

  * Matrix across targets + NIF versions ([hexdocs.pm][6], [sidhion.com][8]).
  * Build Rust artifacts, store as pipeline artifacts.
  * Validate binaries against checksum.
  * Publish via `mix hex.publish`.
  * Optional GitHub Release with artifacts.

### 5. Documentation & README

* Crisp **Quick Start**:

  ```elixir
  {:ok, v} = Jsonschema.compile(schema_json)
  case Jsonschema.validate(v, instance_json) do
    :ok -> IO.puts("valid")
    {:error, errors} -> IO.inspect(errors)
  end
  ```
* Detail installation via Hex (no Rust needed).
* Usage guides on drafts, async, custom formats/resolvers.
* API spec with typed `@spec`, examples of streaming large data.

### 6. Testing Suite

* Comprehensive Rust test harness verifying validity, meta‑schema support.
* Elixir side using sample schemas + `assert_valid?/invalid?/2`.
* Cross-version coverage: multiple `jsonschema` drafts.
* Edge cases: invalid schema, missing `$ref`, circular refs, custom format.

---

## ✅ Success Criteria

* ✅ **Zero Rust toolchain** required at install for consumers.
* ✅ Test coverage >95% in both Rust and Elixir.
* ✅ Supports at least draft‑07 and draft‑2020‑12 schemas.
* ✅ Idiomatic Elixir API with documented types and patterns.
* ✅ Automated CI publishing prebuilt NIFs.
* ✅ Benchmarks showing performance gains over pure‑Elixir implementations.

---

## 📦 Deliverables & Milestones

| Phase | Deliverable                                               | Estimated Time |
| ----- | --------------------------------------------------------- | -------------- |
| 1     | Set up Rustler NIF skeleton + basic Elixir API            | 1 week         |
| 2     | Integrate `jsonschema` crate + compile/validate NIF calls | 1 week         |
| 3     | Elixir wrapper + initial tests/docs                       | 1–2 weeks      |
| 4     | CI for precompiled binaries via `rustler_precompiled`     | 1 week         |
| 5     | Extend tests for drafts, async, edge cases                | 1 week         |
| 6     | Release v1.0 on Hex + announce                            | 2–3 days       |

---

## 🚀 Developer Experience (DX)

* **Local dev**: Full Rust rebuilds via `mix compile`.
* **End users**: Mix installs NIF binary; no Rust tooling.
* **Overrides**: Environment toggle to disable precompiled binary for development.
* **CI-friendly**: Easily extendable to custom targets (Nerves, musl, etc.) ([hexdocs.pm][6], [mainmatter.com][9], [elixirforum.com][10], [github.com][11], [github.com][5], [sidhion.com][8]).

---

## 📌 Summary

This PRD outlines the creation of an Elixir wrapper library for JSON Schema validation using Rust’s `jsonschema` crate, packaged via Rustler with precompiled NIFs for seamless installation. It ensures idiomatic Elixir usage, robust testing, and performant Rust under the hood. The CI/CD pipeline automates building and publishing, delivering a polished 1.0 release.

[1]: https://docs.rs/jsonschema?utm_source=chatgpt.com "jsonschema - Rust - Docs.rs"
[2]: https://hexdocs.pm/rustler_precompiled/?utm_source=chatgpt.com "RustlerPrecompiled — rustler_precompiled v0.8.2 - HexDocs"
[3]: https://elixirforum.com/t/is-there-a-supported-way-to-compile-cache-a-rust-dependency/45877?utm_source=chatgpt.com "Is there a supported way to compile + cache a rust dependency?"
[4]: https://crates.io/crates/jsonschema?utm_source=chatgpt.com "jsonschema - crates.io: Rust Package Registry"
[5]: https://github.com/jonasschmidt/ex_json_schema?utm_source=chatgpt.com "jonasschmidt/ex_json_schema: An Elixir JSON Schema validator"
[6]: https://hexdocs.pm/rustler_precompiled/precompilation_guide.html?utm_source=chatgpt.com "Precompilation guide — rustler_precompiled v0.8.2 - HexDocs"
[7]: https://hexdocs.pm/json_schema_nif/JsonSchemaNif.html?utm_source=chatgpt.com "JsonSchemaNif — JSON Schema NIF v0.1.1 - HexDocs"
[8]: https://sidhion.com/blog/using_rustler_nix/?utm_source=chatgpt.com "Compiling Elixir+Mix projects that use Rustler with Nix"
[9]: https://mainmatter.com/blog/2023/02/01/using-rust-crates-in-elixir/?utm_source=chatgpt.com "Rustler - Using Rust crates in Elixir - Mainmatter"
[10]: https://elixirforum.com/t/jsv-json-schema-validation-library-for-elixir-with-support-for-2020-12/68502?utm_source=chatgpt.com "JSON Schema Validation library for Elixir, with support for 2020-12"
[11]: https://github.com/macisamuele/jsonschema-validator?utm_source=chatgpt.com "macisamuele/jsonschema-validator - GitHub"
