defmodule AnnotAtWeb.PostLive do
  use AnnotAtWeb, :live_view

  import AnnotAtWeb.DocumentComponents

  alias AnnotAt.Accounts
  alias AnnotAt.Atproto
  alias AnnotAt.Atproto.StandardSite
  alias AnnotAt.Atproto.StandardSite.Document
  alias AnnotAt.Publishing

  require Logger

  def render(assigns) do
    ~H"""
    <Layouts.dashboard flash={@flash} current_scope={@current_scope} active={:sites}>
      <.link navigate={~p"/sites/#{@site.id}/posts"} class="text-sm text-ink/60 hover:text-ink">
        ← Posts
      </.link>

      <div class="mt-6">
        <.document
          doc={@doc}
          author={author(@current_scope.user)}
          cover_url={cover_url(@current_scope.user, @doc)}
        />
      </div>
    </Layouts.dashboard>
    """
  end

  def mount(%{"id" => site_id, "rkey" => rkey}, _session, socket) do
    scope = socket.assigns.current_scope
    site = Publishing.get_site!(scope, site_id)

    case StandardSite.get_document(scope.user.id, rkey) do
      {:ok, doc} ->
        {:ok, assign(socket, site: site, doc: doc, page_title: doc.title)}

      {:error, error} ->
        Logger.warning("PostLive: unable to load post", reason: inspect(error))

        socket =
          socket
          |> put_flash(:error, "Couldn't load that post")
          |> push_navigate(to: ~p"/sites/#{site_id}/posts")

        {:ok, socket}
    end
  end

  defp author(user) do
    %{display_name: user.display_name, handle: user.handle, avatar_url: user.avatar_url}
  end

  defp cover_url(user, %Document{cover_image: %{} = blob}) do
    if session = Accounts.get_atproto_session(user.did) do
      Atproto.blob_url(session.pds_host, user.did, blob)
    end
  end

  defp cover_url(_user, _doc), do: nil
end
