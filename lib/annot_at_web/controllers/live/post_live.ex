defmodule AnnotAtWeb.PostLive do
  use AnnotAtWeb, :live_view

  import AnnotAtWeb.DocumentComponents

  alias AnnotAt.Atproto
  alias AnnotAt.Atproto.StandardSite
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

  def mount(%{"id" => site_id, "post_id" => post_id}, _session, socket) do
    scope = socket.assigns.current_scope
    site = Publishing.get_site!(scope, site_id)
    post = Publishing.get_post!(site, post_id)

    case StandardSite.get_document(scope.user.id, post.rkey) do
      {:ok, doc} ->
        {:ok, assign(socket, site: site, doc: doc, page_title: doc["title"])}

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

  defp cover_url(user, %{"coverImage" => blob}) do
    Atproto.blob_url(user.pds_host, user.did, blob)
  end

  defp cover_url(_user, _doc), do: nil
end
