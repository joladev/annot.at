defmodule AnnotAt.Atproto.ProfileTest do
  use ExUnit.Case, async: true
  use Mimic

  alias AnnotAt.Atproto.Profile
  alias AnnotAt.Atproto.Slingshot

  @did "did:plc:abc"
  @handle "jola.dev"
  @display_name "johanna"
  @pds "https://pds.cove.town"
  @cid "cid"
  @avatar_url "#{@pds}/xrpc/com.atproto.sync.getBlob?did=#{@did}&cid=#{@cid}"

  test "fetch/1 returns the display name and avatar from slingshot" do
    expect(Slingshot, :resolve_identity, fn @did ->
      {:ok, %{did: @did, handle: @handle, pds: @pds}}
    end)

    expect(Slingshot, :get_record, fn @did, "app.bsky.actor.profile", "self" ->
      {:ok,
       %{
         "cid" => "bla",
         "uri" => "bla",
         "value" => %{
           "avatar" => %{"ref" => %{"$link" => @cid}},
           "displayName" => @display_name
         }
       }}
    end)

    assert {:ok, %{display_name: @display_name, avatar_url: @avatar_url}} =
             Profile.fetch(@did)
  end

  test "fetch/1 propagates an HTTP error" do
    expect(Slingshot, :resolve_identity, fn @did -> {:error, {:http_status, 400}} end)
    assert {:error, {:http_status, 400}} = Profile.fetch(@did)
  end
end
