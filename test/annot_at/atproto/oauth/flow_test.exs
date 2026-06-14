defmodule AnnotAt.Atproto.OAuth.FlowTest do
  use ExUnit.Case, async: true
  use Mimic

  alias AnnotAt.Atproto.HTTP
  alias AnnotAt.Atproto.OAuth.ClientAssertion
  alias AnnotAt.Atproto.OAuth.Flow
  alias AnnotAt.Atproto.OAuth.ServerMetadata
  alias AnnotAt.Atproto.OAuth.Session

  @did "did:plc:ewvi7nxzyoun6zhxrhs64oiz"
  @pds "https://enoki.us-east.host.bsky.network"

  @token_response "../../../support/fixtures/atproto/token_response.json"
                  |> Path.expand(__DIR__)
                  |> File.read!()

  @server %ServerMetadata{
    issuer: "https://bsky.social",
    authorization_endpoint: "https://bsky.social/oauth/authorize",
    token_endpoint: "https://bsky.social/oauth/token",
    par_endpoint: "https://bsky.social/oauth/par",
    scopes_supported: ["atproto"]
  }

  setup do
    jwk =
      "../../../support/fixtures/atproto/es256_jwk.json"
      |> Path.expand(__DIR__)
      |> File.read!()
      |> Jason.decode!()
      |> JOSE.JWK.from()

    opts = [
      client_id: "https://annot.at/client",
      client_jwk: jwk,
      redirect_uri: "https://annot.at/callback",
      scope: "atproto",
      state: "state-123",
      code_challenge: "challenge-123",
      dpop_key: jwk,
      login_hint: "jola.dev"
    ]

    [opts: opts, jwk: jwk]
  end

  describe "Flow.par/2" do
    test "sends the required PAR parameters", %{opts: opts} do
      expect(HTTP, :post_form, fn url, form, _headers ->
        assert "https://bsky.social/oauth/par" = url
        assert "code" == form[:response_type]
        assert "https://annot.at/client" == form[:client_id]
        assert "https://annot.at/callback" == form[:redirect_uri]
        assert "atproto" == form[:scope]
        assert "state-123" == form[:state]
        assert "challenge-123" == form[:code_challenge]
        assert "S256" == form[:code_challenge_method]
        assert ClientAssertion.assertion_type() == form[:client_assertion_type]
        assert is_binary(form[:client_assertion])
        assert "jola.dev" == form[:login_hint]

        {:ok,
         %{status: 201, body: ~s({"request_uri":"urn:req:abc","expires_in":60}), headers: %{}}}
      end)

      assert {:ok, "urn:req:abc"} = Flow.par(@server, opts)
    end

    test "retries with the server nonce and returns the request_uri", %{opts: opts} do
      expect(HTTP, :post_form, fn _url, _form, _headers ->
        {:ok,
         %{
           status: 400,
           body: ~s({"error":"use_dpop_nonce"}),
           headers: %{"dpop-nonce" => ["nonce-xyz"]}
         }}
      end)

      expect(HTTP, :post_form, fn _url, _form, headers ->
        {"dpop", proof} = List.keyfind(headers, "dpop", 0)
        %JOSE.JWT{fields: claims} = JOSE.JWT.peek_payload(proof)
        assert claims["nonce"] == "nonce-xyz"

        {:ok, %{status: 201, body: ~s({"request_uri":"urn:req:retry"}), headers: %{}}}
      end)

      assert {:ok, "urn:req:retry"} = Flow.par(@server, opts)
    end

    test "returns :missing_dpop_nonce when the nonce error lacks the header", %{opts: opts} do
      expect(HTTP, :post_form, fn _url, _from, _headers ->
        {:ok, %{status: 400, body: ~s({"error":"use_dpop_nonce"}), headers: %{}}}
      end)

      assert {:error, :missing_dpop_nonce} = Flow.par(@server, opts)
    end

    test "surfaces an OAuth error from the server", %{opts: opts} do
      expect(HTTP, :post_form, fn _url, _form, _headers ->
        {:ok, %{status: 400, body: ~s({"error":"invalid_client"}), headers: %{}}}
      end)

      assert Flow.par(@server, opts) == {:error, {:oauth_error, "invalid_client"}}
    end

    test "returns :invalid_par_response when a success body has no request_uri", %{opts: opts} do
      expect(HTTP, :post_form, fn _url, _form, _headers ->
        {:ok, %{status: 200, body: ~s({"expires_in":60}), headers: %{}}}
      end)

      assert Flow.par(@server, opts) == {:error, :invalid_par_response}
    end
  end

  describe "PAR.authorization_url/3" do
    test "builds the authorization redirect URL from a request_uri" do
      url = Flow.authorization_url(@server, "https://annot.at/client", "urn:req:abc")
      uri = URI.parse(url)

      assert "https://bsky.social/oauth/authorize" == "#{uri.scheme}://#{uri.host}#{uri.path}"

      assert %{"client_id" => "https://annot.at/client", "request_uri" => "urn:req:abc"} ==
               URI.decode_query(uri.query)
    end
  end

  describe "PAR.exchange_code/2" do
    test "exchanges the code for a session", %{jwk: jwk} do
      expect(HTTP, :post_form, fn _url, _form, _headers ->
        {:ok, %{status: 200, body: @token_response, headers: %{}}}
      end)

      assert {:ok, session} = Flow.exchange_code(@server, exchange_opts(jwk))
      assert @did == session.did
      assert "atproto" == session.scope
      assert "https://bsky.social" == session.issuer
      assert @pds == session.pds_endpoint
      assert ~U[2026-01-01 00:59:59Z] == session.expires_at
      assert jwk == session.dpop_key
    end

    test "sends the token exchange parameters", %{jwk: jwk} do
      expect(HTTP, :post_form, fn url, form, _headers ->
        assert "https://bsky.social/oauth/token" == url
        assert "authorization_code" == form[:grant_type]
        assert "auth-code" == form[:code]
        assert "https://annot.at/callback" == form[:redirect_uri]
        assert "verifier-123" == form[:code_verifier]
        assert ClientAssertion.assertion_type() == form[:client_assertion_type]
        assert is_binary(form[:client_assertion])

        {:ok, %{status: 200, body: @token_response, headers: %{}}}
      end)

      assert {:ok, _session} = Flow.exchange_code(@server, exchange_opts(jwk))
    end

    test "rejects a token whose sub does not match the expected DID", %{jwk: jwk} do
      expect(HTTP, :post_form, fn _url, _form, _headers ->
        {:ok, %{status: 200, body: @token_response, headers: %{}}}
      end)

      assert {:error, :did_mismatch} ==
               Flow.exchange_code(
                 @server,
                 exchange_opts(jwk, expected_did: "did:plc:someoneelse")
               )
    end

    test "propagates a token response parse error", %{jwk: jwk} do
      body =
        Jason.encode!(%{
          "token_type" => "DPoP",
          "access_token" => "x",
          "refresh_token" => "y",
          "expires_in" => 1,
          "scope" => "atproto"
        })

      expect(HTTP, :post_form, fn _url, _form, _headers ->
        {:ok, %{status: 200, body: body, headers: %{}}}
      end)

      assert {:error, {:missing, "sub"}} == Flow.exchange_code(@server, exchange_opts(jwk))
    end
  end

  describe "Flow.refresh/3" do
    test "refreshes a session, rotating the tokens", %{jwk: jwk} do
      session = session_fixture(jwk)

      expect(HTTP, :post_form, fn _url, _form, _headers ->
        {:ok, %{status: 200, body: @token_response, headers: %{}}}
      end)

      assert {:ok, refreshed} = Flow.refresh(@server, session, refresh_opts(jwk))
      assert @did == refreshed.did
      assert "ref-3C2EzDmzzkrcA9rerRmYeg5wBPCRZdnGRkRKUOvbLq" == refreshed.refresh_token
      assert refreshed.refresh_token != session.refresh_token
      assert jwk == refreshed.dpop_key
      assert ~U[2026-06-01 12:59:59Z] == refreshed.expires_at
    end

    test "sends the refresh parameters", %{jwk: jwk} do
      expect(HTTP, :post_form, fn url, form, _headers ->
        assert "https://bsky.social/oauth/token" == url
        assert "refresh_token" == form[:grant_type]
        assert "old-refresh" == form[:refresh_token]
        assert ClientAssertion.assertion_type() == form[:client_assertion_type]
        assert is_binary(form[:client_assertion])

        {:ok, %{status: 200, body: @token_response, headers: %{}}}
      end)

      assert {:ok, _} = Flow.refresh(@server, session_fixture(jwk), refresh_opts(jwk))
    end

    test "rejects a refresh whose sub does not match the session DID", %{jwk: jwk} do
      session = %{session_fixture(jwk) | did: "did:plc:someoneelse"}

      expect(HTTP, :post_form, fn _url, _form, _headers ->
        {:ok, %{status: 200, body: @token_response, headers: %{}}}
      end)

      assert {:error, :did_mismatch} == Flow.refresh(@server, session, refresh_opts(jwk))
    end
  end

  defp exchange_opts(jwk, overrides \\ []) do
    Keyword.merge(
      [
        client_id: "https://annot.at/client",
        client_jwk: jwk,
        redirect_uri: "https://annot.at/callback",
        code: "auth-code",
        code_verifier: "verifier-123",
        dpop_key: jwk,
        expected_did: @did,
        pds_endpoint: @pds,
        now: ~U[2026-01-01 00:00:00Z]
      ],
      overrides
    )
  end

  defp session_fixture(jwk) do
    %Session{
      did: @did,
      access_token: "old-access",
      refresh_token: "old-refresh",
      dpop_key: jwk,
      scope: "atproto",
      issuer: "https://bsky.social",
      pds_endpoint: @pds,
      expires_at: ~U[2026-01-01 00:00:00Z]
    }
  end

  defp refresh_opts(jwk, overrides \\ []) do
    Keyword.merge(
      [client_id: "https://annot.at/client", client_jwk: jwk, now: ~U[2026-06-01 12:00:00Z]],
      overrides
    )
  end
end
