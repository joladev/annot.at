defmodule AnnotAtWeb.AuthControllerTest do
  use AnnotAtWeb.ConnCase, async: true
  use Mimic

  alias AnnotAt.Accounts
  alias AnnotAt.Atproto.OAuth.Login

  @did "did:plc:ewvi7nxzyoun6zhxrhs64oiz"

  test "GET /oauth-client-metadata.json serves the client metadata", %{conn: conn} do
    conn = get(conn, ~p"/oauth-client-metadata.json")
    metadata = json_response(conn, 200)

    assert "http://localhost:4002/oauth-client-metadata.json" == metadata["client_id"]
    assert ["http://localhost:4002/auth/callback"] == metadata["redirect_uris"]
    assert metadata["scope"] =~ "atproto"
    assert true == metadata["dpop_bound_access_tokens"]
    assert "private_key_jwt" == metadata["token_endpoint_auth_method"]

    assert [key] = metadata["jwks"]["keys"]
    refute Map.has_key?(key, "d")
  end

  test "GET /auth/callback logs in and redirects dashboard", %{conn: conn} do
    user = create_user()
    expect(Login, :complete_login, fn _ -> {:ok, user} end)

    conn = get(conn, "/auth/callback?code=c&state=s&iss=i")
    assert ~p"/dashboard" == redirected_to(conn)
    assert user.id == get_session(conn, :user_id)
  end

  test "GET /auth/callback redirects to login on failure", %{conn: conn} do
    expect(Login, :complete_login, fn _ -> {:error, :invalid_state} end)

    conn = get(conn, "/auth/callback?state=bad")
    assert ~p"/login" == redirected_to(conn)
  end

  test "DELETE /logout clears the session", %{conn: conn} do
    user = create_user()
    stub(Login, :logout, fn _ -> :ok end)

    conn =
      conn
      |> init_test_session(%{user_id: user.id})
      |> delete(~p"/logout")

    assert ~p"/" == redirected_to(conn)
    refute get_session(conn, :user_id)
  end

  defp create_user do
    {:ok, user} =
      Accounts.upsert_login(
        %{did: @did, handle: "alice.test", pds_host: "https://pds.example.com"},
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
