defmodule AnnotAt.Atproto.OAuth.Client do
  @moduledoc """
  Authenticated XRPC for a logged in user with transparent token refresh.

  Loads the user's stored session, ensures the access token is current
  (refreshing if not), and delegates to `XRPC`.
  """

  alias AnnotAt.Accounts
  alias AnnotAt.Atproto.OAuth.Config
  alias AnnotAt.Atproto.OAuth.Discovery
  alias AnnotAt.Atproto.OAuth.DPoP
  alias AnnotAt.Atproto.OAuth.Flow
  alias AnnotAt.Atproto.OAuth.Session
  alias AnnotAt.Atproto.XRPC

  require Logger

  @refresh_buffer_seconds 60

  @type error ::
          :no_session
          | :refresh_failed
          | :missing_dpop_nonce
          | :invalid_json
          | {:transport, term()}
          | {:xrpc_error, pos_integer(), map()}

  @doc """
  Performs an authenticated XRPC query for the user, refreshing if needed.
  """
  @spec query(integer(), String.t(), keyword()) :: {:ok, map()} | {:error, error()}
  def query(user_id, method, params \\ []) do
    call(user_id, fn session -> XRPC.query(session, method, params) end)
  end

  @doc """
  Performs and authenticated XRPC procedure for user, refreshing if needed.
  """
  @spec procedure(integer(), String.t(), map()) :: {:ok, map()} | {:error, error()}
  def procedure(user_id, method, body) do
    call(user_id, fn session -> XRPC.procedure(session, method, body) end)
  end

  @doc """
  Uploads a blob for the user, refreshing if needed. Returns the response
  containing the blob reference.
  """
  @spec upload_blob(integer(), binary(), String.t()) :: {:ok, map()} | {:error, error()}
  def upload_blob(user_id, bytes, content_type) do
    call(user_id, fn session -> XRPC.upload_blob(session, bytes, content_type) end)
  end

  defp call(user_id, fun) do
    with {:ok, session} <- fresh_session(user_id) do
      with {:error, {:xrpc_error, 401, _}} <- fun.(session) do
        with {:ok, refreshed} <- refresh(user_id, session.access_token) do
          fun.(refreshed)
        end
      end
    end
  end

  defp fresh_session(user_id) do
    case load(user_id) do
      nil ->
        {:error, :no_session}

      session ->
        if expired?(session) do
          refresh(user_id, session.access_token)
        else
          {:ok, session}
        end
    end
  end

  defp refresh(user_id, stale_token) do
    Accounts.with_locked_session(user_id, fn user, atproto_session ->
      session = to_session(user, atproto_session)

      if session.access_token == stale_token do
        do_refresh(user_id, session)
      else
        {:ok, session}
      end
    end)
  end

  defp do_refresh(user_id, session) do
    result =
      with {:ok, server} <- Discovery.discover(session.pds_endpoint),
           {:ok, new_session} <-
             Flow.refresh(server, session,
               client_id: Config.client_id(),
               client_jwk: Config.signing_key()
             ),
           {:ok, _} <- persist(user_id, new_session) do
        {:ok, new_session}
      end

    with {:error, reason} <- result do
      Logger.warning("token refresh failed for user #{user_id}: #{inspect(reason)}")
      {:error, :refresh_failed}
    end
  end

  defp persist(user_id, session) do
    Accounts.upsert_session(user_id, %{
      auth_server_issuer: session.issuer,
      granted_scopes: session.scope,
      access_token: session.access_token,
      refresh_token: session.refresh_token,
      dpop_private_jwk: DPoP.dump(session.dpop_key),
      expires_at: session.expires_at
    })
  end

  defp load(user_id) do
    user = Accounts.get_user(user_id)
    session = Accounts.get_atproto_session(user_id)

    if user && session do
      to_session(user, session)
    end
  end

  defp to_session(user, session) do
    %Session{
      did: user.did,
      access_token: session.access_token,
      refresh_token: session.refresh_token,
      dpop_key: DPoP.load(session.dpop_private_jwk),
      scope: session.granted_scopes,
      issuer: session.auth_server_issuer,
      pds_endpoint: user.pds_host,
      expires_at: session.expires_at
    }
  end

  defp expired?(session) do
    threshold = DateTime.add(DateTime.utc_now(), @refresh_buffer_seconds, :second)
    DateTime.compare(session.expires_at, threshold) != :gt
  end
end
