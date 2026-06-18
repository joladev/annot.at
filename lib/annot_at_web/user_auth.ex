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
    |> redirect(to: ~p"/dashboard")
  end

  def log_out_user(conn) do
    conn
    |> renew_session()
    |> redirect(to: ~p"/")
  end

  def require_authenticatd_user(conn, _opts) do
    if conn.assigns.current_scope do
      conn
    else
      conn
      |> put_flash(:error, "You must log in to access this page.")
      |> redirect(to: ~p"/login")
      |> halt()
    end
  end

  def redirect_if_user_is_authenticated(conn, _opts) do
    if conn.assigns.current_scope do
      conn
      |> redirect(to: ~p"/dashboard")
      |> halt()
    else
      conn
    end
  end

  def on_mount(:mount_current_scope, _params, session, socket) do
    {:cont, mount_current_scope(socket, session)}
  end

  def on_mount(:require_authenticated, _params, session, socket) do
    socket = mount_current_scope(socket, session)

    if socket.assigns.current_scope do
      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, "You must log in to access this page.")
        |> Phoenix.LiveView.redirect(to: ~p"/login")

      {:halt, socket}
    end
  end

  defp renew_session(conn) do
    conn
    |> configure_session(renew: true)
    |> clear_session()
  end

  defp mount_current_scope(socket, session) do
    Phoenix.Component.assign_new(socket, :current_scope, fn ->
      user =
        if user_id = session["user_id"] do
          Accounts.get_user(user_id)
        end

      Scope.for_user(user)
    end)
  end
end
