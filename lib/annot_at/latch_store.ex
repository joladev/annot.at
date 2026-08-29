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
      trace("take_request", row.did, handle: row.handle)
      {:ok, row_to_request(row)}
    else
      trace("take_request.not_found", nil, [])
      {:error, :not_found}
    end
  end

  @impl Latch.Store
  def put_request(_state, %Request{} = request, _ttl_seconds) do
    attrs = request_to_attrs(request)

    trace("put_request", request.did, handle: request.handle)

    case Accounts.create_login_request(attrs) do
      {:ok, _} -> :ok
      {:error, changeset} -> backend_error(:put_request, request.did, changeset)
    end
  end

  @impl Latch.Store
  def fetch_session(did) do
    if row = Accounts.get_atproto_session(did) do
      trace("fetch_session", did, row_fields(row))
      {:ok, row_to_session(row)}
    else
      trace("fetch_session.not_found", did, [])
      {:error, :not_found}
    end
  end

  @impl Latch.Store
  def put_session(did, %Session{} = session) do
    attrs = session_to_attrs(session)

    trace("put_session.in", did, session_fields(session))

    case Accounts.upsert_session(did, attrs) do
      {:ok, row} ->
        trace("put_session.stored", did, row_fields(row))
        verify(did, "put_session")
        :ok

      {:error, changeset} ->
        backend_error(:put_session, did, changeset)
    end
  end

  @impl Latch.Store
  def delete_session(did) do
    trace("delete_session", did, [])
    Accounts.delete_atproto_session(did)
  end

  @impl Latch.Store
  def update_session(did, fun) do
    result =
      Accounts.with_locked_session(did, fn row ->
        session = row_to_session(row)

        trace("update_session.in", did, row_fields(row))

        case fun.(session) do
          {:ok, %Session{} = updated} ->
            trace(
              "update_session.out",
              did,
              [rotated: updated.refresh_token != session.refresh_token] ++
                session_fields(updated)
            )

            persist_session(did, updated)

          {:error, reason} = error ->
            trace("update_session.refresh_failed", did, reason: inspect(reason))
            error
        end
      end)

    trace("update_session.committed", did, outcome: outcome(result))
    verify(did, "update_session")

    translate_update_result(result)
  end

  defp persist_session(did, %Session{} = session) do
    attrs = session_to_attrs(session)

    case Accounts.upsert_session(did, attrs) do
      {:ok, row} ->
        trace("update_session.stored", did, row_fields(row))
        {:ok, session}

      {:error, changeset} ->
        backend_error(:update_session, did, changeset)
    end
  end

  defp translate_update_result({:ok, session}), do: {:ok, session}
  defp translate_update_result({:error, :no_session}), do: {:error, :not_found}
  defp translate_update_result({:error, _} = error), do: error

  # Reads the row back outside the transaction that wrote it, so a write that
  # reported success but did not survive the commit is visible on its own.
  defp verify(did, after_what) do
    case Accounts.get_atproto_session(did) do
      nil -> trace("verify.missing", did, after: after_what)
      row -> trace("verify", did, [after: after_what] ++ row_fields(row))
    end
  end

  defp outcome({:ok, %Session{} = session}), do: "ok refresh=" <> digest(session.refresh_token)
  defp outcome({:error, reason}), do: "error " <> inspect(reason)
  defp outcome(other), do: inspect(other)

  defp row_fields(%AtprotoSession{} = row) do
    [
      refresh: digest(row.refresh_token),
      access: digest(row.access_token),
      dpop: digest(row.dpop_private_jwk),
      expires_at: to_string(row.expires_at),
      row_updated_at: to_string(row.updated_at)
    ]
  end

  defp session_fields(%Session{} = session) do
    [
      refresh: digest(session.refresh_token),
      access: digest(session.access_token),
      dpop: digest(Jason.encode!(session.dpop_key)),
      expires_at: to_string(session.expires_at)
    ]
  end

  # Short, non-reversible fingerprint. Never log credential material itself.
  defp digest(nil), do: "nil"

  defp digest(value) when is_binary(value) do
    :sha256
    |> :crypto.hash(value)
    |> Base.encode16(case: :lower)
    |> binary_part(0, 8)
  end

  defp trace(event, did, fields) do
    Logger.info(
      "latch_store #{event}",
      [latch_trace: event, did: did, latch_node: to_string(node()), caller: inspect(self())] ++
        fields
    )
  end

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
