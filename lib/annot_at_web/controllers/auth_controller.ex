defmodule AnnotAtWeb.AuthController do
  use AnnotAtWeb, :controller

  import AnnotAtWeb.UserAuth, only: [log_in_user: 2, log_out_user: 1]

  alias AnnotAt.Login

  def callback(conn, params) do
    case Login.complete_login(params) do
      {:ok, user} ->
        log_in_user(conn, user)

      {:error, reason} ->
        conn
        |> put_flash(:error, error_message(reason))
        |> redirect(to: ~p"/login")
    end
  end

  def delete(conn, _params) do
    if scope = conn.assigns.current_scope do
      Login.logout(scope.user)
    end

    log_out_user(conn)
  end

  def client_metadata(conn, _params) do
    metadata = Latch.client_metadata(AnnotAt.Latch)

    json(conn, metadata)
  end

  defp error_message(:invalid_state), do: "Your login link expired. Please try again."
  defp error_message({:oauth_error, _}), do: "Authorization was denied or failed."
  defp error_message(_reason), do: "Something went wrong. Please try again."
end
