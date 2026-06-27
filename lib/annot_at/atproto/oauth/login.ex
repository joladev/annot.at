defmodule AnnotAt.Atproto.OAuth.Login do
  @moduledoc """
  Orchestrates the atproto OAuth login, resolving the account, discovering its
  authorization server, running the pushed-authorization and token-exchange
  legs of the flow, and persisting the result.

  The integration layer above `Flow` (OAuth primitives), `Identity`/`Discovery`
  (resolution), `Config` (client settings), and `Accounts` (persistence).
  """

  alias AnnotAt.Accounts
  alias AnnotAt.Accounts.User
  alias AnnotAt.Atproto.Identity
  alias AnnotAt.Atproto.OAuth.Config
  alias AnnotAt.Atproto.OAuth.Discovery
  alias AnnotAt.Atproto.OAuth.DPoP
  alias AnnotAt.Atproto.OAuth.Flow
  alias AnnotAt.Atproto.OAuth.PKCE
  alias AnnotAt.Atproto.Profile

  require Logger

  @doc """
  Begins a login for `handle`: resolves the identity, discovers the
  authorization server, pushes the authorization request, stashes the
  in-progress state, and returns the URL to redirect the browser to.
  """
  @spec start_login(String.t()) :: {:ok, String.t()} | {:error, :invalid_handle | :login_failed}
  def start_login(handle) when is_binary(handle) do
    Logger.info("atproto login starting for #{handle}")

    verifier = PKCE.generate_verifier()
    dpop_key = DPoP.generate_key()
    state = random_state()

    result =
      with {:ok, identity} <- Identity.resolve_handle(handle),
           {:ok, server} <- Discovery.discover(identity.pds_endpoint),
           {:ok, request_uri} <- request_par(server, identity, verifier, dpop_key, state),
           {:ok, _request} <- store_login_request(server, identity, verifier, dpop_key, state) do
        Logger.info(
          "atproto login redirecting #{identity.handle} (#{identity.did}) to #{server.issuer}"
        )

        {:ok, Flow.authorization_url(server, Config.client_id(), request_uri)}
      end

    with {:error, reason} <- result do
      Logger.warning("atproto login start failed for #{handle}: #{inspect(reason)}")

      {:error, login_error(reason)}
    end
  end

  @doc """
  Completes a login from the callback parameters. Validates the stored state,
  exchanges the code for a session, and persists the user and session.
  """
  @spec complete_login(map()) ::
          {:ok, User.t()}
          | {:error,
             {:oauth_error, String.t()} | :invalid_callback | :invalid_state | :login_failed}
  def complete_login(%{"error" => error}), do: {:error, {:oauth_error, error}}

  def complete_login(%{"code" => code, "state" => state, "iss" => iss}) do
    result =
      with {:ok, request} <- take_request(state),
           :ok <- verify_issuer(request, iss),
           {:ok, session} <- exchange(request, code),
           {:ok, user} <- persist(request, session) do
        Logger.info("atproto login completed for #{user.handle} (#{user.did})")

        {:ok, user}
      end

    with {:error, reason} <- result do
      Logger.warning("atproto OAuth callback failed: #{inspect(reason)}")
      {:error, callback_error(reason)}
    end
  end

  def complete_login(_), do: {:error, :invalid_callback}

  @doc """
  Logs out by deleting the user's atproto session. The browser session
  is cleared by the caller.
  """
  @spec logout(User.t()) :: :ok
  def logout(%User{} = user) do
    Logger.info("atproto logout for #{user.handle}")

    Accounts.delete_atproto_session(user)
  end

  defp request_par(server, identity, verifier, dpop_key, state) do
    Flow.par(server,
      client_id: Config.client_id(),
      client_jwk: Config.signing_key(),
      redirect_uri: Config.redirect_uri(),
      scope: Config.scope(),
      state: state,
      code_challenge: PKCE.challenge(verifier),
      dpop_key: dpop_key,
      login_hint: identity.handle
    )
  end

  defp store_login_request(server, identity, verifier, dpop_key, state) do
    Accounts.create_login_request(%{
      state: state,
      did: identity.did,
      handle: identity.handle,
      pds_host: identity.pds_endpoint,
      auth_server_issuer: server.issuer,
      pkce_verifier: verifier,
      dpop_private_jwk: DPoP.dump(dpop_key),
      token_endpoint: server.token_endpoint
    })
  end

  defp take_request(state) do
    case Accounts.take_login_request(state) do
      nil -> {:error, :invalid_state}
      request -> {:ok, request}
    end
  end

  defp verify_issuer(%{auth_server_issuer: iss}, iss), do: :ok
  defp verify_issuer(_request, _iss), do: {:error, :issuer_mismatch}

  defp exchange(request, code) do
    Flow.exchange_code(
      client_id: Config.client_id(),
      client_jwk: Config.signing_key(),
      redirect_uri: Config.redirect_uri(),
      code: code,
      code_verifier: request.pkce_verifier,
      dpop_key: DPoP.load(request.dpop_private_jwk),
      expected_did: request.did,
      pds_endpoint: request.pds_host,
      issuer: request.auth_server_issuer,
      token_endpoint: request.token_endpoint
    )
  end

  defp persist(request, session) do
    profile = fetch_profile(request.handle)

    Accounts.upsert_login(
      %{
        did: session.did,
        handle: request.handle,
        pds_host: session.pds_endpoint,
        handle_verified_at: DateTime.utc_now(:second),
        display_name: profile.display_name,
        avatar_url: profile.avatar_url
      },
      %{
        auth_server_issuer: session.issuer,
        granted_scopes: session.scope,
        access_token: session.access_token,
        refresh_token: session.refresh_token,
        dpop_private_jwk: DPoP.dump(session.dpop_key),
        expires_at: session.expires_at
      }
    )
  end

  defp random_state do
    24
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
  end

  defp login_error(:invalid_handle), do: :invalid_handle
  defp login_error(_reason), do: :login_failed

  defp callback_error(:invalid_state), do: :invalid_state
  defp callback_error(_reason), do: :login_failed

  defp fetch_profile(handle) do
    case Profile.fetch(handle) do
      {:ok, profile} ->
        profile

      {:error, reason} ->
        Logger.warning("failed to fetch profile for #{handle}: #{inspect(reason)}")
        %{display_name: nil, avatar: nil}
    end
  end
end
