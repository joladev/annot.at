defmodule AnnotAt.Atproto.ProfileTest do
  use ExUnit.Case, async: true
  use Mimic

  alias AnnotAt.Atproto.HTTP
  alias AnnotAt.Atproto.Profile

  test "fetch/1 returns the display name and avatar from the AppView" do
    expect(HTTP, :get_json, fn url ->
      assert "https://public.api.bsky.app/xrpc/app.bsky.actor.getProfile?actor=did%3Aplc%3Aabc" ==
               url

      {:ok, %{"did" => "did:plc:abc", "displayName" => "Jola", "avatar" => "https://cdn/av.jpg"}}
    end)

    assert {:ok, %{display_name: "Jola", avatar_url: "https://cdn/av.jpg"}} =
             Profile.fetch("did:plc:abc")
  end

  test "fetch/1 propagates an HTTP error" do
    expect(HTTP, :get_json, fn _ -> {:error, {:http_status, 400}} end)
    assert {:error, {:http_status, 400}} = Profile.fetch("did:plc:abc")
  end
end
