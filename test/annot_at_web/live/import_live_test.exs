defmodule AnnotAtWeb.ImportLiveTest do
  use AnnotAtWeb.ConnCase, async: true
  use Mimic

  import Phoenix.LiveViewTest

  alias AnnotAt.Accounts
  alias AnnotAt.Accounts.Scope
  alias AnnotAt.Atproto.StandardSite
  alias AnnotAt.Feeds.Client
  alias AnnotAt.Feeds.Source
  alias AnnotAt.Publishing

  @rkey "3mope7jyypk22"

  test "verified publication imports with the picked feed", %{conn: conn} do
    user = create_user()
    scope = Scope.for_user(user)

    expect(StandardSite, :get_publication, fn user_id, rkey ->
      assert user.id == user_id
      assert @rkey == rkey
      {:ok, %{"name" => "New Blog", "url" => "https://new.example"}}
    end)

    expect(StandardSite, :verify_ownership, fn "https://new.example", at_uri ->
      assert "at://did:plc:abc/site.standard.publication/#{@rkey}" == at_uri
      :ok
    end)

    expect(Client, :discover, fn "https://new.example" ->
      {:ok, [%Source{url: "https://new.example/feed.xml", title: "RSS", format: :rss}]}
    end)

    {:ok, lv, _html} =
      conn
      |> init_test_session(%{user_id: user.id})
      |> live(~p"/sites/import/#{@rkey}")

    assert render_async(lv, 2000) =~ "Verified"
    assert render(lv) =~ "https://new.example/feed.xml"

    lv
    |> element("button[phx-value-url='https://new.example/feed.xml']")
    |> render_click()

    assert [site] = Publishing.list_sites(scope)
    assert "https://new.example" == site.url
    assert @rkey == site.rkey
    assert "https://new.example/feed.xml" == site.feed_url
    assert %DateTime{} = site.verified_at
    assert %DateTime{} = site.published_at
  end

  test "unverified publication shows instructions instead of the feed picker", %{conn: conn} do
    user = create_user()

    expect(StandardSite, :get_publication, fn _user_id, @rkey ->
      {:ok, %{"name" => "New Blog", "url" => "https://new.example"}}
    end)

    expect(StandardSite, :verify_ownership, fn _url, _at_uri -> {:error, :mismatch} end)

    {:ok, lv, _html} =
      conn
      |> init_test_session(%{user_id: user.id})
      |> live(~p"/sites/import/#{@rkey}")

    html = render_async(lv, 2000)
    assert html =~ "verified yet"
    assert html =~ "/.well-known/site.standard.publication"
    refute html =~ "feed.xml"
  end

  defp create_user do
    {:ok, user} =
      Accounts.upsert_user(%{
        did: "did:plc:abc",
        handle: "jola.dev"
      })

    user
  end
end
