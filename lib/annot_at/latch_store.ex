defmodule AnnotAt.LatchStore do
  @moduledoc false

  @behaviour Latch.Store

  alias AnnotAt.Accounts
  alias AnnotAt.Accounts.AtprotoSession
  alias AnnotAt.Accounts.OAuthLoginRequest
  alias Latch.Request
  alias Latch.Session

  require Logger

  @impl Latch.Store
  def take_request(state) do
    if row = Accounts.take_login_request(state) do
      {:ok, row_to_request(row)}
    else
      {:error, :not_found}
    end
  end

  @impl Latch.Store
  def put_request(_state, %Request{} = request, _ttl_seconds) do
    attrs = request_to_attrs(request)

    case Accounts.create_login_request(attrs) do
      {:ok, _} -> :ok
      {:error, changeset} -> backend_error(:put_request, request.did, changeset)
    end
  end

  @impl Latch.Store
  def fetch_session(did) do
    if row = Accounts.get_atproto_session(did) do
      {:ok, row_to_session(row)}
    else
      {:error, :not_found}
    end
  end

  @impl Latch.Store
  def put_session(did, %Session{} = session) do
    attrs = session_to_attrs(session)

    case Accounts.upsert_session(did, attrs) do
      {:ok, _} -> :ok
      {:error, changeset} -> backend_error(:put_session, did, changeset)
    end
  end

  @impl Latch.Store
  def delete_session(did) do
    Accounts.delete_atproto_session(did)
  end

  @impl Latch.Store
  def update_session(did, fun) do
    result =
      Accounts.with_locked_session(did, fn row ->
        session = row_to_session(row)

        case fun.(session) do
          {:ok, %Session{} = session} -> persist_session(did, session)
          {:error, _} = error -> error
        end
      end)

    translate_update_result(result)
  end

  defp persist_session(did, %Session{} = session) do
    attrs = session_to_attrs(session)

    case Accounts.upsert_session(did, attrs) do
      {:ok, _} -> {:ok, session}
      {:error, changeset} -> backend_error(:update_session, did, changeset)
    end
  end

  defp translate_update_result({:ok, session}), do: {:ok, session}
  defp translate_update_result({:error, :no_session}), do: {:error, :not_found}
  defp translate_update_result({:error, _} = error), do: error

  defp row_to_session(%AtprotoSession{} = row) do
    %Session{
      did: row.did,
      access_token: row.access_token,
      refresh_token: row.refresh_token,
      dpop_key: Jason.decode!(row.dpop_private_jwk),
      scope: row.granted_scopes,
      issuer: row.auth_server_issuer,
      pds_endpoint: row.pds_host,
      expires_at: row.expires_at
    }
  end

  defp session_to_attrs(%Session{} = session) do
    %{
      pds_host: session.pds_endpoint,
      auth_server_issuer: session.issuer,
      granted_scopes: session.scope,
      access_token: session.access_token,
      refresh_token: session.refresh_token,
      dpop_private_jwk: Jason.encode!(session.dpop_key),
      expires_at: session.expires_at
    }
  end

  defp row_to_request(%OAuthLoginRequest{} = row) do
    %Request{
      state: row.state,
      did: row.did,
      handle: row.handle,
      pds_endpoint: row.pds_host,
      issuer: row.auth_server_issuer,
      token_endpoint: row.token_endpoint,
      pkce_verifier: row.pkce_verifier,
      dpop_key: Jason.decode!(row.dpop_private_jwk)
    }
  end

  defp request_to_attrs(%Request{} = request) do
    %{
      state: request.state,
      did: request.did,
      handle: request.handle,
      pds_host: request.pds_endpoint,
      auth_server_issuer: request.issuer,
      token_endpoint: request.token_endpoint,
      pkce_verifier: request.pkce_verifier,
      dpop_private_jwk: Jason.encode!(request.dpop_key)
    }
  end

  defp backend_error(action, did, changeset) do
    Logger.error("latch_store #{action} did=#{inspect(did)}: #{inspect(changeset)}")
    {:error, :backend_error}
  end
end
