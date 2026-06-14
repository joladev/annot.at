defmodule AnnotAt.AccountsTest do
  use AnnotAt.DataCase, async: true

  alias AnnotAt.Accounts
  alias AnnotAt.Accounts.AtprotoSession
  alias AnnotAt.Accounts.User

  @did "did:plc:ewvi7nxzyoun6zhxrhs64oiz"

  defp user_attrs(overrides \\ %{}) do
    Map.merge(
      %{
        did: @did,
        handle: "alice.test",
        pds_host: "https://pds.example.com",
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
        expires_at: ~U[2026-01-01 01:00:00Z]
      },
      overrides
    )
  end

  test "upsert_login/2 creates a user and session" do
    assert {:ok, user} = Accounts.upsert_login(user_attrs(), session_attrs())

    assert @did == user.did
    assert "alice.test" == user.handle
    assert %AtprotoSession{} = user.atproto_session
    assert "access-1" == user.atproto_session.access_token
  end

  test "upsert_login/2 updates the user and replaces the session on re-login" do
    {:ok, first} = Accounts.upsert_login(user_attrs(), session_attrs())

    {:ok, second} =
      Accounts.upsert_login(
        user_attrs(%{handle: "alice.new"}),
        session_attrs(%{access_token: "access-2", refresh_token: "refresh-2"})
      )

    assert first.id == second.id
    assert "alice.new" == second.handle
    assert "access-2" == second.atproto_session.access_token
    assert 1 == Repo.aggregate(User, :count)
    assert 1 == Repo.aggregate(AtprotoSession, :count)
  end

  test "upsert_login/2 rolls back and returns an error for invalid attrs" do
    assert {:error, changeset} = Accounts.upsert_login(%{handle: "x"}, session_attrs())
    assert %{did: ["can't be blank"]} = errors_on(changeset)
    assert 0 == Repo.aggregate(User, :count)
  end

  test "upsert_session/2 replaces the existing session for a user" do
    {:ok, user} = Accounts.upsert_user(user_attrs())
    {:ok, _} = Accounts.upsert_session(user.id, session_attrs())
    {:ok, replaced} = Accounts.upsert_session(user.id, session_attrs(%{access_token: "access-2"}))

    assert "access-2" == replaced.access_token
    assert 1 == Repo.aggregate(AtprotoSession, :count)
  end

  test "get_user_by_did/1 and get_atproto_session/1 fetch persisted records" do
    {:ok, user} = Accounts.upsert_login(user_attrs(), session_attrs())

    assert user.id == Accounts.get_user_by_did(@did).id
    assert "access-1" == Accounts.get_atproto_session(user.id).access_token
  end

  test "get_user_by_did/1 returns nil for an unknown DID" do
    refute Accounts.get_user_by_did("did:plc:nope")
  end

  test "delete_atproto_session/1 removes the session, keeping the user" do
    {:ok, user} = Accounts.upsert_login(user_attrs(), session_attrs())
    assert Accounts.get_atproto_session(user.id)

    assert :ok == Accounts.delete_atproto_session(user)

    refute Accounts.get_atproto_session(user.id)
    assert Accounts.get_user!(user.id)
  end
end
