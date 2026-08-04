defmodule AnnotAtWeb.PostsLiveTest do
  use AnnotAtWeb.ConnCase, async: true
  use Mimic

  import Phoenix.LiveViewTest

  alias AnnotAt.Accounts
  alias AnnotAt.Accounts.Scope
  alias AnnotAt.Atproto.StandardSite
  alias AnnotAt.Atproto.StandardSite.Document
  alias AnnotAt.Feeds.Client
  alias AnnotAt.Feeds.Entry
  alias AnnotAt.Feeds.Feed
  alias AnnotAt.Publishing
  alias Latch.TID

  test "publishing a post writes a document and flips the row", %{
    conn: conn
  } do
    user = create_user()
    scope = Scope.for_user(user)
    site = create_site(scope)
    title = "First Post"
    id = "guid-1"
    published_at = ~U[2024-10-02 13:00:00Z]
    rkey = TID.at_time(published_at, 1)

    feed = %Feed{
      title: "Blog",
      entries: [
        %Entry{
          id: id,
          url: "https://example.com/posts/first",
          title: title,
          published_at: published_at,
          summary: "a summary",
          content: "the body",
          categories: ["category"]
        }
      ]
    }

    expect(StandardSite, :list_documents, fn _user_id -> {:ok, []} end)
    expect(Client, :load, fn _url -> {:ok, feed} end)

    expect(Client, :resolve_documents, fn _feed, _user_did ->
      %{entries: entries} = feed

      %{
        feed
        | entries:
            Enum.map(entries, fn entry ->
              %{entry | rkey: rkey}
            end)
      }
    end)

    expect(StandardSite, :put_document, fn user_id, document, _cover ->
      assert user_id == user.id
      assert title == document.title
      assert TID.valid?(document.rkey)
      assert ["category"] = document.tags
      {:ok, %{"uri" => "at://x"}}
    end)

    {:ok, lv, _html} =
      conn
      |> init_test_session(%{user_id: user.id})
      |> live(~p"/sites/#{site.id}/posts?tab=unpublished")

    assert render_async(lv, 2000) =~ title

    lv
    |> element("button[phx-value-rkey='#{rkey}']")
    |> render_click()

    lv
    |> element("#publish-modal-confirm")
    |> render_click()

    assert render_async(lv, 2000) =~ "Everything in the feed is published."
    assert [%{rkey: ^rkey}] = Publishing.list_posts(site)
  end

  test "publishing attaches the cover image when one is usable", %{
    conn: conn
  } do
    user = create_user()
    scope = Scope.for_user(user)
    site = create_site(scope)
    id = "guid-1"
    cover = {"PNGBYTES", "image/png"}
    published_at = ~U[2024-10-02 13:00:00Z]
    rkey = TID.at_time(published_at, 1)

    feed = %Feed{
      title: "Blog",
      entries: [
        %Entry{
          id: id,
          url: "https://example.com/posts/first",
          title: "First Post",
          published_at: published_at,
          summary: "a summary",
          content: "the body"
        }
      ]
    }

    expect(StandardSite, :list_documents, fn _user_id -> {:ok, []} end)
    expect(Client, :load, fn _url -> {:ok, feed} end)

    expect(Client, :resolve_documents, fn _feed, _did ->
      %{
        feed
        | entries:
            Enum.map(feed.entries, fn entry ->
              %{
                entry
                | rkey: rkey,
                  image: "https://example.com/og.png",
                  cover_status: :ok
              }
            end)
      }
    end)

    expect(Client, :fetch_image, fn "https://example.com/og.png" ->
      {:ok, cover}
    end)

    expect(StandardSite, :put_document, fn _user_id, _document, upload ->
      assert upload == cover
      {:ok, %{"uri" => "at://x"}}
    end)

    {:ok, lv, _html} =
      conn
      |> init_test_session(%{user_id: user.id})
      |> live(~p"/sites/#{site.id}/posts?tab=unpublished")

    assert render_async(lv, 2000) =~ "First Post"

    lv
    |> element("button[phx-value-rkey='#{rkey}']")
    |> render_click()

    lv
    |> element("#publish-modal-confirm")
    |> render_click()

    assert render_async(lv, 2000) =~ "Published"
  end

  test "publishing drops an unpublishable cover but still publishes", %{
    conn: conn
  } do
    user = create_user()
    scope = Scope.for_user(user)
    site = create_site(scope)
    id = "guid-1"
    published_at = ~U[2024-10-02 13:00:00Z]
    rkey = TID.at_time(published_at, 1)

    feed = %Feed{
      title: "Blog",
      entries: [
        %Entry{
          id: id,
          url: "https://example.com/posts/first",
          title: "First Post",
          published_at: published_at,
          summary: "a summary",
          content: "the body"
        }
      ]
    }

    expect(StandardSite, :list_documents, fn _user_id -> {:ok, []} end)
    expect(Client, :load, fn _url -> {:ok, feed} end)

    expect(Client, :resolve_documents, fn _feed, _did ->
      %{
        feed
        | entries:
            Enum.map(feed.entries, fn entry ->
              %{
                entry
                | rkey: rkey,
                  image: "https://example.com/big.png",
                  cover_status: :too_large
              }
            end)
      }
    end)

    expect(StandardSite, :put_document, fn _user_id, _document, upload ->
      assert is_nil(upload)
      {:ok, %{"uri" => "at://x"}}
    end)

    {:ok, lv, _html} =
      conn
      |> init_test_session(%{user_id: user.id})
      |> live(~p"/sites/#{site.id}/posts?tab=unpublished")

    assert render_async(lv, 2000) =~ "First Post"

    lv
    |> element("button[phx-value-rkey='#{rkey}']")
    |> render_click()

    lv
    |> element("#publish-modal-confirm")
    |> render_click()

    assert render_async(lv, 2000) =~ "Published"
    assert [%{rkey: ^rkey}] = Publishing.list_posts(site)
  end

  test "removing a post deletes the record and flips the row back", %{conn: conn} do
    user = create_user()
    scope = Scope.for_user(user)
    site = create_site(scope)
    published_at = ~U[2024-10-02 13:00:00Z]
    rkey = TID.at_time(published_at, 1)

    document = %Document{
      rkey: rkey,
      site: StandardSite.publication_uri(user.did, site.rkey),
      title: "First Post",
      published_at: published_at
    }

    feed = %Feed{
      title: "Blog",
      entries: [
        %Entry{
          id: "guid-1",
          url: "https://example.com/posts/first",
          title: "First Post",
          published_at: published_at
        }
      ]
    }

    expect(StandardSite, :list_documents, fn _user_id -> {:ok, [document]} end)
    expect(Client, :load, fn _url -> {:ok, feed} end)

    expect(Client, :resolve_documents, fn _feed, _did ->
      %{feed | entries: Enum.map(feed.entries, &%{&1 | rkey: rkey})}
    end)

    expect(StandardSite, :delete_document, fn user_id, doc_rkey ->
      assert user.id == user_id
      assert rkey == doc_rkey
      {:ok, %{}}
    end)

    {:ok, lv, _html} =
      conn
      |> init_test_session(%{user_id: user.id})
      |> live(~p"/sites/#{site.id}/posts")

    assert render_async(lv, 2000) =~ "Published (1)"

    lv
    |> element("#remove-#{rkey}")
    |> render_click()

    lv
    |> element("#delete-modal-confirm")
    |> render_click()

    assert render_async(lv, 2000) =~ "Nothing published from this feed yet."
    assert [] = Publishing.list_posts(site)
  end

  defp create_user do
    {:ok, user} =
      Accounts.upsert_user(%{
        did: "did:plc:abc",
        handle: "jola.dev"
      })

    user
  end

  defp create_site(scope) do
    {:ok, site} = Publishing.create_site(scope, "https://example.com")
    {:ok, site} = Publishing.use_new_publication(scope, site)
    {:ok, site} = Publishing.mark_verified(scope, site)
    {:ok, site} = Publishing.mark_published(scope, site)

    site
  end
end
