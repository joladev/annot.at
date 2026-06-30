defmodule AnnotAtWeb.PostsLiveTest do
  use AnnotAtWeb.ConnCase, async: true
  use Mimic

  import Phoenix.LiveViewTest

  alias AnnotAt.Accounts
  alias AnnotAt.Accounts.Scope
  alias AnnotAt.Atproto.StandardSite
  alias AnnotAt.Atproto.TID
  alias AnnotAt.Feeds.Client
  alias AnnotAt.Feeds.Entry
  alias AnnotAt.Feeds.Feed
  alias AnnotAt.Publishing

  setup do
    user = create_user()
    scope = Scope.for_user(user)
    site = create_site(scope)

    %{user: user, site: site}
  end

  test "publishing a post writes a document and flips the row", %{
    conn: conn,
    user: user,
    site: site
  } do
    title = "First Post"
    id = "guid-1"

    feed = %Feed{
      title: "Blog",
      entries: [
        %Entry{
          id: id,
          url: "https://example.com/posts/first",
          title: title,
          published_at: ~U[2024-10-02 13:00:00Z],
          summary: "a summary",
          content: "the body"
        }
      ]
    }

    expect(Client, :load, fn _url -> {:ok, feed} end)

    expect(Client, :resolve_documents, fn _feed, _user_did ->
      %{entries: entries} = feed

      %{
        feed
        | entries:
            Enum.map(entries, fn entry ->
              %{entry | rkey: TID.at_time(entry.published_at)}
            end)
      }
    end)

    expect(StandardSite, :put_document, fn user_id, document ->
      assert user_id == user.id
      assert title == document.title
      assert document.rkey =~ ~r/^[234567abcdefghij]/
      {:ok, %{"uri" => "at://x"}}
    end)

    {:ok, lv, _html} =
      conn
      |> init_test_session(%{user_id: user.id})
      |> live(~p"/sites/#{site.id}/posts")

    assert render_async(lv, 2000) =~ title

    lv
    |> element("button[phx-value-guid='#{id}']")
    |> render_click()

    lv
    |> element("#publish-modal-confirm")
    |> render_click()

    assert render_async(lv, 2000) =~ "Published"
    assert [%{guid: ^id}] = Publishing.list_posts(site)
  end

  test "publishing attaches the cover image when one is usable", %{
    conn: conn,
    user: user,
    site: site
  } do
    id = "guid-1"
    cover = {"PNGBYTES", "image/png"}

    feed = %Feed{
      title: "Blog",
      entries: [
        %Entry{
          id: id,
          url: "https://example.com/posts/first",
          title: "First Post",
          published_at: ~U[2024-10-02 13:00:00Z],
          summary: "a summary",
          content: "the body"
        }
      ]
    }

    expect(Client, :load, fn _url -> {:ok, feed} end)

    expect(Client, :resolve_documents, fn _feed, _did ->
      %{
        feed
        | entries:
            Enum.map(feed.entries, fn entry ->
              %{
                entry
                | rkey: TID.at_time(entry.published_at),
                  image: "https://example.com/og.png",
                  cover_status: :ok
              }
            end)
      }
    end)

    expect(Client, :fetch_image, fn "https://example.com/og.png" ->
      {:ok, cover}
    end)

    expect(StandardSite, :put_document, fn _user_id, document ->
      assert document.cover_image == cover
      {:ok, %{"uri" => "at://x"}}
    end)

    {:ok, lv, _html} =
      conn
      |> init_test_session(%{user_id: user.id})
      |> live(~p"/sites/#{site.id}/posts")

    assert render_async(lv, 2000) =~ "First Post"

    lv
    |> element("button[phx-value-guid='#{id}']")
    |> render_click()

    lv
    |> element("#publish-modal-confirm")
    |> render_click()

    assert render_async(lv, 2000) =~ "Published"
  end

  test "publishing drops an unpublishable cover but still publishes", %{
    conn: conn,
    user: user,
    site: site
  } do
    id = "guid-1"

    feed = %Feed{
      title: "Blog",
      entries: [
        %Entry{
          id: id,
          url: "https://example.com/posts/first",
          title: "First Post",
          published_at: ~U[2024-10-02 13:00:00Z],
          summary: "a summary",
          content: "the body"
        }
      ]
    }

    expect(Client, :load, fn _url -> {:ok, feed} end)

    expect(Client, :resolve_documents, fn _feed, _did ->
      %{
        feed
        | entries:
            Enum.map(feed.entries, fn entry ->
              %{
                entry
                | rkey: TID.at_time(entry.published_at),
                  image: "https://example.com/big.png",
                  cover_status: :too_large
              }
            end)
      }
    end)

    expect(StandardSite, :put_document, fn _user_id, document ->
      assert document.cover_image == nil
      {:ok, %{"uri" => "at://x"}}
    end)

    {:ok, lv, _html} =
      conn
      |> init_test_session(%{user_id: user.id})
      |> live(~p"/sites/#{site.id}/posts")

    assert render_async(lv, 2000) =~ "First Post"

    lv
    |> element("button[phx-value-guid='#{id}']")
    |> render_click()

    lv
    |> element("#publish-modal-confirm")
    |> render_click()

    assert render_async(lv, 2000) =~ "Published"
    assert [%{guid: ^id}] = Publishing.list_posts(site)
  end

  defp create_user do
    {:ok, user} =
      Accounts.upsert_login(
        %{did: "did:plc:abc", handle: "alice.test", pds_host: "https://pds.example.com"},
        %{
          auth_server_issuer: "https://bsky.social",
          granted_scopes: "atproto",
          access_token: "a",
          refresh_token: "r",
          dpop_private_jwk: "{}",
          expires_at: ~U[2026-01-01 01:00:00Z]
        }
      )

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
