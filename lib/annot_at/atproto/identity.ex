defmodule AnnotAt.Atproto.Identity do
  @moduledoc """
  Resolves an atproto handle to a verified identity.

  Resolution is bidirectional per the atproto identity spec, the handle is
  resolved to a DID and the DID document is fetched independently, and the
  docment's claimed handle must match the handle we started from. Neither
  direction alone is trusted, otherwise anyone could point DNS at a victim's
  DID.
  """

  alias AnnotAt.Atproto.DID
  alias AnnotAt.Atproto.DIDDocument
  alias AnnotAt.Atproto.DNS
  alias AnnotAt.Atproto.Handle
  alias AnnotAt.Atproto.HTTP

  @plc_directory "https://plc.directory"

  @enforce_keys [:did, :handle, :pds_endpoint]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          did: String.t(),
          handle: String.t(),
          pds_endpoint: String.t()
        }

  @doc """
  Resolves and verifies a handle, returning its DID and PDS endpoint.

  Domain failures are atoms (`:invalid_handle`, `:ambiguous_dns`,
  `:handle_mismatch`, `:unsupported_did_method`, ...). Fetch failures
  propagate the transport tuples from `HTTP`.
  """
  @spec resolve_handle(String.t()) ::
          {:ok, t()}
          | {:error,
             :handle_not_found
             | :invalid_handle
             | :ambiguous_dns
             | :invalid_did
             | :handle_mismatch
             | :unsupported_did_method
             | {:http_status, pos_integer()}
             | {:transport, term()}
             | :invalid_json
             | :did_mismatch
             | :no_pds
             | :invalid_pds_endpoint}
  def resolve_handle(handle) when is_binary(handle) do
    handle = Handle.normalize(handle)

    with :ok <- validate_handle(handle),
         {:ok, did} <- handle_to_did(handle),
         :ok <- validate_did(did),
         {:ok, document} <- did_to_document(did),
         {:ok, parsed} <- DIDDocument.parse(document, did),
         :ok <- confirm_bidirectional(parsed, handle) do
      {:ok, %__MODULE__{did: did, handle: handle, pds_endpoint: parsed.pds_endpoint}}
    end
  end

  defp validate_handle(handle) do
    if Handle.valid?(handle) do
      :ok
    else
      {:error, :invalid_handle}
    end
  end

  # DNS TXT is preferred, the HTTPS well-known method is only consulated when
  # DNS returns no record. Conflicting DNS records hard-fail per spec.
  defp handle_to_did(handle) do
    case dns_did(handle) do
      {:ok, _did} = ok -> ok
      {:error, :ambiguous_dns} = error -> error
      :none -> https_did(handle)
    end
  end

  defp validate_did(did) do
    if DID.valid?(did) do
      :ok
    else
      {:error, :invalid_did}
    end
  end

  defp dns_did(handle) do
    with_prefix = "_atproto." <> handle

    dids =
      with_prefix
      |> DNS.lookup_txt()
      |> Enum.flat_map(fn
        "did=" <> did -> [did]
        _ -> []
      end)
      |> Enum.uniq()

    case dids do
      [did] -> {:ok, did}
      [] -> :none
      _ -> {:error, :ambiguous_dns}
    end
  end

  defp https_did(handle) do
    case HTTP.get_text("https://" <> handle <> "/.well-known/atproto-did") do
      {:ok, body} ->
        {:ok, String.trim(body)}

      {:error, _reason} ->
        {:error, :handle_not_found}
    end
  end

  defp did_to_document("did:plc:" <> _ = did) do
    HTTP.get_json(@plc_directory <> "/" <> did)
  end

  defp did_to_document("did:web:" <> host) do
    HTTP.get_json("https://" <> URI.decode(host) <> "/.well-known/did.json")
  end

  defp did_to_document(_), do: {:error, :unsupported_did_method}

  defp confirm_bidirectional(%DIDDocument{handle: handle}, handle), do: :ok
  defp confirm_bidirectional(_parsed, _handle_), do: {:error, :handle_mismatch}
end
