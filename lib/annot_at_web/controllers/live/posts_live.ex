defmodule AnnotAtWeb.PostsLive do
  use AnnotAtWeb, :live_view

  alias AnnotAt.Accounts
  alias AnnotAt.Atproto
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

        <.async_result :let={documents} assign={@documents}>
          <:loading>
            <div class="mt-6 flex items-center gap-2 text-ink/60">
              <.icon name="hero-arrow-path" class="size-5 animate-spin" /> Reading your repo…
            </div>
          </:loading>
          <:failed :let={_}>
            <p class="mt-6 text-sm font-bold text-red-600">Couldn't read your repo.</p>
          </:failed>

          <% tabs = partition(feed.entries, documents) %>
          <% outside = outside_feed(feed.entries, documents) %>

          <nav class="mt-6 flex flex-wrap items-center gap-2">
            <.tab_link patch={~p"/sites/#{@site.id}/posts?tab=published"} active={@tab == :published}>
              Published ({length(tabs.published)})
            </.tab_link>
            <.tab_link
              patch={~p"/sites/#{@site.id}/posts?tab=unpublished"}
              active={@tab == :unpublished}
            >
              Unpublished ({length(tabs.unpublished)})
            </.tab_link>
            <.tab_link
              patch={~p"/sites/#{@site.id}/posts?tab=outside_feed"}
              active={@tab == :outside_feed}
            >
              Outside feed ({length(outside)})
            </.tab_link>
            <.tab_link patch={~p"/sites/#{@site.id}/posts?tab=setup"} active={@tab == :setup}>
              Setup needed ({length(tabs.setup)})
            </.tab_link>
            <div class="ml-auto">
              <.button
                variant="primary"
                shadow="secondary"
                disabled={
                  @publishing_all? or @tab != :unpublished or
                    not any_publishable?(tabs.unpublished)
                }
                phx-click={show_modal("publish-all-modal")}
              >
                <.icon :if={@publishing_all?} name="hero-arrow-path" class="size-5
     animate-spin" />
                {if @publishing_all?, do: "Publishing…", else: "Publish all"}
              </.button>
            </div>
          </nav>

          <%= case @tab do %>
            <% :published -> %>
              <p :if={tabs.published == []} class="mt-6 text-ink/55">
                Nothing published from this feed yet.
              </p>
              <div class="mt-6 space-y-3">
                <div
                  :for={{entry, doc} <- tabs.published}
                  class="flex items-center gap-4 rounded-2xl border-2 border-ink bg-paper p-4"
                >
                  <.document_thumb document={doc} pds_host={@pds_host} did={@current_scope.user.did} />

                  <div class="min-w-0 flex-1">
                    <.link
                      navigate={~p"/sites/#{@site.id}/posts/#{entry.rkey}"}
                      class="block truncate font-bold text-ink/70 hover:text-ink"
                    >
                      {entry.title}
                    </.link>
                    <div :if={entry.summary} class="mt-0.5 truncate text-sm text-ink/50">
                      {entry.summary}
                    </div>
                    <div class="mt-1 flex items-center gap-2 text-xs text-ink/45">
                      <span class="flex items-center gap-1">
                        <.icon name="hero-check" class="size-3.5" /> Published
                      </span>
                      <span class="truncate text-ink/40">{entry.rkey}</span>
                      <span :if={stale?(@posts, entry)} class="font-bold text-amber-600">
                        Changed since publish
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
                    phx-value-rkey={entry.rkey}
                    phx-click={JS.push("select_post") |> show_modal("republish-modal")}
                  >
                    <.icon
                      name="hero-arrow-path"
                      class={["size-4", publishing?(@publishing, entry) && "animate-spin"]}
                    />
                    {if publishing?(@publishing, entry), do: "Re-publishing…", else: "Re-publish"}
                  </.button>
                  <.button
                    id={"remove-#{entry.rkey}"}
                    aria-label="Remove"
                    variant="ghost"
                    size="sm"
                    phx-value-rkey={entry.rkey}
                    phx-click={JS.push("select_post") |> show_modal("delete-modal")}
                  >
                    <.icon name="hero-trash" class="size-4" />
                  </.button>
                </div>
              </div>
            <% :unpublished -> %>
              <p :if={tabs.unpublished == []} class="mt-6 text-ink/55">
                Everything in the feed is published.
              </p>

              <div class="mt-6 space-y-3">
                <div
                  :for={entry <- tabs.unpublished}
                  class="flex items-center gap-4 rounded-2xl border-2 border-ink bg-paper p-4"
                >
                  <.cover_thumb entry={entry} />

                  <div class="min-w-0 flex-1">
                    <div class="truncate font-bold">{entry.title}</div>
                    <div :if={entry.summary} class="mt-0.5 truncate text-sm text-ink/55">
                      {entry.summary}
                    </div>
                    <div class="mt-1 flex items-center gap-2 text-xs text-ink/45">
                      <span :if={entry.published_at}>
                        {Calendar.strftime(entry.published_at, "%b %d, %Y")}
                      </span>
                      <span :if={entry.cover_status in [:too_large, :not_image]}>
                        {cover_note(entry.cover_status)}
                      </span>
                    </div>
                  </div>

                  <.button
                    :if={has_date?(entry)}
                    variant="primary"
                    size="sm"
                    disabled={publishing?(@publishing, entry)}
                    phx-value-rkey={entry.rkey}
                    phx-click={JS.push("select_post") |> show_modal("publish-modal")}
                  >
                    <.icon
                      :if={publishing?(@publishing, entry)}
                      name="hero-arrow-path"
                      class="size-4 animate-spin"
                    />
                    {if publishing?(@publishing, entry), do: "Publishing…", else: "Publish"}
                  </.button>
                  <span :if={not has_date?(entry)} class="flex-none text-xs text-ink/40">No date</span>
                </div>
              </div>
            <% :outside_feed -> %>
              <p :if={outside == []} class="mt-6 text-ink/55">
                Every published document is in the current feed.
              </p>
              <div class="mt-6 space-y-3">
                <div
                  :for={doc <- outside}
                  class="flex items-center gap-4 rounded-2xl border-2 border-ink bg-paper p-4"
                >
                  <.document_thumb document={doc} pds_host={@pds_host} did={@current_scope.user.did} />
                  <div class="min-w-0 flex-1">
                    <.link
                      navigate={~p"/sites/#{@site.id}/posts/#{doc.rkey}"}
                      class="block truncate font-bold text-ink/70 hover:text-ink"
                    >
                      {doc.title}
                    </.link>
                    <div
                      :if={doc.description}
                      class="mt-0.5 truncate text-sm
                    text-ink/50"
                    >
                      {doc.description}
                    </div>
                    <div class="mt-1 flex items-center gap-2 text-xs text-ink/45">
                      <span class="flex items-center gap-1">
                        <.icon name="hero-check" class="size-3.5" /> Published
                      </span>
                      <span class="truncate text-ink/40">{doc.rkey}</span>
                      <span :if={doc.published_at}>
                        {Calendar.strftime(doc.published_at, "%b %d, %Y")}
                      </span>
                    </div>
                  </div>

                  <.button
                    id={"remove-#{doc.rkey}"}
                    aria-label="Remove"
                    variant="ghost"
                    size="sm"
                    phx-value-rkey={doc.rkey}
                    phx-click={JS.push("select_post") |> show_modal("delete-modal")}
                  >
                    <.icon name="hero-trash" class="size-4" />
                  </.button>
                </div>
              </div>
            <% :setup -> %>
              <div class="mt-6 max-w-prose space-y-4 text-sm text-ink/60">
                <p>
                  These posts don't declare a
                  <span class="font-mono text-xs">site.standard.document</span>
                  link, so annot.at doesn't know which record key to publish them under. To fix
                  that, each post's page needs a tag in its <span class="font-mono text-xs">&lt;head&gt;</span>:
                </p>

                <pre class="overflow-x-auto rounded-xl border-2 border-ink/15 bg-ink/5
             p-3 font-mono text-xs text-ink/75">&lt;link
      rel="site.standard.document"
      href="at://did:plc:your-did/site.standard.document/3lucidatid123"
    /&gt;</pre>

                <p>
                  The thing in the <code>href</code>
                  is the <.link
                    class="underline"
                    href="https://atproto.com/specs/at-uri-scheme"
                  >at-uri</.link>, the atproto standardized reference to a record. It consists of your <code>did</code>,
                  the collection <code>site.standard.document</code>, and the record key (<code>rkey</code>).
                  The standard requires record keys to be
                  <span class="font-bold text-ink/75">TIDs</span>
                  (<.link class="underline" href="https://atproto.com/specs/tid">timestamp identifiers</.link>),
                  sortable, roughly time-ordered keys like <span class="font-mono text-xs">3lucidatid123</span>. There are two
                  good ways to give each post a stable one:
                </p>

                <ul class="list-disc space-y-2 pl-5">
                  <li>
                    <span class="font-bold text-ink/75">Derive it
                    deterministically</span>
                    from something stable, like the post's publish date or a hash of its
                    URL. Given the same input, you get the same output, so your build can regenerate it on demand and
                    nothing needs to be stored. Here's an <.link
                      class="underline"
                      href="https://tangled.org/jola.dev/jola.dev/blob/2503ad1df3fb4a4018da279498fb761d60872613/lib/jola_dev_web/components/layouts/root.html.heex#L47-50"
                    >example of a statically generated blog doing that</.link>.
                  </li>
                  <li>
                    <span class="font-bold text-ink/75">Generate one and store it</span>
                    in the post's frontmatter, metadata, or on the post record if you've got a database backed site.
                    You can use a randomly generated one, as long as you store it and keep returning the same one.
                  </li>
                </ul>

                <p>
                  Whichever you pick, the key must be stable. If it changes, annot.at will be unable to connect the
                  page with the standard.site document record. Apps like Bluesky also use this record to check if they
                  should render the special preview frame, the <code>link</code>
                  on the page has to match the document record.
                </p>

                <p class="border-t-2 border-ink/10 pt-4 text-xs text-ink/45">
                  The TID requirement will hopefully be relaxed in a future version of
                  the
                  standard, so human-readable keys like your post slug would work too. <.link
                    href="https://tangled.org/standard.site/lexicons/issues/7"
                    target="_blank"
                    class="font-bold underline hover:text-ink"
                  >
                                   Join the discussion
                                 </.link>.
                </p>
              </div>
              <div class="mt-6 space-y-3">
                <div
                  :for={entry <- tabs.setup}
                  class="flex items-center gap-4 rounded-2xl border-2 border-dashed border-ink/25 p-4"
                >
                  <.cover_thumb entry={entry} />

                  <div class="min-w-0 flex-1">
                    <div class="truncate font-bold text-ink/60">{entry.title}</div>
                    <div :if={entry.summary} class="mt-0.5 truncate text-sm text-ink/45">
                      {entry.summary}
                    </div>
                  </div>
                </div>
              </div>
          <% end %>

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
            confirm="publish_post"
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

          <.confirm_modal
            id="delete-modal"
            title="Remove this post"
            confirm="delete_post"
            cta="Remove"
          >
            This deletes the <span class="font-mono
           text-xs">site.standard.document</span>
            record from your atproto repo. The blog post itself is untouched, and you can
            re-publish it later under the same record key.
          </.confirm_modal>
        </.async_result>
      </.async_result>
    </Layouts.dashboard>
    """
  end

  @impl Phoenix.LiveView
  def mount(%{"id" => id}, _session, socket) do
    site = Publishing.get_site!(socket.assigns.current_scope, id)
    posts = Map.new(Publishing.list_posts(site), &{&1.rkey, &1})
    user = socket.assigns.current_scope.user

    pds_host =
      if session = Accounts.get_atproto_session(user.did) do
        session.pds_host
      end

    socket =
      socket
      |> assign(
        page_title: "Posts",
        site: site,
        posts: posts,
        publishing_all?: false,
        selected_rkey: nil,
        publishing: MapSet.new(),
        pds_host: pds_host
      )
      |> load_feed(site)
      |> load_documents(site)

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(params, _uri, socket) do
    tab =
      case Map.get(params, "tab") do
        "unpublished" -> :unpublished
        "outside_feed" -> :outside_feed
        "setup" -> :setup
        _ -> :published
      end

    {:noreply, assign(socket, tab: tab)}
  end

  @impl Phoenix.LiveView
  def handle_event("select_post", %{"rkey" => rkey}, socket) do
    {:noreply, assign(socket, selected_rkey: rkey)}
  end

  def handle_event("publish_post", _params, socket) do
    %{selected_rkey: rkey, site: site, current_scope: scope, feed: feed} =
      socket.assigns

    with %AsyncResult{ok?: true, result: %{entries: entries}} <- feed,
         %{published_at: %DateTime{}} = entry <- Enum.find(entries, &(&1.rkey == rkey)) do
      socket =
        socket
        |> assign(publishing: MapSet.put(socket.assigns.publishing, rkey))
        |> start_async({:publish, rkey}, fn -> create_document(scope, site, entry) end)

      {:noreply, socket}
    else
      reason ->
        Logger.warning("PostsLive: failed to publish", reason: inspect(reason))
        {:noreply, put_flash(socket, :error, "Couldn't publish, try again.")}
    end
  end

  def handle_event("publish_all_post", _params, socket) do
    %{site: site, current_scope: scope, feed: feed, documents: documents} =
      socket.assigns

    with %AsyncResult{ok?: true, result: %{entries: entries}} <- feed,
         %AsyncResult{ok?: true, result: docs} <- documents do
      partitioned = partition(entries, docs)
      unpublished = Map.fetch!(partitioned, :unpublished)
      to_publish = Enum.filter(unpublished, &has_date?/1)

      socket =
        socket
        |> assign(publishing_all?: true)
        |> start_async(:publish_all, fn -> publish_all(scope, site, to_publish) end)

      {:noreply, socket}
    end
  end

  def handle_event("delete_post", _params, socket) do
    %{selected_rkey: rkey, site: site, current_scope: scope} = socket.assigns

    {:noreply, start_async(socket, {:delete, rkey}, fn -> delete_document(scope, site, rkey) end)}
  end

  @impl Phoenix.LiveView
  def handle_async(:publish_all, {:ok, {new_docs, new_posts}}, socket) do
    socket =
      socket
      |> assign(publishing_all?: false)
      |> assign(posts: Map.merge(socket.assigns.posts, new_posts))
      |> update_documents(&(Enum.reverse(new_docs) ++ &1))

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

  def handle_async({:publish, rkey}, {:ok, {:ok, {document, post}}}, socket) do
    socket =
      socket
      |> assign(
        publishing: MapSet.delete(socket.assigns.publishing, rkey),
        posts: Map.put(socket.assigns.posts, rkey, post)
      )
      |> upsert_document(document)

    {:noreply, socket}
  end

  def handle_async({:publish, rkey}, result, socket) do
    Logger.warning("PostsLive: write failed", reason: inspect(result), rkey: rkey)

    socket =
      socket
      |> assign(publishing: MapSet.delete(socket.assigns.publishing, rkey))
      |> put_flash(:error, "Couldn't publish, try again.")

    {:noreply, socket}
  end

  def handle_async(:load_feed, {:ok, {:ok, feed}}, socket) do
    {:noreply,
     assign(socket,
       feed: AsyncResult.ok(socket.assigns.feed, feed)
     )}
  end

  def handle_async(:load_feed, {:ok, reason}, socket) do
    Logger.warning("PostsLive: failed to load feed", reason: inspect(reason))
    {:noreply, assign(socket, feed: AsyncResult.failed(socket.assigns.feed, reason))}
  end

  def handle_async(:load_documents, {:ok, {:ok, documents}}, socket) do
    {:noreply, assign(socket, documents: AsyncResult.ok(socket.assigns.documents, documents))}
  end

  def handle_async(:load_documents, {:ok, reason}, socket) do
    Logger.warning("PostsLive: failed to load documents", reason: inspect(reason))
    {:noreply, assign(socket, documents: AsyncResult.failed(socket.assigns.documents, reason))}
  end

  def handle_async({:delete, rkey}, {:ok, :ok}, socket) do
    socket =
      socket
      |> assign(posts: Map.delete(socket.assigns.posts, rkey))
      |> update_documents(fn documents -> Enum.reject(documents, &(&1.rkey == rkey)) end)

    {:noreply, socket}
  end

  def handle_async({:delete, rkey}, result, socket) do
    Logger.warning("PostsLive: delete failed", reason: inspect(result), rkey: rkey)

    {:noreply, put_flash(socket, :error, "Couldn't remove, try again.")}
  end

  defp load_feed(socket, site) do
    if connected?(socket) do
      user_did = socket.assigns.current_scope.user.did

      socket
      |> assign(feed: AsyncResult.loading())
      |> start_async(:load_feed, fn ->
        with {:ok, feed} <- Client.load(site.feed_url) do
          {:ok, Client.resolve_documents(feed, user_did)}
        end
      end)
    else
      assign(socket, feed: AsyncResult.loading())
    end
  end

  defp load_documents(socket, site) do
    if connected?(socket) do
      user = socket.assigns.current_scope.user
      site_uri = StandardSite.publication_uri(user.did, site.rkey)

      socket
      |> assign(documents: AsyncResult.loading())
      |> start_async(:load_documents, fn ->
        with {:ok, documents} <- StandardSite.list_documents(user.id) do
          {:ok, Enum.filter(documents, &(&1.site == site_uri))}
        end
      end)
    else
      assign(socket, documents: AsyncResult.loading())
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
      content: if(entry.content, do: {:html, entry.content}),
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

    with {:ok, _} <- StandardSite.put_document(scope.user.id, document, fetch_cover(entry)),
         {:ok, post} <-
           Publishing.track_post(site, %{rkey: document.rkey, content_hash: Entry.hash(entry)}) do
      {:ok, {document, post}}
    end
  end

  defp delete_document(scope, site, rkey) do
    case StandardSite.delete_document(scope.user.id, rkey) do
      {:ok, _} ->
        Publishing.untrack_post(site, rkey)

      {:error, %Latch.Error.XRPC{body: %{"error" => "RecordNotFound"}}} ->
        Publishing.untrack_post(site, rkey)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp publish_all(scope, site, entries) do
    Enum.reduce(entries, {[], %{}}, fn entry, {documents, posts} ->
      case create_document(scope, site, entry) do
        {:ok, {document, post}} -> {[document | documents], Map.put(posts, document.rkey, post)}
        _ -> {documents, posts}
      end
    end)
  end

  defp partition(entries, documents) do
    documents_by_rkey = Map.new(documents, &{&1.rkey, &1})

    groups =
      Enum.group_by(entries, fn entry ->
        cond do
          is_nil(entry.rkey) -> :setup
          Map.has_key?(documents_by_rkey, entry.rkey) -> :published
          true -> :unpublished
        end
      end)

    published = Map.get(groups, :published, [])

    published_documents =
      Enum.map(published, fn entry ->
        {entry, Map.fetch!(documents_by_rkey, entry.rkey)}
      end)

    %{
      published: published_documents,
      unpublished: Map.get(groups, :unpublished, []),
      setup: Map.get(groups, :setup, [])
    }
  end

  defp outside_feed(entries, documents) do
    entry_rkeys = MapSet.new(entries, & &1.rkey)
    Enum.reject(documents, &MapSet.member?(entry_rkeys, &1.rkey))
  end

  defp stale?(posts, %Entry{} = entry) do
    case Map.fetch(posts, entry.rkey) do
      {:ok, %Post{content_hash: hash}} -> hash != Entry.hash(entry)
      :error -> false
    end
  end

  defp any_publishable?(entries), do: Enum.any?(entries, &has_date?/1)

  defp has_date?(entry), do: match?(%DateTime{}, entry.published_at)

  defp publishing?(publishing, entry), do: MapSet.member?(publishing, entry.rkey)

  defp update_documents(socket, fun) do
    documents = socket.assigns.documents
    assign(socket, documents: AsyncResult.ok(documents, fun.(documents.result)))
  end

  defp upsert_document(socket, document) do
    update_documents(socket, fn documents ->
      if Enum.any?(documents, &(&1.rkey == document.rkey)) do
        Enum.map(documents, fn doc ->
          if doc.rkey == document.rkey, do: document, else: doc
        end)
      else
        [document | documents]
      end
    end)
  end

  attr :patch, :string, required: true
  attr :active, :boolean, required: true
  slot :inner_block, required: true

  defp tab_link(assigns) do
    ~H"""
    <.link
      patch={@patch}
      class={[
        "rounded-full border-2 px-3 py-1 text-sm font-bold transition-colors",
        if(@active,
          do: "border-ink bg-ink text-paper",
          else: "border-ink/15 text-ink/55 hover:border-ink/40 hover:text-ink"
        )
      ]}
    >
      {render_slot(@inner_block)}
    </.link>
    """
  end

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

  attr :document, :map, required: true
  attr :pds_host, :string, default: nil
  attr :did, :string, required: true

  defp document_thumb(assigns) do
    ~H"""
    <img
      :if={document_cover_url(@pds_host, @did, @document)}
      src={document_cover_url(@pds_host, @did, @document)}
      alt=""
      class="aspect-[1.91/1] w-24 shrink-0 rounded-lg border-2 border-ink/15
    object-cover"
    />
    <div
      :if={is_nil(document_cover_url(@pds_host, @did, @document))}
      class="flex aspect-[1.91/1] w-24 shrink-0 items-center justify-center rounded-lg
    border-2 border-dashed border-ink/10 text-ink/20"
    >
      <.icon name="hero-photo" class="size-5" />
    </div>
    """
  end

  defp document_cover_url(pds_host, did, %Document{cover_image: %{} = blob})
       when is_binary(pds_host) do
    Atproto.blob_url(pds_host, did, blob)
  end

  defp document_cover_url(_pds_host, _did, _document), do: nil
end
