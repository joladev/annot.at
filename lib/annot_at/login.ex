defmodule AnnotAt.Login do
  @moduledoc """
  atproto OAuth login orchestration on top of Latch.
  """

  alias AnnotAt.Accounts
  alias AnnotAt.Accounts.User
  alias AnnotAt.Atproto.Profile
  alias Latch.Error.HandleNotFound
  alias Latch.Error.InvalidResponse
  alias Latch.Error.OAuth
  alias Latch.Error.SecurityViolation

  require Logger

  @spec start_login(String.t()) :: {:ok, String.t()} | {:error, :invalid_handle | :login_failed}
  def start_login(handle) when is_binary(handle) do
    case Latch.authorize(AnnotAt.Latch, handle) do
      {:ok, url} ->
        {:ok, url}

      {:error, %HandleNotFound{reason: :invalid_handle}} ->
        {:error, :invalid_handle}

      {:error, reason} ->
        Logger.warning("authorize failed: #{inspect(reason)}")
        {:error, :login_failed}
    end
  end

  @spec complete_login(map()) ::
          {:ok, User.t()}
          | {:error,
             {:oauth_error, String.t()} | :invalid_callback | :invalid_state | :login_failed}

  def complete_login(params) do
    case Latch.callback(AnnotAt.Latch, params) do
      {:ok, %{did: did, handle: handle}} ->
        profile = fetch_profile(handle)

        with {:error, changeset} <-
               Accounts.upsert_user(%{
                 did: did,
                 handle: handle,
                 handle_verified_at: DateTime.utc_now(:second),
                 display_name: profile.display_name,
                 avatar_url: profile.avatar_url
               }) do
          Logger.warning("upsert_user failed", changeset: inspect(changeset))
          {:error, :login_failed}
        end

      {:error, %OAuth{error: error}} ->
        {:error, {:oauth_error, error}}

      {:error, %SecurityViolation{reason: :state_mismatch}} ->
        {:error, :invalid_state}

      {:error, %SecurityViolation{}} ->
        {:error, :login_failed}

      {:error, %InvalidResponse{}} ->
        {:error, :invalid_callback}

      {:error, _} ->
        {:error, :login_failed}
    end
  end

  @spec logout(User.t()) :: :ok
  def logout(%User{did: did}) do
    Latch.delete_session(AnnotAt.Latch, did)
    :ok
  end

  defp fetch_profile(handle) do
    case Profile.fetch(handle) do
      {:ok, profile} ->
        profile

      {:error, reason} ->
        Logger.warning("failed to fetch profile for #{handle}: #{inspect(reason)}")
        %{display_name: nil, avatar_url: nil}
    end
  end
end
