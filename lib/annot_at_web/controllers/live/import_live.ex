defmodule AnnotAtWeb.ImportLive do
  use AnnotAtWeb, :live_view

  alias AnnotAt.Atproto.StandardSite
  alias AnnotAt.Feeds.Client
  alias AnnotAt.Publishing
  alias AnnotAt.URL
  alias Phoenix.LiveView.AsyncResult

  require Logger

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <Layouts.dashboard flash={@flash} current_scope={@current_scope} active={:sites}>
      <.link
        navigate={~p"/sites?tab=discovered"}
        class="text-sm font-bold text-ink/50 hover:text-ink"
      >
        ← Discovered
      </.link>
      <h1 class="mt-4 font-display text-3xl font-bold tracking-tight">Import publication</h1>
      <p class="mt-1 text-ink/60">
        This publication already lives in your repo. Pick the feed to read posts from,
        and
        it's set up.
      </p>

      <.async_result :let={check} assign={@check}>
        <:loading>
          <div class="mt-6 flex items-center gap-2 text-ink/60">
            <.icon name="hero-arrow-path" class="size-5 animate-spin" /> Checking your .well-known…
          </div>
        </:loading>
        <:failed :let={_}>
          <p class="mt-6 text-sm font-bold text-red-600">Couldn't load that
            publication.</p>
        </:failed>

        <div class="mt-6 rounded-2xl border-2 border-ink bg-paper p-5">
          <div class="truncate font-display text-lg font-bold tracking-tight">
            {check.pub["name"] || check.pub["url"]}
          </div>
          <div class="mt-0.5 truncate text-sm text-ink/50">{check.pub["url"]}</div>
        </div>

        <%= if check.verified? do %>
          <div class="mt-6 flex items-center gap-1.5 text-sm text-ink/55">
            <.icon name="hero-check-circle" class="size-5 text-green-600" />
            Verified, you control this domain.
          </div>

          <h2 class="mt-8 font-display text-xl font-bold tracking-tight">Pick a feed</h2>
          <p class="mt-0.5 text-sm text-ink/60">
            Posts from this feed will show up in annot.at.
          </p>

          <.async_result :let={feeds} assign={@feeds}>
            <:loading>
              <div class="mt-6 flex items-center gap-2 text-ink/60">
                <.icon name="hero-arrow-path" class="size-5 animate-spin" /> Finding feeds…
              </div>
            </:loading>
            <:failed :let={_}>
              <p class="mt-6 text-sm font-bold text-red-600">Couldn't find feeds on this site.</p>
            </:failed>

            <p :if={feeds == []} class="mt-6 max-w-prose text-sm text-ink/60">
              No feeds found on this site. annot.at reads your posts from an RSS or Atom feed — add one to your blog and make sure it's linked from your homepage, then <.link
                href={~p"/sites/import/#{@rkey}"}
                class="font-bold underline hover:text-ink"
              >
              reload this page
              </.link>.
            </p>

            <div class="mt-6 space-y-3">
              <button
                :for={feed <- feeds}
                phx-click="pick_feed"
                phx-value-url={feed.url}
                class="group flex w-full cursor-pointer items-center gap-3 rounded-2xl
          border-2 border-ink bg-paper p-4 text-left transition-all hover:-translate-y-0.5
          hover:shadow-[5px_5px_0px_0px_var(--color-ink)]"
              >
                <.icon name="hero-rss" class="size-5 flex-none" />
                <div class="min-w-0 flex-1">
                  <div class="truncate font-bold">{feed.title || feed.url}</div>
                  <div class="truncate text-sm text-ink/50">{feed.url}</div>
                </div>
                <.icon
                  name="hero-arrow-right"
                  class="size-5 flex-none transition-transform group-hover:translate-x-1"
                />
              </button>
            </div>
          </.async_result>
        <% else %>
          <div class="mt-6 space-y-4">
            <p class="text-sm text-ink/70">
              This publication isn't verified yet. Host this file on your site, then
              check again:
            </p>
            <div class="rounded-xl border-2 border-ink bg-sky-light p-4">
              <div class="text-xs font-bold uppercase tracking-wide
    text-ink/55">Path</div>
              <code class="mt-1 block break-all text-sm font-medium">
                /.well-known/site.standard.publication
              </code>
              <div class="mt-3 text-xs font-bold uppercase tracking-wide
    text-ink/55">Contents</div>
              <code class="mt-1 block break-all text-sm
    font-medium">{check.at_uri}</code>
            </div>
            <.button variant="primary" shadow="secondary" phx-click="recheck">
              <.icon name="hero-arrow-path" class="size-5" /> Check again
            </.button>
          </div>
        <% end %>
      </.async_result>
    </Layouts.dashboard>
    """
  end

  @impl Phoenix.LiveView
  def mount(%{"rkey" => rkey}, _session, socket) do
    user = socket.assigns.current_scope.user

    socket =
      socket
      |> assign(
        page_title: "Import publication",
        rkey: rkey,
        check: AsyncResult.loading(),
        feeds: nil
      )
      |> start_async(:check, fn -> check_publication(user, rkey) end)

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("recheck", _params, socket) do
    user = socket.assigns.current_scope.user
    rkey = socket.assigns.rkey

    socket =
      socket
      |> assign(check: AsyncResult.loading(), feeds: nil)
      |> start_async(:check, fn -> check_publication(user, rkey) end)

    {:noreply, socket}
  end

  def handle_event("pick_feed", %{"url" => feed_url}, socket) do
    %{rkey: rkey, check: %{result: %{pub: pub}}, current_scope: scope} = socket.assigns

    case import_publication(scope, pub, rkey, feed_url) do
      {:ok, site} ->
        {:noreply, push_navigate(socket, to: ~p"/sites/#{site.id}")}

      {:error, reason} ->
        Logger.warning("ImportLive: import failed", reason: inspect(reason))
        {:noreply, put_flash(socket, :error, "Couldn't import, try again.")}
    end
  end

  @impl Phoenix.LiveView
  def handle_async(:check, {:ok, %{verified?: true} = result}, socket) do
    socket =
      socket
      |> assign(check: AsyncResult.ok(socket.assigns.check, result))
      |> assign(feeds: AsyncResult.loading())
      |> start_async(:load_feeds, fn -> Client.discover(result.pub["url"]) end)

    {:noreply, socket}
  end

  def handle_async(:check, {:ok, %{verified?: false} = result}, socket) do
    {:noreply, assign(socket, check: AsyncResult.ok(socket.assigns.check, result))}
  end

  def handle_async(:check, {:ok, {:error, reason}}, socket) do
    Logger.warning("ImportLive: check failed", reason: inspect(reason))
    {:noreply, assign(socket, check: AsyncResult.failed(socket.assigns.check, reason))}
  end

  def handle_async(:load_feeds, {:ok, {:ok, feeds}}, socket) do
    {:noreply, assign(socket, feeds: AsyncResult.ok(socket.assigns.feeds, feeds))}
  end

  def handle_async(:load_feeds, {:ok, {:error, reason}}, socket) do
    Logger.warning("ImportLive: feed discovery failed", reason: inspect(reason))
    {:noreply, assign(socket, feeds: AsyncResult.failed(socket.assigns.feeds, reason))}
  end

  defp check_publication(user, rkey) do
    case StandardSite.get_publication(user.id, rkey) do
      {:ok, pub} ->
        at_uri = StandardSite.publication_uri(user.did, rkey)
        verified? = StandardSite.verify_ownership(pub["url"], at_uri) == :ok
        %{pub: pub, at_uri: at_uri, verified?: verified?}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp import_publication(scope, pub, rkey, feed_url) do
    with {:ok, site} <- Publishing.create_site(scope, URL.canonical(pub["url"])),
         {:ok, site} <- Publishing.use_existing_publication(scope, site, rkey),
         {:ok, site} <- Publishing.update_site(scope, site, %{feed_url: feed_url}) do
      Publishing.mark_verified(scope, site)
    end
  end
end
