defmodule AnnotAt.Accounts do
  @moduledoc """
  Context module for accounts related database queries, such as looking up users.
  """

  import Ecto.Query, only: [from: 2]

  alias AnnotAt.Accounts.AtprotoSession
  alias AnnotAt.Accounts.OAuthLoginRequest
  alias AnnotAt.Accounts.User
  alias AnnotAt.Repo

  @spec get_user!(integer()) :: User.t()
  def get_user!(id) do
    Repo.get!(User, id)
  end

  def get_user(id) do
    Repo.get(User, id)
  end

  @spec get_user_by_did(String.t()) :: User.t() | nil
  def get_user_by_did(did) do
    Repo.get_by(User, did: did)
  end

  @spec get_atproto_session(integer()) :: AtprotoSession.t() | nil
  def get_atproto_session(user_id) do
    Repo.get_by(AtprotoSession, user_id: user_id)
  end

  @doc """
  Creates or updates a user and their atproto session for a login.

  The user is matches by DID and its cached fields refreshed. The session is
  one-per-user and fully replaced. Wrapped in a transaction so a login never
  leaves a user without its session.
  """
  @spec upsert_login(map(), map()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def upsert_login(user_attrs, session_attrs) do
    Repo.transact(fn ->
      with {:ok, user} <- upsert_user(user_attrs),
           {:ok, session} <- upsert_session(user.id, session_attrs) do
        {:ok, %{user | atproto_session: session}}
      end
    end)
  end

  @doc """
  Deletes a user's atproto session (logout), keeping the user record.
  """
  @spec delete_atproto_session(User.t()) :: :ok
  def delete_atproto_session(%User{id: user_id}) do
    Repo.delete_all(from(s in AtprotoSession, where: s.user_id == ^user_id))
    :ok
  end

  @spec upsert_user(map()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def upsert_user(user_attrs) do
    Repo.insert(User.changeset(%User{}, user_attrs),
      on_conflict: {:replace_all_except, [:id, :did, :inserted_at]},
      conflict_target: :did,
      returning: true
    )
  end

  @spec upsert_session(integer(), map()) ::
          {:ok, AtprotoSession.t()} | {:error, Ecto.Changeset.t()}
  def upsert_session(user_id, session_attrs) do
    Repo.insert(
      AtprotoSession.changeset(%AtprotoSession{user_id: user_id}, session_attrs),
      on_conflict: {:replace_all_except, [:id, :user_id, :inserted_at]},
      conflict_target: :user_id,
      returning: true
    )
  end

  @doc """
  Stores an in-progress login, keyed by its OAuth `state`.
  """
  @spec create_login_request(map()) :: {:ok, OAuthLoginRequest.t()} | {:error, Ecto.Changeset.t()}
  def create_login_request(request_attrs) do
    Repo.insert(OAuthLoginRequest.changeset(%OAuthLoginRequest{}, request_attrs))
  end

  @doc """
  Atomically fetches and deletes the login request for `state` or `nil`.

  Single use: a `state` is consumed exactly once, even under concurrent
  callbacks, since the delete and read happen in one statement.
  """
  @spec take_login_request(String.t()) :: OAuthLoginRequest.t() | nil
  def take_login_request(state) do
    query = from(r in OAuthLoginRequest, where: r.state == ^state, select: r)

    case Repo.delete_all(query) do
      {1, [request]} -> request
      {0, []} -> nil
    end
  end

  @doc """
  Deletes login requests older than `max_age_seconds` (abandoned logins.)
  """
  @spec delete_expired_login_requests(pos_integer()) :: non_neg_integer()
  def delete_expired_login_requests(max_age_seconds) do
    cutoff = DateTime.add(DateTime.utc_now(), -max_age_seconds, :second)
    {count, _} = Repo.delete_all(from(r in OAuthLoginRequest, where: r.inserted_at < ^cutoff))
    count
  end
end
