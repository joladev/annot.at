defmodule AnnotAtWeb.UserAuth do
  @moduledoc false

  use AnnotAtWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller

  alias AnnotAt.Accounts
  alias AnnotAt.Accounts.Scope

  @doc """
  Assigns :current_scope from the user_id in the session.
  """
  def fetch_current_scope(conn, _opts) do
    user =
      if user_id = get_session(conn, :user_id) do
        Accounts.get_user(user_id)
      end

    assign(conn, :current_scope, Scope.for_user(user))
  end

  @doc """
  Renews the session, stores ID, redirects.
  """
  def log_in_user(conn, user) do
    conn
    |> renew_session()
    |> put_session(:user_id, user.id)
    |> redirect(to: ~p"/")
  end

  def log_out_user(conn) do
    conn
    |> renew_session()
    |> redirect(to: ~p"/")
  end

  defp renew_session(conn) do
    conn
    |> configure_session(renew: true)
    |> clear_session()
  end
end
