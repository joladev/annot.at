defmodule AnnotAtWeb.DashboardLiveTest do
  use AnnotAtWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias AnnotAt.Accounts

  @did "did:plc:ewvi7nxzyoun6zhxrhs64oiz"

  test "renders the greeting for the signed-in user", %{conn: conn} do
    user = create_user()

    {:ok, _lv, html} =
      conn
      |> init_test_session(%{user_id: user.id})
      |> live(~p"/dashboard")

    assert html =~ "Hi Johanna"
    assert html =~ "Your sites"
  end

  test "redirects to login when not authenticated", %{conn: conn} do
    assert {:error, {:redirect, %{to: path}}} = live(conn, ~p"/dashboard")
    assert ~p"/login" == path
  end

  defp create_user do
    {:ok, user} =
      Accounts.upsert_user(%{
        did: @did,
        handle: "jola.dev",
        display_name: "Johanna"
      })

    user
  end
end
