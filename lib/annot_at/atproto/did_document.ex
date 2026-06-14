defmodule AnnotAt.Atproto.DIDDocument do
  @moduledoc """
  Parses atproto DID documents to extract the claimed handle and PDS endpoint.

  Verifies the document's internal correctness only. The caller must confirm
  the handle resolves back to this DID (bidirectional verification) before
  trusting it.
  """

  alias AnnotAt.Atproto.Handle

  @pds_type "AtprotoPersonalDataServer"

  @enforce_keys [:did, :handle, :pds_endpoint]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          did: String.t(),
          handle: String.t(),
          pds_endpoint: String.t()
        }

  @doc """
  Parses a decoded DID document for a given DID.

  The `did` argument is the DID that was resolved to obtain this document.
  It must match the document's `id`.
  """
  @spec parse(map(), String.t()) ::
          {:ok, t()} | {:error, :did_mismatch | :invalid_handle | :no_pds | :invalid_pds_endpoint}
  def parse(document, did) when is_map(document) and is_binary(did) do
    with :ok <- check_id(document, did),
         {:ok, handle} <- claimed_handle(document),
         {:ok, endpoint} <- pds_endpoint(document) do
      {:ok, %__MODULE__{did: did, handle: handle, pds_endpoint: endpoint}}
    end
  end

  defp check_id(document, did) do
    if Map.get(document, "id") == did do
      :ok
    else
      {:error, :did_mismatch}
    end
  end

  defp claimed_handle(document) do
    result =
      document
      |> Map.get("alsoKnownAs", [])
      |> Enum.find_value(fn
        "at://" <> handle = uri when is_binary(uri) ->
          if Handle.valid?(handle) do
            handle
          else
            nil
          end

        _ ->
          nil
      end)

    case result do
      nil -> {:error, :invalid_handle}
      handle -> {:ok, handle}
    end
  end

  defp pds_endpoint(document) do
    result =
      document
      |> Map.get("service", [])
      |> Enum.find(fn service ->
        String.ends_with?(to_string(service["id"]), "#atproto_pds") and
          Map.get(service, "type") == @pds_type
      end)

    case result do
      nil -> {:error, :no_pds}
      service -> validate_endpoint(service["serviceEndpoint"])
    end
  end

  defp validate_endpoint(url) when is_binary(url) do
    case URI.parse(url) do
      %URI{scheme: scheme, host: host, path: nil, query: nil, userinfo: nil}
      when scheme in ["http", "https"] and is_binary(host) and host != "" ->
        {:ok, url}

      _ ->
        {:error, :invalid_pds_endpoint}
    end
  end

  defp validate_endpoint(_), do: {:error, :invalid_pds_endpoint}
end
