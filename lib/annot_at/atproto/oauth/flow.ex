defmodule AnnotAt.Atproto.OAuth.Flow do
  @moduledoc """
  Drives the atproto OAuth flow against an authorization server: pushed
  authorization requests, the authorization redirect, token exchange, and
  refresh.

  Requests to the authorization server are DPoP-bound. The server requires a
  fresh DPoP nonce, so each request is attempted once without a nonce and
  retried once with the none the server returns. The client assertion and
  DPoP proof are regenreated on the retry, so neither `jti` is reused.
  """

  alias AnnotAt.Atproto.HTTP
  alias AnnotAt.Atproto.OAuth.ClientAssertion
  alias AnnotAt.Atproto.OAuth.DPoP
  alias AnnotAt.Atproto.OAuth.ServerMetadata
  alias AnnotAt.Atproto.OAuth.Session
  alias AnnotAt.Atproto.OAuth.TokenResponse

  require Logger

  @type request_error ::
          {:transport, term()}
          | :invalid_json
          | :missing_dpop_nonce
          | :unexpected_response
          | {:oauth_error, String.t()}

  @doc """
  Performs a pushed authorization request, returning the `request_uri`.

  ## Required options
  - `:client_id`, `:client_jwk` - the confidential client's id and signing key
  - `:redirect_uri`, `:scope`, `:state`, `:code_challenge` - auth params
  - `:dpop_key` - the per-session DPoP key

  ## Optional
  - `:login_hint` - the user's handle or DID
  """

  @spec par(ServerMetadata.t(), keyword()) ::
          {:ok, String.t()} | {:error, request_error() | :invalid_par_response}
  def par(%ServerMetadata{} = server, opts) do
    client_id = Keyword.fetch!(opts, :client_id)
    client_jwk = Keyword.fetch!(opts, :client_jwk)
    redirect_uri = Keyword.fetch!(opts, :redirect_uri)
    scope = Keyword.fetch!(opts, :scope)
    state = Keyword.fetch!(opts, :state)
    code_challenge = Keyword.fetch!(opts, :code_challenge)
    dpop_key = Keyword.fetch!(opts, :dpop_key)
    login_hint = Keyword.get(opts, :login_hint)

    build_form = fn ->
      maybe_put(
        [
          response_type: "code",
          client_id: client_id,
          redirect_uri: redirect_uri,
          scope: scope,
          state: state,
          code_challenge: code_challenge,
          code_challenge_method: "S256",
          client_assertion_type: ClientAssertion.assertion_type(),
          client_assertion: ClientAssertion.sign(client_jwk, client_id, server.issuer)
        ],
        :login_hint,
        login_hint
      )
    end

    with {:ok, body} <- dpop_request(server.par_endpoint, build_form, dpop_key) do
      case body do
        %{"request_uri" => request_uri} when is_binary(request_uri) -> {:ok, request_uri}
        _ -> {:error, :invalid_par_response}
      end
    end
  end

  @doc """
  Builds the authorization redirect URL from a PAR `request_uri`.

  The browser is sent here, per atproto only `client_id` and `request_uri`
  travel in the URL, since the real parameters were pushed durig PAR.
  """
  @spec authorization_url(ServerMetadata.t(), String.t(), String.t()) :: String.t()
  def authorization_url(%ServerMetadata{} = server, client_id, request_uri) do
    query = URI.encode_query(client_id: client_id, request_uri: request_uri)
    server.authorization_endpoint <> "?" <> query
  end

  @doc """
  Exchanges an authorization code for a session.

  Verifies the token response `sub` matches `expected_did` (the DID resolved
  before login) before building the session. The callback's `state` and `iss`
  are validated upstream, before this is called.

  ## Required options
  - `:client_id`, `:client_jwk` - the confidential client's id and signing key
  - `:redirect_uri` - must match the value sent during PAR
  - `:code`, `:core_verifier` - the authorization code and PKCE verifier
  - `:dpop_key` - the per-session DPoP key
  - `:expected_did` - the DID the `sub` must match
  - `:pds_endpoint` - the resource server, stored on the session

  ## Optional
  - `:now` - base time for `expires_at` (defaults to the current time)
  """
  @spec exchange_code(ServerMetadata.t(), keyword()) ::
          {:ok, Session.t()}
          | {:error,
             request_error() | {:missing, String.t()} | {:invalid, String.t()} | :did_mismatch}
  def exchange_code(%ServerMetadata{} = server, opts) do
    client_id = Keyword.fetch!(opts, :client_id)
    client_jwk = Keyword.fetch!(opts, :client_jwk)
    redirect_uri = Keyword.fetch!(opts, :redirect_uri)
    code = Keyword.fetch!(opts, :code)
    code_verifier = Keyword.fetch!(opts, :code_verifier)
    dpop_key = Keyword.fetch!(opts, :dpop_key)
    expected_did = Keyword.fetch!(opts, :expected_did)
    pds_endpoint = Keyword.fetch!(opts, :pds_endpoint)
    now = Keyword.get_lazy(opts, :now, &DateTime.utc_now/0)

    build_form = fn ->
      [
        grant_type: "authorization_code",
        code: code,
        redirect_uri: redirect_uri,
        code_verifier: code_verifier,
        client_id: client_id,
        client_assertion_type: ClientAssertion.assertion_type(),
        client_assertion: ClientAssertion.sign(client_jwk, client_id, server.issuer)
      ]
    end

    with {:ok, body} <- dpop_request(server.token_endpoint, build_form, dpop_key),
         {:ok, tokens} <- TokenResponse.parse(body),
         :ok <- verify_sub(tokens.sub, expected_did) do
      {:ok, build_session(tokens, server, pds_endpoint, dpop_key, now)}
    end
  end

  @doc """
  Refreshes a session, returning a new session with rotated tokens.

  The refresh is DPoP-bound to the session's existing key (the tokens are
  bound to it), and the new `sub` must still match the session's DID. Refresh
  tokens are single-use, so the returned session carries the rotated tokens
  and must replace the old one.

  ## Required options
  - `:client_id`, `:client_jwk` - the confidential client's id and signing key

  ## Optional
  - `:now` - base time for `expires_at` (defaults to the current time)
  """
  @spec refresh(ServerMetadata.t(), Session.t(), keyword()) ::
          {:ok, Session.t()}
          | {:error,
             request_error() | {:missing, String.t()} | {:invalid, String.t()} | :did_mismatch}
  def refresh(%ServerMetadata{} = server, %Session{} = session, opts) do
    client_id = Keyword.fetch!(opts, :client_id)
    client_jwk = Keyword.fetch!(opts, :client_jwk)
    now = Keyword.get_lazy(opts, :now, &DateTime.utc_now/0)

    build_form = fn ->
      [
        grant_type: "refresh_token",
        refresh_token: session.refresh_token,
        client_id: client_id,
        client_assertion_type: ClientAssertion.assertion_type(),
        client_assertion: ClientAssertion.sign(client_jwk, client_id, server.issuer)
      ]
    end

    with {:ok, body} <- dpop_request(server.token_endpoint, build_form, session.dpop_key),
         {:ok, tokens} <- TokenResponse.parse(body),
         :ok <- verify_sub(tokens.sub, session.did) do
      {:ok, build_session(tokens, server, session.pds_endpoint, session.dpop_key, now)}
    end
  end

  defp dpop_request(url, build_form, dpop_key, nonce \\ nil) do
    proof = DPoP.proof(dpop_key, "POST", url, nonce: nonce)

    with {:ok, %{status: status, body: raw, headers: headers}} <-
           HTTP.post_form(url, build_form.(), [{"dpop", proof}]),
         {:ok, body} <- decode_json(raw) do
      cond do
        status in 200..299 ->
          {:ok, body}

        retry_nonce?(body, nonce) ->
          retry_with_nonce(url, build_form, dpop_key, headers)

        Map.has_key?(body, "error") ->
          Logger.warning("atproto OAuth error from #{url}: #{inspect(body)}")
          {:error, {:oauth_error, Map.fetch!(body, "error")}}

        true ->
          {:error, :unexpected_response}
      end
    end
  end

  defp retry_with_nonce(url, build_form, dpop_key, headers) do
    case nonce_header(headers) do
      nil -> {:error, :missing_dpop_nonce}
      nonce -> dpop_request(url, build_form, dpop_key, nonce)
    end
  end

  defp retry_nonce?(%{"error" => "use_dpop_nonce"}, nil), do: true
  defp retry_nonce?(_body, _nonce), do: false

  defp nonce_header(headers) do
    case Map.get(headers, "dpop-nonce") do
      [nonce | _] -> nonce
      _ -> nil
    end
  end

  defp decode_json(raw) do
    case Jason.decode(raw) do
      {:ok, json} -> {:ok, json}
      _ -> {:error, :invalid_json}
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Keyword.put(map, key, value)

  defp verify_sub(sub, sub), do: :ok
  defp verify_sub(_sub, _expected), do: {:error, :did_mismatch}

  defp build_session(tokens, server, pds_endpoint, dpop_key, now) do
    %Session{
      did: tokens.sub,
      access_token: tokens.access_token,
      refresh_token: tokens.refresh_token,
      dpop_key: dpop_key,
      scope: tokens.scope,
      issuer: server.issuer,
      pds_endpoint: pds_endpoint,
      expires_at: DateTime.add(now, tokens.expires_in, :second)
    }
  end
end
