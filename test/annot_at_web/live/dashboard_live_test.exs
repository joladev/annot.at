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

    assert html =~ "Hi Alice"
    assert html =~ "Your sites"
  end

  test "redirects to login when not authenticated", %{conn: conn} do
    assert {:error, {:redirect, %{to: path}}} = live(conn, ~p"/dashboard")
    assert ~p"/login" == path
  end

  defp create_user do
    {:ok, user} =
      Accounts.upsert_login(
        %{
          did: @did,
          handle: "alice.test",
          pds_host: "https://pds.example.com",
          display_name: "Alice"
        },
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
end
