defmodule AnnotAt.Atproto.Profile do
  @moduledoc """
  Fetches public Bluesky profile data (display name, avatar) from the user's PDS, through Slingshot.

  Does not rely on the Bluesky AppView.
  """

  alias AnnotAt.Atproto.Slingshot

  @doc """
  Fetches a public profile by DID or handle.
  """
  def fetch(actor) do
    with {:ok, %{did: did, pds: pds}} <- Slingshot.resolve_identity(actor),
         {:ok, %{"value" => profile}} <-
           Slingshot.get_record(did, "app.bsky.actor.profile", "self") do
      {:ok,
       %{
         display_name: profile["displayName"],
         avatar_url: avatar_url(pds, did, profile["avatar"])
       }}
    end
  end

  defp avatar_url(pds, did, %{"ref" => %{"$link" => cid}}) when is_binary(pds) do
    "#{pds}/xrpc/com.atproto.sync.getBlob?did=#{did}&cid=#{cid}"
  end

  defp avatar_url(_pds, _did, _avatar), do: nil
end
