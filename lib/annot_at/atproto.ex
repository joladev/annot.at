defmodule AnnotAt.Atproto do
  @moduledoc """
  atproto is the protocol that underpins all of the functionality
  in this service.

  https://atproto.com/
  """

  @inspect_site "https://pdsls.dev/"

  @doc """
  Let users inspect their records.
  """
  def inspect_url(aturi) do
    @inspect_site <> aturi
  end

  def blob_url(pds_host, did, %{"ref" => %{"$link" => cid}}) do
    "#{pds_host}/xrpc/com.atproto.sync.getBlob?did=#{did}&cid=#{cid}"
  end
end
