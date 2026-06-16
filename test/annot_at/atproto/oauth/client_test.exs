defmodule AnnotAt.Atproto.OAuth.ClientTest do
  use AnnotAt.DataCase, async: true
  use Mimic

  alias AnnotAt.Accounts
  alias AnnotAt.Atproto.OAuth.Client
  alias AnnotAt.Atproto.OAuth.Discovery
  alias AnnotAt.Atproto.OAuth.Flow
  alias AnnotAt.Atproto.OAuth.ServerMetadata
  alias AnnotAt.Atproto.OAuth.Session
  alias AnnotAt.Atproto.XRPC

  @did "did:plc:ewvi7nxzyoun6zhxrhs64oiz"
  @pds "https://shaggymane.us-west.host.bsky.network"
  @issuer "https://bsky.social"

  @dpop_jwk_json "../../../support/fixtures/atproto/es256_jwk.json"
                 |> Path.expand(__DIR__)
                 |> File.read!()

  test "query/3 uses the current token when it is not expired" do
    user = create_user(future())
    reject(&Flow.refresh/3)

    expect(XRPC, :query, fn %Session{access_token: "access-old"},
                            "app.bsky.actor.getProfile",
                            _ ->
      {:ok, %{"handle" => "jola.dev"}}
    end)

    assert {:ok, %{"handle" => "jola.dev"}} =
             Client.query(user.id, "app.bsky.actor.getProfile", actor: @did)
  end

  test "query/3 refreshes an expired token before calling, and persists it" do
    user = create_user(~U[2020-01-01 00:00:00Z])
    server = server()

    expect(Discovery, :discover, fn @pds -> {:ok, server} end)

    expect(Flow, :refresh, fn ^server, %Session{refresh_token: "refresh-old"}, _opts ->
      {:ok, refreshed_session()}
    end)

    expect(XRPC, :query, fn %Session{access_token: "access-new"}, _method, _ ->
      {:ok, %{"ok" => true}}
    end)

    assert {:ok, %{"ok" => true}} = Client.query(user.id, "app.bsky.actor.getProfile")
    assert "access-new" == Accounts.get_atproto_session(user.id).access_token
  end

  test "query/3 refreshes and retries on a 401" do
    user = create_user(future())
    server = server()

    expect(XRPC, :query, fn %Session{access_token: "access-old"}, _, _ ->
      {:error, {:xrpc_error, 401, %{}}}
    end)

    expect(Discovery, :discover, fn @pds -> {:ok, server} end)
    expect(Flow, :refresh, fn ^server, _session, _opts -> {:ok, refreshed_session()} end)

    expect(XRPC, :query, fn %Session{access_token: "access-new"}, _, _ ->
      {:ok, %{"retried" => true}}
    end)

    assert {:ok, %{"retried" => true}} = Client.query(user.id, "app.bsky.actor.getProfile")
  end

  test "query/3 returns :no_session for a user without a session" do
    {:ok, user} = Accounts.upsert_user(%{did: @did, handle: "jola.dev", pds_host: @pds})
    reject(&XRPC.query/3)

    assert {:error, :no_session} = Client.query(user.id, "app.bsky.actor.getProfile")
  end

  defp create_user(expires_at) do
    {:ok, user} =
      Accounts.upsert_login(
        %{did: @did, handle: "jola.dev", pds_host: @pds},
        %{
          auth_server_issuer: @issuer,
          granted_scopes: "atproto",
          access_token: "access-old",
          refresh_token: "refresh-old",
          dpop_private_jwk: @dpop_jwk_json,
          expires_at: expires_at
        }
      )

    user
  end

  defp future do
    DateTime.utc_now()
    |> DateTime.add(3600, :second)
    |> DateTime.truncate(:second)
  end

  defp server do
    %ServerMetadata{
      issuer: @issuer,
      authorization_endpoint: "#{@issuer}/oauth/authorize",
      token_endpoint: "#{@issuer}/oauth/token",
      par_endpoint: "#{@issuer}/oauth/par",
      scopes_supported: ["atproto"]
    }
  end

  defp refreshed_session do
    %Session{
      did: @did,
      access_token: "access-new",
      refresh_token: "refresh-new",
      dpop_key:
        @dpop_jwk_json
        |> Jason.decode!()
        |> JOSE.JWK.from(),
      scope: "atproto",
      issuer: @issuer,
      pds_endpoint: @pds,
      expires_at: future()
    }
  end
end
