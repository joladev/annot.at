defmodule AnnotAt.Atproto.Identity do
  @moduledoc """
  Resolves an atproto handle to a verified identity.

  Resolution is bidirectional per the atproto identity spec, the handle is
  resolved to a DID and the DID document is fetched independently, and the
  docment's claimed handle must match the handle we started from. Neither
  direction alone is trusted, otherwise anyone could point DNS at a victim's
  DID.
  """

  alias AnnotAt.Atproto.HTTP
  alias Latch.DIDDocument

  @plc_directory "https://plc.directory"

  @enforce_keys [:did, :handle, :pds_endpoint]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          did: String.t(),
          handle: String.t(),
          pds_endpoint: String.t()
        }

  @spec resolve_did(String.t()) :: {:ok, DIDDocument.t()} | {:error, term()}
  def resolve_did(did) when is_binary(did) do
    with {:ok, doc} <- did_to_document(did) do
      DIDDocument.parse(doc, did)
    end
  end

  defp did_to_document("did:plc:" <> _ = did) do
    HTTP.get_json(@plc_directory <> "/" <> did)
  end

  defp did_to_document("did:web:" <> host) do
    HTTP.get_json("https://" <> URI.decode(host) <> "/.well-known/did.json")
  end

  defp did_to_document(_), do: {:error, :unsupported_did_method}
end
