defmodule AnnotAt.AccountsTest do
  use AnnotAt.DataCase, async: true

  alias AnnotAt.Accounts
  alias AnnotAt.Accounts.AtprotoSession
  alias AnnotAt.Accounts.OAuthLoginRequest
  alias AnnotAt.Accounts.User

  @did "did:plc:ewvi7nxzyoun6zhxrhs64oiz"

  describe "upsert_user/1" do
    test "creates a user" do
      assert {:ok, user} = Accounts.upsert_user(user_attrs())

      assert @did == user.did
      assert "jola.dev" == user.handle
    end

    test "upsert_user/1 updates the user on conflict" do
      {:ok, first} = Accounts.upsert_user(user_attrs())
      {:ok, second} = Accounts.upsert_user(user_attrs(%{handle: "johanna.cove.town"}))

      assert first.id == second.id
      assert "johanna.cove.town" == second.handle
      assert 1 == Repo.aggregate(User, :count)
    end
  end

  describe "upsert_session/2" do
    test "creates a session for a did" do
      {:ok, session} = Accounts.upsert_session(@did, session_attrs())

      assert @did == session.did
      assert "access-1" == session.access_token
    end

    test "replaces the existing session for a did" do
      {:ok, _} = Accounts.upsert_session(@did, session_attrs())

      {:ok, replaced} =
        Accounts.upsert_session(@did, session_attrs(%{access_token: "access-2"}))

      assert "access-2" == replaced.access_token
      assert 1 == Repo.aggregate(AtprotoSession, :count)
    end
  end

  test "get_user_by_did/1 and get_atproto_session/1 fetch persisted records" do
    {:ok, user} = Accounts.upsert_user(user_attrs())
    {:ok, _} = Accounts.upsert_session(@did, session_attrs())

    assert user.id == Accounts.get_user_by_did(@did).id
    assert "access-1" == Accounts.get_atproto_session(@did).access_token
  end

  test "get_user_by_did/1 returns nil for an unknown DID" do
    refute Accounts.get_user_by_did("did:plc:nope")
  end

  test "delete_atproto_session/1 removes the session" do
    {:ok, _} = Accounts.upsert_session(@did, session_attrs())
    assert Accounts.get_atproto_session(@did)

    assert :ok == Accounts.delete_atproto_session(@did)

    refute Accounts.get_atproto_session(@did)
  end

  test "create_login_request/1 then take_login_request/1 round-trips a login" do
    {:ok, _} = Accounts.create_login_request(login_request_attrs())

    request = Accounts.take_login_request("state-123")
    assert @did == request.did
    assert "verifier-123" == request.pkce_verifier
  end

  test "take_login_request/1 is single-use" do
    {:ok, _} = Accounts.create_login_request(login_request_attrs())

    assert Accounts.take_login_request("state-123")
    refute Accounts.take_login_request("state-123")
  end

  test "take_login_request/1 returns nil for an unknown state" do
    refute Accounts.take_login_request("nope")
  end

  test "delete_expired_login_requests/1 removes only old requests" do
    {:ok, old} = Accounts.create_login_request(login_request_attrs(%{state: "old"}))
    {:ok, _} = Accounts.create_login_request(login_request_attrs(%{state: "fresh"}))

    Repo.update_all(
      from(r in OAuthLoginRequest, where: r.id == ^old.id),
      set: [inserted_at: ~U[2020-01-01 00:00:00Z]]
    )

    assert 1 == Accounts.delete_expired_login_requests(3600)
    refute Accounts.take_login_request("old")
    assert Accounts.take_login_request("fresh")
  end

  defp login_request_attrs(overrides \\ %{}) do
    Map.merge(
      %{
        state: "state-123",
        did: @did,
        handle: "jola.dev",
        pds_host: "https://pds.example.com",
        auth_server_issuer: "https://bsky.social",
        pkce_verifier: "verifier-123",
        dpop_private_jwk: "{}",
        token_endpoint: "somethnig"
      },
      overrides
    )
  end

  defp user_attrs(overrides \\ %{}) do
    Map.merge(
      %{
        did: @did,
        handle: "jola.dev",
        handle_verified_at: ~U[2026-01-01 00:00:00Z]
      },
      overrides
    )
  end

  defp session_attrs(overrides \\ %{}) do
    Map.merge(
      %{
        auth_server_issuer: "https://bsky.social",
        granted_scopes: "atproto",
        access_token: "access-1",
        refresh_token: "refresh-1",
        dpop_private_jwk: "{}",
        expires_at: ~U[2026-01-01 01:00:00Z],
        pds_host: "https://pds.example.com"
      },
      overrides
    )
  end
end
