defmodule AnnotAtWeb.PostsLive do
  use AnnotAtWeb, :live_view

  alias AnnotAt.Atproto.StandardSite
  alias AnnotAt.Atproto.StandardSite.Document
  alias AnnotAt.Feeds.Client
  alias AnnotAt.Feeds.Entry
  alias AnnotAt.Publishing
  alias AnnotAt.Publishing.Post
  alias Phoenix.LiveView.AsyncResult
  alias Phoenix.LiveView.JS

  require Logger

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <Layouts.dashboard flash={@flash} current_scope={@current_scope} active={:sites}>
      <.link navigate={~p"/sites/#{@site.id}"} class="text-sm font-bold
    text-ink/50 hover:text-ink">
        ← {@site.url}
      </.link>
      <h1 class="mt-4 font-display text-3xl font-bold tracking-tight">Posts</h1>
      <p class="mt-1 text-ink/60">Publish your blog's posts to the
        ATmosphere.</p>

      <.async_result :let={feed} assign={@feed}>
        <:loading>
          <div class="mt-6 flex items-center gap-2 text-ink/60">
            <.icon name="hero-arrow-path" class="size-5 animate-spin" /> Reading
            the feed…
          </div>
        </:loading>
        <:failed :let={_}>
          <p class="mt-6 text-sm font-bold text-red-600">Couldn't read the
            feed.</p>
        </:failed>

        <div
          :if={feed.entries != []}
          class="mt-6 flex flex-col gap-3
         sm:flex-row sm:items-center sm:justify-between"
        >
          <p class="text-sm font-medium text-ink/55">
            {Enum.count(done(feed.entries, @posts))} of {length(feed.entries)} published
          </p>

          <.button
            variant="primary"
            shadow="secondary"
            disabled={
              @publishing_all? or
                not any_pending?(
                  feed.entries,
                  @posts
                )
            }
            phx-click={show_modal("publish-all-modal")}
          >
            <.icon :if={@publishing_all?} name="hero-arrow-path" class="size-5
     animate-spin" />
            {if @publishing_all?, do: "Publishing…", else: "Publish all"}
          </.button>
        </div>

        <p :if={feed.entries == []} class="mt-6 text-ink/55">No posts in this
          feed.</p>

        <div :if={pending(feed.entries, @posts) != []} class="mt-6 space-y-3">
          <div
            :for={entry <- pending(feed.entries, @posts)}
            class="flex items-center gap-4 rounded-2xl border-2 border-ink bg-paper p-4"
          >
            <.cover_thumb entry={entry} />

            <div class="min-w-0 flex-1">
              <div class="truncate font-bold">{entry.title}</div>
              <div :if={entry.summary} class="mt-0.5 truncate text-sm text-ink/55">
                {entry.summary}
              </div>
              <div class="mt-1 flex items-center gap-2 text-xs text-ink/45">
                <span :if={entry.published_at}>{Calendar.strftime(entry.published_at, "%b
          %d, %Y")}</span>
                <span
                  :if={entry.cover_status in [:too_large, :not_image]}
                  class="text-ink/45"
                >
                  {cover_note(entry.cover_status)}
                </span>
              </div>
            </div>

            <.button
              :if={has_date?(entry)}
              variant="primary"
              size="sm"
              disabled={is_nil(entry.rkey) or publishing?(@publishing, entry)}
              phx-value-guid={entry.id}
              phx-click={"select_post" |> JS.push() |> show_modal("publish-modal")}
            >
              <.icon
                :if={publishing?(@publishing, entry)}
                name="hero-arrow-path"
                class="size-4 animate-spin"
              />
              {if publishing?(@publishing, entry), do: "Publishing…", else: "Publish"}
            </.button>
            <span :if={not has_date?(entry)} class="flex-none text-xs text-ink/40">No
              date</span>
          </div>
        </div>

        <div :if={done(feed.entries, @posts) != []} class="mt-8">
          <div class="text-[11px] font-bold uppercase tracking-widest
        text-ink/40">Published</div>
          <div class="mt-3 space-y-2">
            <div
              :for={entry <- done(feed.entries, @posts)}
              class="flex items-center justify-between gap-3 rounded-2xl
        border-2 border-ink/15 px-4 py-3"
            >
              <.cover_thumb entry={entry} />

              <div class="min-w-0 flex-1">
                <div class="truncate font-bold text-ink/70">{entry.title}</div>
                <div :if={entry.summary} class="mt-0.5 truncate text-sm text-ink/50">
                  {entry.summary}
                </div>
                <div class="mt-1 flex items-center gap-2 text-xs text-ink/45">
                  <span class="flex items-center gap-1">
                    <.icon name="hero-check" class="size-3.5" /> Published
                  </span>
                  <span class="truncate text-ink/40">
                    {entry_to_post(
                      @posts,
                      entry
                    ).rkey}
                  </span>
                  <span :if={entry.cover_status in [:too_large, :not_image]}>
                    {cover_note(entry.cover_status)}
                  </span>
                </div>
              </div>

              <.button
                variant="ghost"
                size="sm"
                disabled={publishing?(@publishing, entry)}
                phx-value-guid={entry.id}
                phx-click={
                  JS.push("select_post")
                  |> show_modal("republish-modal")
                }
              >
                <.icon
                  name="hero-arrow-path"
                  class={["size-4", publishing?(@publishing, entry) && "animate-spin"]}
                />
                {if publishing?(@publishing, entry), do: "Re-publishing…", else: "Re-publish"}
              </.button>
            </div>
          </div>
        </div>

        <.confirm_modal
          id="publish-modal"
          title="Publish this post"
          confirm="publish_post"
          cta="Publish"
        >
          This writes a <span class="font-mono text-xs">site.standard.document</span>
          record to your atproto repo, making it publicly discoverable. You can re-publish to update it later.
        </.confirm_modal>

        <.confirm_modal
          id="republish-modal"
          title="Re-publish this post"
          confirm="republish_post"
          cta="Re-publish"
        >
          This overwrites the existing <span class="font-mono text-xs">site.standard.document</span>
          record with the latest content from your feed.
        </.confirm_modal>

        <.confirm_modal
          id="publish-all-modal"
          title="Publish all posts"
          confirm="publish_all_post"
          cta="Publish all"
        >
          This writes a <span class="font-mono text-xs">site.standard.document</span>
          record for every unpublished post in your feed, making each publicly discoverable. You can re-publish to update them later.
        </.confirm_modal>
      </.async_result>
    </Layouts.dashboard>
    """
  end

  @impl Phoenix.LiveView
  def mount(%{"id" => id}, _session, socket) do
    site = Publishing.get_site!(socket.assigns.current_scope, id)
    posts = Map.new(Publishing.list_posts(site), &{&1.guid, &1})

    socket =
      socket
      |> assign(
        page_title: "Posts",
        site: site,
        posts: posts,
        publishing_all?: false,
        selected_guid: nil,
        publishing: MapSet.new()
      )
      |> load_feed(site)

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("select_post", %{"guid" => guid}, socket) do
    {:noreply, assign(socket, selected_guid: guid)}
  end

  def handle_event("publish_post", _params, socket) do
    %{selected_guid: guid, site: site, current_scope: scope, feed: feed} =
      socket.assigns

    with %AsyncResult{ok?: true, result: %{entries: entries}} <- feed,
         %{published_at: %DateTime{}} = entry <- Enum.find(entries, &(&1.id == guid)) do
      socket =
        socket
        |> assign(publishing: MapSet.put(socket.assigns.publishing, guid))
        |> start_async({:publish, guid}, fn -> create_document(scope, site, entry) end)

      {:noreply, socket}
    else
      reason ->
        Logger.warning("PostsLive: failed to publish", reason: inspect(reason))
        {:noreply, put_flash(socket, :error, "Couldn't publish, try again.")}
    end
  end

  def handle_event("republish_post", _params, socket) do
    %{selected_guid: guid, site: site, current_scope: scope, feed: feed, posts: posts} =
      socket.assigns

    with %AsyncResult{ok?: true, result: %{entries: entries}} <- feed,
         %{published_at: %DateTime{}} = entry <-
           Enum.find(
             entries,
             &(&1.id ==
                 guid)
           ),
         {:ok, %Post{} = post} <- Map.fetch(posts, guid) do
      socket =
        socket
        |> assign(publishing: MapSet.put(socket.assigns.publishing, guid))
        |> start_async({:publish, guid}, fn -> update_document(scope, site, post, entry) end)

      {:noreply, socket}
    else
      reason ->
        Logger.warning("PostsLive: failed to re-publish", reason: inspect(reason))
        {:noreply, put_flash(socket, :error, "Couldn't re-publish, try again.")}
    end
  end

  def handle_event("publish_all_post", _params, socket) do
    %{site: site, current_scope: scope, feed: feed, posts: posts} =
      socket.assigns

    with %AsyncResult{ok?: true, result: %{entries: entries}} <- feed do
      to_publish =
        entries
        |> pending(posts)
        |> Enum.filter(fn post -> has_date?(post) && post.rkey end)

      socket =
        socket
        |> assign(publishing_all?: true)
        |> start_async(:publish_all, fn -> publish_all(scope, site, to_publish) end)

      {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_async(:publish_all, {:ok, new_posts}, socket) do
    socket =
      socket
      |> assign(publishing_all?: false)
      |> assign(posts: Map.merge(socket.assigns.posts, new_posts))

    {:noreply, socket}
  end

  def handle_async(:publish_all, {:exit, reason}, socket) do
    Logger.warning("PostsLive: failed to publish all", reason: inspect(reason))

    socket =
      socket
      |> assign(publishing_all?: false)
      |> put_flash(:error, "Some posts couldn't be published.")

    {:noreply, socket}
  end

  def handle_async({:publish, guid}, {:ok, {:ok, post}}, socket) do
    {:noreply,
     assign(socket,
       publishing: MapSet.delete(socket.assigns.publishing, guid),
       posts: Map.put(socket.assigns.posts, guid, post)
     )}
  end

  def handle_async({:publish, guid}, result, socket) do
    Logger.warning("PostsLive: write failed", reason: inspect(result), guid: guid)

    socket =
      socket
      |> assign(publishing: MapSet.delete(socket.assigns.publishing, guid))
      |> put_flash(:error, "Couldn't publish, try again.")

    {:noreply, socket}
  end

  def handle_async(:load_feed, {:ok, {:ok, %{feed: feed, posts: posts}}}, socket) do
    {:noreply,
     assign(socket,
       feed: AsyncResult.ok(socket.assigns.feed, feed),
       posts: posts
     )}
  end

  def handle_async(:load_feed, {:ok, reason}, socket) do
    Logger.warning("PostsLive: failed to load feed", reason: inspect(reason))
    {:noreply, assign(socket, feed: AsyncResult.failed(socket.assigns.feed, reason))}
  end

  defp load_feed(socket, site) do
    if connected?(socket) do
      user_did = socket.assigns.current_scope.user.did

      socket
      |> assign(feed: AsyncResult.loading())
      |> start_async(:load_feed, fn ->
        with {:ok, feed} <- Client.load(site.feed_url) do
          feed = Client.resolve_documents(feed, user_did)
          posts = Publishing.adopt(site, feed.entries)
          {:ok, %{feed: feed, posts: posts}}
        end
      end)
    else
      assign(socket, feed: AsyncResult.loading())
    end
  end

  defp to_document(entry, site, user) do
    %Document{
      rkey: entry.rkey,
      site: StandardSite.publication_uri(user.did, site.rkey),
      title: entry.title,
      path: path_of(entry.url),
      published_at: entry.published_at,
      description: entry.summary,
      text_content: text_content_of(entry.content),
      content: entry.content,
      cover_image: fetch_cover(entry),
      tags: entry.categories
    }
  end

  defp path_of(nil), do: nil
  defp path_of(url), do: URI.parse(url).path

  defp text_content_of(nil), do: nil

  defp text_content_of(content) do
    content
    |> LazyHTML.from_fragment()
    |> LazyHTML.text()
  end

  defp create_document(scope, site, entry) do
    document = to_document(entry, site, scope.user)

    with {:ok, _} <- StandardSite.put_document(scope.user.id, document) do
      Publishing.create_post(site, %{
        guid: entry.id,
        rkey: document.rkey,
        content_hash: Entry.hash(entry)
      })
    end
  end

  defp update_document(scope, site, %Post{} = post, entry) do
    document = to_document(entry, site, scope.user)

    with {:ok, _} <- StandardSite.put_document(scope.user.id, document) do
      Publishing.update_post(post, %{content_hash: Entry.hash(entry)})
    end
  end

  defp publish_all(scope, site, entries) do
    Enum.reduce(entries, %{}, fn entry, acc ->
      case create_document(scope, site, entry) do
        {:ok, post} -> Map.put(acc, entry.id, post)
        _ -> acc
      end
    end)
  end

  defp pending(entries, posts) do
    Enum.reject(entries, &Map.has_key?(posts, &1.id))
  end

  defp done(entries, posts) do
    Enum.filter(entries, &Map.has_key?(posts, &1.id))
  end

  defp any_pending?(entries, posts) do
    entries
    |> pending(posts)
    |> Enum.any?(&has_date?/1)
  end

  defp has_date?(entry), do: match?(%DateTime{}, entry.published_at)

  defp publishing?(publishing, entry), do: MapSet.member?(publishing, entry.id)

  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :confirm, :string, required: true
  attr :cta, :string, required: true
  slot :inner_block, required: true

  defp confirm_modal(assigns) do
    ~H"""
    <.modal id={@id}>
      <h2 class="font-display text-2xl font-bold tracking-tight">{@title}</h2>
      <p class="mt-2 text-sm text-ink/70">{render_slot(@inner_block)}</p>
      <div class="mt-6 flex justify-end gap-3">
        <.button phx-click={hide_modal(@id)}>Cancel</.button>
        <.button
          id={"#{@id}-confirm"}
          variant="primary"
          shadow="secondary"
          phx-click={JS.push(@confirm) |> hide_modal(@id)}
        >
          {@cta}
        </.button>
      </div>
    </.modal>
    """
  end

  defp entry_to_post(posts, %Entry{} = entry) do
    result =
      Enum.find(posts, fn {_key, %Post{} = post} ->
        post.guid == entry.id
      end)

    case result do
      {_key, value} ->
        value

      _ ->
        nil
    end
  end

  defp fetch_cover(%Entry{cover_status: status, image: url})
       when status in [:ok, :unknown] and is_binary(url) do
    case Client.fetch_image(url) do
      {:ok, image} -> image
      {:error, _} -> nil
    end
  end

  defp fetch_cover(_entry), do: nil

  defp cover_note(:too_large), do: "Cover image too large to publish (max 1MB)"
  defp cover_note(:not_image), do: "Cover image isn't a supported format"

  attr :entry, :map, required: true

  def cover_thumb(assigns) do
    ~H"""
    <img
      :if={@entry.cover_status in [:ok, :unknown] && @entry.image}
      src={@entry.image}
      alt=""
      class="aspect-[1.91/1] w-24 shrink-0 rounded-lg border-2 border-ink/15 object-cover"
    />
    <div
      :if={@entry.cover_status in [:too_large, :not_image]}
      title={cover_note(@entry.cover_status)}
      class="flex aspect-[1.91/1] w-24 shrink-0 items-center justify-center rounded-lg border-2 border-dashed border-ink/30 text-ink/35"
    >
      <.icon name="hero-exclamation-triangle" class="size-5" />
    </div>
    <div
      :if={@entry.cover_status == :none}
      class="flex aspect-[1.91/1] w-24 shrink-0 items-center justify-center rounded-lg border-2 border-dashed border-ink/10 text-ink/20"
    >
      <.icon name="hero-photo" class="size-5" />
    </div>
    """
  end
end
