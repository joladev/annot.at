defmodule AnnotAt.Atproto.StandardSiteTest do
  use AnnotAt.DataCase, async: true
  use Mimic

  alias AnnotAt.Accounts
  alias AnnotAt.Atproto.OAuth.Client
  alias AnnotAt.Atproto.StandardSite
  alias AnnotAt.Atproto.StandardSite.Document
  alias AnnotAt.Atproto.StandardSite.Publication

  @did "did:plc:ewvi7nxzyoun6zhxrhs64oiz"

  defp create_user do
    {:ok, user} =
      Accounts.upsert_user(%{did: @did, handle: "jola.dev", pds_host: "https://pds.example.com"})

    user
  end

  test "put_publication/2 writes a publication record at rkey self" do
    user = create_user()

    expect(Client, :procedure, fn user_id, "com.atproto.repo.putRecord", body ->
      assert user.id == user_id
      assert @did == body.repo
      assert "site.standard.publication" == body.collection
      assert "self" == body.rkey
      assert "site.standard.publication" == body.record["$type"]
      assert "jola.dev" == body.record["name"]
      {:ok, %{"uri" => "at://x"}}
    end)

    pub = %Publication{name: "jola.dev", url: "https://jola.dev", description: "blog"}
    assert {:ok, %{"uri" => "at://x"}} = StandardSite.put_publication(user.id, pub)
  end

  test "put_document/2 writes a document record with an rkey and rfc3339 timestamps" do
    user = create_user()

    expect(Client, :procedure, fn _user_id, "com.atproto.repo.putRecord", body ->
      assert "site.standard.document" == body.collection
      assert "post-1" == body.rkey
      assert "Hello" == body.record["title"]
      assert "2026-01-01T00:00:00Z" == body.record["publishedAt"]
      assert ["a", "b"] == body.record["tags"]
      {:ok, %{"uri" => "at://y"}}
    end)

    doc = %Document{
      rkey: "post-1",
      site: StandardSite.publication_uri(@did),
      title: "Hello",
      path: "/posts/1",
      published_at: ~U[2026-01-01 00:00:00Z],
      updated_at: ~U[2026-01-01 00:00:00Z],
      description: "desc",
      text_content: "body",
      tags: ["a", "b"]
    }

    assert {:ok, %{"uri" => "at://y"}} = StandardSite.put_document(user.id, doc)
  end

  test "returns :no_session when the user does not exist" do
    reject(&Client.procedure/3)

    assert {:error, :no_session} =
             StandardSite.put_publication(-1, %Publication{name: "x", url: "y"})
  end

  test "put_publication/2 uploads the icon and embeds the returned blob" do
    user = create_user()

    blob = %{
      "$type" => "blob",
      "ref" => %{"$link" => "bafyicon"},
      "mimeType" => "image/png",
      "size" => 3
    }

    expect(Client, :upload_blob, fn user_id, <<1, 2, 3>>, "image/png" ->
      assert user.id == user_id
      {:ok, %{"blob" => blob}}
    end)

    expect(Client, :procedure, fn _user_id, "com.atproto.repo.putRecord", body ->
      assert blob == body.record["icon"]
      {:ok, %{"uri" => "at://x"}}
    end)

    pub = %Publication{
      name: "jola.dev",
      url: "https://jola.dev",
      icon: {<<1, 2, 3>>, "image/png"}
    }

    assert {:ok, %{"uri" => "at://x"}} = StandardSite.put_publication(user.id, pub)
  end

  test "put_publication/2 omits optional fields that are nil" do
    user = create_user()

    expect(Client, :procedure, fn _user_id, "com.atproto.repo.putRecord", body ->
      refute Map.has_key?(body.record, "description")
      refute Map.has_key?(body.record, "icon")
      {:ok, %{}}
    end)

    assert {:ok, %{}} =
             StandardSite.put_publication(user.id, %Publication{
               name: "n",
               url: "https://n.example"
             })
  end

  test "put_document/2 omits updatedAt and path when not set" do
    user = create_user()

    expect(Client, :procedure, fn _user_id, "com.atproto.repo.putRecord", body ->
      refute Map.has_key?(body.record, "updatedAt")
      refute Map.has_key?(body.record, "path")
      assert "2026-01-01T00:00:00Z" == body.record["publishedAt"]
      {:ok, %{"uri" => "at://y"}}
    end)

    doc = %Document{
      rkey: "post-2",
      site: StandardSite.publication_uri(@did),
      title: "Hello",
      published_at: ~U[2026-01-01 00:00:00Z]
    }

    assert {:ok, %{"uri" => "at://y"}} = StandardSite.put_document(user.id, doc)
  end
end
