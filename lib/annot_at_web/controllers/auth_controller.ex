defmodule AnnotAtWeb.AuthController do
  use AnnotAtWeb, :controller

  import AnnotAtWeb.UserAuth, only: [log_in_user: 2, log_out_user: 1]

  alias AnnotAt.Atproto.OAuth.ClientMetadata
  alias AnnotAt.Atproto.OAuth.Config
  alias AnnotAt.Atproto.OAuth.Login

  def new(conn, _params) do
    render(conn, :new, handle: "")
  end

  def create(conn, %{"handle" => handle}) do
    case Login.start_login(handle) do
      {:ok, url} ->
        redirect(conn, external: url)

      {:error, reason} ->
        conn
        |> put_flash(:error, error_message(reason))
        |> render(:new, handle: handle)
    end
  end

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
    metadata =
      ClientMetadata.build(
        client_id: Config.client_id(),
        redirect_uris: [Config.redirect_uri()],
        scope: Config.scope(),
        jwk: Config.signing_key(),
        client_name: "annot.at"
      )

    json(conn, metadata)
  end

  defp error_message(:invalid_handle), do: "That doesn't look like a valid handle."
  defp error_message(:invalid_state), do: "Your login link expired. Please try again."
  defp error_message({:oauth_error, _}), do: "Authorization was denied or failed."
  defp error_message(_reason), do: "Something went wrong. Please try again."
end
