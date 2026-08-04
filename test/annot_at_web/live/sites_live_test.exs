defmodule AnnotAtWeb.SitesLiveTest do
  use AnnotAtWeb.ConnCase, async: true
  use Mimic

  import Phoenix.LiveViewTest

  alias AnnotAt.Accounts
  alias AnnotAt.Accounts.Scope
  alias AnnotAt.Atproto.StandardSite
  alias AnnotAt.Publishing

  test "discovered tab lists publications that aren't set up", %{conn: conn} do
    user = create_user()

    expect(StandardSite, :list_publications, fn user_id ->
      assert user.id == user_id
      {:ok, [%{rkey: "3mope7jyypk22", url: "https://new.example", name: "New Blog"}]}
    end)

    {:ok, lv, _html} =
      conn
      |> init_test_session(%{user_id: user.id})
      |> live(~p"/sites?tab=discovered")

    assert render_async(lv, 2000) =~ "New Blog"
    assert render(lv) =~ "Import"
  end

  test "a site whose publication is gone shows as broken and can be deleted", %{conn: conn} do
    user = create_user()
    scope = Scope.for_user(user)
    {:ok, _site} = create_broken_site(scope)

    expect(StandardSite, :list_publications, fn _user_id -> {:ok, []} end)

    {:ok, lv, _html} =
      conn
      |> init_test_session(%{user_id: user.id})
      |> live(~p"/sites")

    assert render_async(lv, 2000) =~ "Publication missing"

    lv
    |> element("button", "Delete")
    |> render_click()

    refute render(lv) =~ "Publication missing"
    assert [] = Publishing.list_sites(scope)
  end

  defp create_user do
    {:ok, user} =
      Accounts.upsert_user(%{
        did: "did:plc:abc",
        handle: "jola.dev"
      })

    user
  end

  defp create_broken_site(scope) do
    {:ok, site} = Publishing.create_site(scope, "https://gone.example")
    Publishing.use_existing_publication(scope, site, "3mope7jyypk22")
  end
end
