defmodule AnnotAt.Atproto.StandardSiteTest do
  use AnnotAt.DataCase, async: true
  use Mimic

  alias AnnotAt.Accounts
  alias AnnotAt.Atproto.HTTP
  alias AnnotAt.Atproto.OAuth.Client
  alias AnnotAt.Atproto.StandardSite
  alias AnnotAt.Atproto.StandardSite.Document
  alias AnnotAt.Atproto.StandardSite.Publication

  @did "did:plc:ewvi7nxzyoun6zhxrhs64oiz"
  @rkey "3mope7jyypk22"

  describe "put_publication/2" do
    test "writes a publication record at rkey self" do
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

    test "returns :no_session when the user does not exist" do
      reject(&Client.procedure/3)

      assert {:error, :no_session} =
               StandardSite.put_publication(-1, %Publication{name: "x", url: "y"})
    end

    test "uploads the icon and embeds the returned blob" do
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

    test "omits optional fields that are nil" do
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
  end

  describe "put_document/2" do
    test "writes a document record with an rkey and rfc3339 timestamps" do
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
        site: StandardSite.publication_uri(@did, @rkey),
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

    test "omits updatedAt and path when not set" do
      user = create_user()

      expect(Client, :procedure, fn _user_id, "com.atproto.repo.putRecord", body ->
        refute Map.has_key?(body.record, "updatedAt")
        refute Map.has_key?(body.record, "path")
        assert "2026-01-01T00:00:00Z" == body.record["publishedAt"]
        {:ok, %{"uri" => "at://y"}}
      end)

      doc = %Document{
        rkey: "post-2",
        site: StandardSite.publication_uri(@did, @rkey),
        title: "Hello",
        published_at: ~U[2026-01-01 00:00:00Z]
      }

      assert {:ok, %{"uri" => "at://y"}} = StandardSite.put_document(user.id, doc)
    end
  end

  describe "verify_ownership/2" do
    @url "https://example.com"
    @at_uri "at://#{@did}/site.standard.publication/#{@rkey}"

    test "ok when the well-known matches the at-uri, ignoring surrounding
whitespace" do
      expect(HTTP, :get_text, fn
        "https://example.com/.well-known/site.standard.publication" ->
          {:ok, "  #{@at_uri}\n"}
      end)

      assert :ok = StandardSite.verify_ownership(@url, @at_uri)
    end

    test "fetches the well-known at the domain root even when the url has a
path" do
      expect(HTTP, :get_text, fn
        "https://example.com/.well-known/site.standard.publication" ->
          {:ok, @at_uri}
      end)

      assert :ok =
               StandardSite.verify_ownership(
                 "https://example.com/blog",
                 @at_uri
               )
    end

    test "mismatch when the well-known holds a different uri" do
      expect(HTTP, :get_text, fn _ ->
        {:ok, "at://did:plc:someoneelse/site.standard.publication/x"}
      end)

      assert {:error, :mismatch} = StandardSite.verify_ownership(@url, @at_uri)
    end

    test "not_found when the file is missing" do
      expect(HTTP, :get_text, fn _ -> {:error, {:http_status, 404}} end)
      assert {:error, :not_found} = StandardSite.verify_ownership(@url, @at_uri)
    end
  end

  describe "list_publications/1" do
    test "returns existing publications with their rkeys" do
      user = create_user()

      expect(Client, :query, fn _id, "com.atproto.repo.listRecords", params ->
        assert "site.standard.publication" == params[:collection]

        {:ok,
         %{
           "records" => [
             %{
               "uri" => "at://#{@did}/site.standard.publication/#{@rkey}",
               "value" => %{"name" => "jola.dev", "url" => "https://jola.dev"}
             }
           ]
         }}
      end)

      assert {:ok, [pub]} = StandardSite.list_publications(user.id)
      assert "3mope7jyypk22" == pub.rkey
      assert "https://jola.dev" == pub.url
      assert "jola.dev" == pub.name
    end
  end

  describe "get_publication/2" do
    test "reads the record value" do
      user = create_user()

      expect(Client, :query, fn _id, "com.atproto.repo.getRecord", params ->
        assert "abc123" == params[:rkey]
        {:ok, %{"value" => %{"name" => "jola.dev", "url" => "https://jola.dev"}}}
      end)

      assert {:ok, %{"name" => "jola.dev"}} = StandardSite.get_publication(user.id, "abc123")
    end
  end

  describe "draft_publication/2" do
    test "builds a publication document with discover default" do
      doc =
        StandardSite.draft_publication("https://jola.dev", %{
          title: "jola.dev",
          description: "blog"
        })

      assert "site.standard.publication" == doc["$type"]
      assert "jola.dev" == doc["name"]
      assert "https://jola.dev" == doc["url"]
      assert "blog" == doc["description"]
      assert %{"showInDiscover" => true} == doc["preferences"]
    end
  end

  defp create_user do
    {:ok, user} =
      Accounts.upsert_user(%{
        did: @did,
        handle: "jola.dev",
        pds_host: "https://pds.example.com"
      })

    user
  end
end
