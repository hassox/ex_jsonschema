defmodule ExJsonschema.DraftDetector do
  @moduledoc """
  Automatic JSON Schema draft detection and selection utilities.

  This module provides functionality to automatically detect JSON Schema draft versions
  from schema documents and work with supported draft specifications. The primary
  draft detection logic is implemented in Rust for performance and correctness, with
  this module serving as a convenient Elixir wrapper.

  ## Supported Drafts

  - Draft 4 (2013)
  - Draft 6 (2017) 
  - Draft 7 (2019)
  - Draft 2019-09
  - Draft 2020-12 (default)

  ## Examples

      # Automatic draft detection from schema documents
      schema = %{
        "$schema" => "http://json-schema.org/draft-07/schema#",
        "type" => "object"
      }
      {:ok, :draft7} = DraftDetector.detect_draft(schema)

      # Detection from JSON strings
      json = ~s({"$schema": "https://json-schema.org/draft/2020-12/schema"})
      {:ok, :draft202012} = DraftDetector.detect_draft(json)

      # Utility functions
      DraftDetector.supports_draft?(:draft7) #=> true
      DraftDetector.draft_url(:draft202012) #=> "https://json-schema.org/draft/2020-12/schema"

  """

  require Logger
  alias ExJsonschema.Native

  @type draft :: :draft4 | :draft6 | :draft7 | :draft201909 | :draft202012
  @type schema :: map() | String.t()
  @type detection_result :: {:ok, draft()} | {:error, String.t()}

  # Default draft to use when no $schema is present or detection fails
  @default_draft :draft202012

  # Supported JSON Schema draft versions
  @supported_drafts [:draft4, :draft6, :draft7, :draft201909, :draft202012]

  # Mapping of schema URLs to draft atoms
  @schema_url_mappings %{
    # Draft 4
    "http://json-schema.org/draft-04/schema" => :draft4,
    "http://json-schema.org/draft-04/schema#" => :draft4,
    # Legacy
    "http://json-schema.org/schema#" => :draft4,

    # Draft 6
    "http://json-schema.org/draft-06/schema" => :draft6,
    "http://json-schema.org/draft-06/schema#" => :draft6,

    # Draft 7
    "http://json-schema.org/draft-07/schema" => :draft7,
    "http://json-schema.org/draft-07/schema#" => :draft7,

    # Draft 2019-09
    "https://json-schema.org/draft/2019-09/schema" => :draft201909,
    "https://json-schema.org/draft/2019-09/meta/core" => :draft201909,
    "https://json-schema.org/draft/2019-09/meta/applicator" => :draft201909,
    "https://json-schema.org/draft/2019-09/meta/validation" => :draft201909,
    "https://json-schema.org/draft/2019-09/meta/meta-data" => :draft201909,
    "https://json-schema.org/draft/2019-09/meta/format" => :draft201909,
    "https://json-schema.org/draft/2019-09/meta/content" => :draft201909,

    # Draft 2020-12
    "https://json-schema.org/draft/2020-12/schema" => :draft202012,
    "https://json-schema.org/draft/2020-12/meta/core" => :draft202012,
    "https://json-schema.org/draft/2020-12/meta/applicator" => :draft202012,
    "https://json-schema.org/draft/2020-12/meta/unevaluated" => :draft202012,
    "https://json-schema.org/draft/2020-12/meta/validation" => :draft202012,
    "https://json-schema.org/draft/2020-12/meta/meta-data" => :draft202012,
    "https://json-schema.org/draft/2020-12/meta/format-annotation" => :draft202012,
    "https://json-schema.org/draft/2020-12/meta/format-assertion" => :draft202012,
    "https://json-schema.org/draft/2020-12/meta/content" => :draft202012
  }

  # Canonical URLs for each draft
  @canonical_urls %{
    draft4: "http://json-schema.org/draft-04/schema#",
    draft6: "http://json-schema.org/draft-06/schema#",
    draft7: "http://json-schema.org/draft-07/schema#",
    draft201909: "https://json-schema.org/draft/2019-09/schema",
    draft202012: "https://json-schema.org/draft/2020-12/schema"
  }

  @doc """
  Detects the JSON Schema draft version from a schema document.

  Examines the `$schema` property to determine the draft version.
  If no `$schema` is present or the URL is unrecognized, returns the default draft.

  ## Parameters

    - `schema` - A schema as a map or JSON string

  ## Examples

      iex> schema = %{"$schema" => "http://json-schema.org/draft-07/schema#", "type" => "string"}
      iex> DraftDetector.detect_draft(schema)
      {:ok, :draft7}

      iex> schema = %{"type" => "number"}  # No $schema
      iex> DraftDetector.detect_draft(schema)
      {:ok, :draft202012}

      iex> DraftDetector.detect_draft(~s({"$schema": "https://json-schema.org/draft/2020-12/schema"}))
      {:ok, :draft202012}

  """
  @spec detect_draft(schema()) :: detection_result()
  def detect_draft(schema) when is_map(schema) do
    # Check for invalid $schema value first (maintain compatibility)
    case Map.get(schema, "$schema") do
      val when is_integer(val) or is_float(val) or is_boolean(val) or is_list(val) ->
        {:error, "Invalid $schema value: must be a string, got #{inspect(val)}"}

      _ ->
        # Convert map to JSON string for Rust NIF
        case Jason.encode(schema) do
          {:ok, schema_json} ->
            handle_rust_response(Native.detect_draft_from_schema(schema_json))

          {:error, %Jason.EncodeError{} = error} ->
            {:error, "Invalid schema data: #{Exception.message(error)}"}
        end
    end
  end

  def detect_draft(schema) when is_binary(schema) do
    Logger.debug("Detecting JSON Schema draft from string", %{
      schema_size: byte_size(schema)
    })

    # Delegate to Rust NIF and handle response format
    result = handle_rust_response(Native.detect_draft_from_schema(schema))

    case result do
      {:ok, draft} ->
        Logger.debug("Draft detection successful", %{detected_draft: draft})

      {:error, reason} ->
        Logger.warning("Draft detection failed", %{reason: reason})
    end

    result
  end

  def detect_draft(schema) do
    {:error, "Invalid schema input: expected map or JSON string, got #{inspect(schema)}"}
  end

  @doc """
  Detects draft version from a schema URL.

  This function provides URL-based draft detection as a convenience utility.
  For schema document detection, use `detect_draft/1` which delegates to the
  underlying Rust implementation for better performance.

  ## Examples

      iex> DraftDetector.detect_draft_from_url("http://json-schema.org/draft-07/schema#")
      {:ok, :draft7}

      iex> DraftDetector.detect_draft_from_url("https://example.com/custom-schema")
      {:ok, :draft202012}  # Falls back to default draft

  """
  @spec detect_draft_from_url(String.t() | nil) :: detection_result()
  def detect_draft_from_url(nil), do: {:error, "Invalid URL: cannot be nil"}
  def detect_draft_from_url(""), do: {:error, "Invalid URL: cannot be empty"}

  def detect_draft_from_url(url) when is_binary(url) do
    case Map.get(@schema_url_mappings, url) do
      nil ->
        # Try pattern matching for unknown URLs
        case extract_draft_from_url_pattern(url) do
          {:ok, draft} -> {:ok, draft}
          # Fallback to default instead of error
          :error -> {:ok, @default_draft}
        end

      draft ->
        {:ok, draft}
    end
  end

  @doc """
  Returns all supported JSON Schema draft versions.

  ## Examples

      iex> DraftDetector.supported_drafts()
      [:draft4, :draft6, :draft7, :draft201909, :draft202012]

  """
  @spec supported_drafts() :: [draft()]
  def supported_drafts, do: @supported_drafts

  @doc """
  Checks if a draft version is supported.

  ## Examples

      iex> DraftDetector.supports_draft?(:draft7)
      true

      iex> DraftDetector.supports_draft?(:draft3)
      false

  """
  @spec supports_draft?(any()) :: boolean()
  def supports_draft?(draft), do: draft in @supported_drafts

  @doc """
  Returns the default draft version used when detection fails.

  ## Examples

      iex> DraftDetector.default_draft()
      :draft202012

  """
  @spec default_draft() :: draft()
  def default_draft, do: @default_draft

  @doc """
  Checks if a schema document contains a $schema property.

  ## Examples

      iex> DraftDetector.schema_has_draft?(%{"$schema" => "http://json-schema.org/draft-07/schema#"})
      true

      iex> DraftDetector.schema_has_draft?(%{"type" => "string"})
      false

  """
  @spec schema_has_draft?(schema()) :: boolean()
  def schema_has_draft?(schema) when is_map(schema) do
    Map.has_key?(schema, "$schema")
  end

  def schema_has_draft?(schema) when is_binary(schema) do
    case Jason.decode(schema) do
      {:ok, parsed_schema} -> schema_has_draft?(parsed_schema)
      {:error, _} -> false
    end
  end

  def schema_has_draft?(_), do: false

  @doc """
  Returns the canonical URL for a draft version.

  ## Examples

      iex> DraftDetector.draft_url(:draft7)
      "http://json-schema.org/draft-07/schema#"

      iex> DraftDetector.draft_url(:draft202012)
      "https://json-schema.org/draft/2020-12/schema"

  """
  @spec draft_url(draft()) :: String.t() | {:error, String.t()}
  def draft_url(draft) when draft in @supported_drafts do
    Map.get(@canonical_urls, draft)
  end

  def draft_url(draft) do
    {:error, "Unsupported draft: #{inspect(draft)}"}
  end

  # Private helper functions

  # Convert Rust NIF response format to maintain API compatibility
  defp handle_rust_response({:ok, draft}) when is_atom(draft) do
    {:ok, draft}
  end

  defp handle_rust_response({:error, error_map}) when is_map(error_map) do
    # Extract message from Rust error structure  
    message = error_map["message"] || "Unknown error"
    details = error_map["details"]

    if details do
      {:error, "#{message}: #{details}"}
    else
      {:error, message}
    end
  end

  defp handle_rust_response(other) do
    {:error, "Unexpected response from draft detection: #{inspect(other)}"}
  end

  defp extract_draft_from_url_pattern(url) do
    cond do
      String.contains?(url, "draft-04") or String.contains?(url, "draft/04") ->
        {:ok, :draft4}

      String.contains?(url, "draft-06") or String.contains?(url, "draft/06") ->
        {:ok, :draft6}

      String.contains?(url, "draft-07") or String.contains?(url, "draft/07") ->
        {:ok, :draft7}

      String.contains?(url, "2019-09") ->
        {:ok, :draft201909}

      String.contains?(url, "2020-12") ->
        {:ok, :draft202012}

      true ->
        :error
    end
  end
end
