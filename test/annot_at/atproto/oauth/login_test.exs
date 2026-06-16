defmodule AnnotAt.Atproto.OAuth.LoginTest do
  use AnnotAt.DataCase, async: true
  use Mimic

  alias AnnotAt.Accounts
  alias AnnotAt.Accounts.OAuthLoginRequest
  alias AnnotAt.Atproto.Identity
  alias AnnotAt.Atproto.OAuth.Discovery
  alias AnnotAt.Atproto.OAuth.Flow
  alias AnnotAt.Atproto.OAuth.Login
  alias AnnotAt.Atproto.OAuth.ServerMetadata
  alias AnnotAt.Atproto.OAuth.Session
  alias AnnotAt.Atproto.Profile

  @did "did:plc:ewvi7nxzyoun6zhxrhs64oiz"
  @pds "https://enoki.us-east.host.bsky.network"
  @issuer "https://bsky.social"

  @dpop_jwk_json "../../../support/fixtures/atproto/es256_jwk.json"
                 |> Path.expand(__DIR__)
                 |> File.read!()

  setup do
    jwk =
      @dpop_jwk_json
      |> Jason.decode!()
      |> JOSE.JWK.from()

    [jwk: jwk]
  end

  describe "Login.start_login/1" do
    test "resolves, PARs, stores the request, and returns the authorize URL" do
      identity = %Identity{did: @did, handle: "jola.dev", pds_endpoint: @pds}
      server = server()

      expect(Identity, :resolve_handle, fn "jola.dev" -> {:ok, identity} end)
      expect(Discovery, :discover, fn @pds -> {:ok, server} end)
      expect(Flow, :par, fn ^server, _opts -> {:ok, "urn:req:abc"} end)

      assert {:ok, url} = Login.start_login("jola.dev")
      assert url =~ "#{@issuer}/oauth/authorize"
      assert url =~ "request_uri=urn"

      assert [request] = Repo.all(OAuthLoginRequest)
      assert @did == request.did
      assert "jola.dev" == request.handle
      assert @issuer == request.auth_server_issuer
      assert request.pkce_verifier
      assert request.dpop_private_jwk
    end

    test "maps an invalid handle to :invalid_handle" do
      expect(Identity, :resolve_handle, fn _ -> {:error, :invalid_handle} end)
      reject(&Discovery.discover/1)

      assert {:error, :invalid_handle} == Login.start_login("nope")
    end

    test "maps other resolution failures to :login_failed" do
      expect(Identity, :resolve_handle, fn _ -> {:error, :handle_not_found} end)

      assert {:error, :login_failed} == Login.start_login("jola.dev")
    end
  end

  describe "Login.complete_login/1" do
    test "exchanges the code and persists the user and session", %{jwk: jwk} do
      create_request()
      server = server()

      session = %Session{
        did: @did,
        access_token: "access-1",
        refresh_token: "refresh-1",
        dpop_key: jwk,
        scope: "atproto",
        issuer: @issuer,
        pds_endpoint: @pds,
        expires_at: ~U[2026-01-01 01:00:00Z]
      }

      expect(Discovery, :discover, fn @pds -> {:ok, server} end)
      expect(Flow, :exchange_code, fn ^server, _opts -> {:ok, session} end)

      expect(Profile, :fetch, fn "jola.dev" ->
        {:ok, %{display_name: "Johanna", avatar_url: "https://cdn/av.jpg"}}
      end)

      params = %{"code" => "code-1", "state" => "state-1", "iss" => @issuer}
      assert {:ok, user} = Login.complete_login(params)

      assert @did == user.did
      assert "Johanna" == user.display_name
      assert "https://cdn/av.jpg" == user.avatar_url
      assert "access-1" == user.atproto_session.access_token
      refute Accounts.take_login_request("state-1")
    end

    test "returns :invalid_state for an unknown state" do
      reject(&Flow.exchange_code/2)

      params = %{"code" => "x", "state" => "nope", "iss" => @issuer}
      assert {:error, :invalid_state} == Login.complete_login(params)
    end

    test "rejects a callback whose iss does not match the stored issuer" do
      create_request()
      reject(&Flow.exchange_code/2)

      params = %{"code" => "c", "state" => "state-1", "iss" => "https://evil.example"}
      assert {:error, :login_failed} == Login.complete_login(params)
    end

    test "surfaces an authorization-server error" do
      assert {:error, {:oauth_error, "access_denied"}} ==
               Login.complete_login(%{"error" => "access_denied"})
    end

    test "returns :invalid_callback for malformed params" do
      assert {:error, :invalid_callback} == Login.complete_login(%{})
    end
  end

  describe "Login.logout/1" do
    test "logout/1 deletes the user's atproto session", %{jwk: _jwk} do
      {:ok, user} =
        Accounts.upsert_login(
          %{did: @did, handle: "jola.dev", pds_host: @pds},
          %{
            auth_server_issuer: @issuer,
            granted_scopes: "atproto",
            access_token: "a",
            refresh_token: "r",
            dpop_private_jwk: "{}",
            expires_at: ~U[2026-01-01 01:00:00Z]
          }
        )

      assert Accounts.get_atproto_session(user.id)
      assert :ok == Login.logout(user)
      refute Accounts.get_atproto_session(user.id)
    end
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

  defp create_request(overrides \\ %{}) do
    {:ok, request} =
      Accounts.create_login_request(
        Map.merge(
          %{
            state: "state-1",
            did: @did,
            handle: "jola.dev",
            pds_host: @pds,
            auth_server_issuer: @issuer,
            pkce_verifier: "verifier-1",
            dpop_private_jwk: @dpop_jwk_json
          },
          overrides
        )
      )

    request
  end
end
