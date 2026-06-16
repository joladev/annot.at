defmodule AnnotAt.Atproto.Profile do
  @moduledoc """
  Fetches public Bluesky profile data (display name, avatar) from the AppView.
  """

  alias AnnotAt.Atproto.HTTP

  @appview "https://public.api.bsky.app"

  @doc """
  Fetches a public profile by DID or handle.
  """
  @spec fetch(String.t()) ::
          {:ok, %{display_name: String.t() | nil, avatar: String.t() | nil}}
          | {:error, {:http_status, pos_integer()} | {:transport, term()} | :invalid_json}

  def fetch(actor) do
    url = "#{@appview}/xrpc/app.bsky.actor.getProfile?#{URI.encode_query(actor: actor)}"

    with {:ok, profile} <- HTTP.get_json(url) do
      {:ok,
       %{display_name: Map.get(profile, "displayName"), avatar_url: Map.get(profile, "avatar")}}
    end
  end
end
