defmodule AnnotAtWeb.SiteLive do
  use AnnotAtWeb, :live_view

  alias AnnotAt.Atproto.StandardSite
  alias AnnotAt.Feeds.Client
  alias AnnotAt.Publishing
  alias AnnotAt.Publishing.Site
  alias AnnotAt.URL
  alias Phoenix.LiveView.AsyncResult

  @impl Phoenix.LiveView
  def mount(%{"id" => id}, _session, socket) do
    site = Publishing.get_site!(socket.assigns.current_scope, id)

    socket =
      socket
      |> assign(page_title: site.url, site: site)
      |> advance(phase(site))

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <Layouts.dashboard flash={@flash} current_scope={@current_scope} active={:overview}>
      <.link navigate={~p"/dashboard"} class="text-sm text-ink/60
     hover:text-ink">← Back</.link>

      <div class="mt-4 flex flex-col gap-3 sm:flex-row sm:items-center
     sm:justify-between">
        <h1 class="font-display text-3xl font-bold
     tracking-tight">{@site.url}</h1>

        <div :if={phase(@site) == :done} class="flex items-center gap-3">
          <span class="inline-flex items-center gap-1.5 rounded-full border-2
     border-ink bg-paper px-3 py-1.5 text-sm font-bold">
            <.icon name="hero-check-badge" class="size-5 text-green-600" /> Verified
          </span>
          <button
            :if={is_nil(@site.published_at)}
            phx-click="publish"
            class="inline-flex cursor-pointer items-center gap-1.5 rounded-xl
     border-2 border-ink bg-ink px-5 py-2.5 text-sm font-bold text-paper
     shadow-[4px_4px_0px_0px_var(--color-peach-bold)] transition-all
     hover:-translate-y-0.5 active:translate-y-0"
          >
            <.icon name="hero-paper-airplane" class="size-5" /> Publish
          </button>
        </div>
      </div>

      <div class="mt-8 space-y-3">
        <%= case phase(@site) do %>
          <% :done -> %>
            <.site_cards site={@site} record={@record} feed={@feed} />
          <% :feed -> %>
            <.feed_step feeds={@feeds} />
          <% :publication -> %>
            <.publication_step publications={@publications} />
          <% :well_known -> %>
            <.well_known_step verification={@verification} at_uri={@at_uri} />
        <% end %>
      </div>
    </Layouts.dashboard>
    """
  end

  @impl Phoenix.LiveView
  def handle_event("pick_feed", %{"url" => feed_url}, socket) do
    {:ok, site} =
      Publishing.update_site(socket.assigns.current_scope, socket.assigns.site, %{
        feed_url: feed_url
      })

    socket =
      socket
      |> assign(site: site)
      |> advance(phase(site))

    {:noreply, socket}
  end

  def handle_event("use_existing", %{"rkey" => rkey}, socket) do
    {:ok, site} =
      Publishing.use_existing_publication(socket.assigns.current_scope, socket.assigns.site, rkey)

    socket =
      socket
      |> assign(site: site)
      |> advance(phase(site))

    {:noreply, socket}
  end

  def handle_event("use_new", _params, socket) do
    {:ok, site} =
      Publishing.use_new_publication(socket.assigns.current_scope, socket.assigns.site)

    socket =
      socket
      |> assign(site: site)
      |> advance(phase(site))

    {:noreply, socket}
  end

  def handle_event("confirm_verified", _params, socket) do
    {:ok, site} = Publishing.mark_verified(socket.assigns.current_scope, socket.assigns.site)

    socket =
      socket
      |> assign(site: site)
      |> advance(phase(site))

    {:noreply, socket}
  end

  def handle_event("revalidate", _params, socket) do
    {:noreply, advance(socket, :well_known)}
  end

  def handle_event("publish", _params, socket) do
    {:noreply, put_flash(socket, :info, "Publishing to the Atmosphere is coming soon.")}
  end

  defp phase(%Site{verified_at: %DateTime{}}), do: :done
  defp phase(%Site{feed_url: nil}), do: :feed
  defp phase(%Site{rkey: nil}), do: :publication
  defp phase(%Site{}), do: :well_known

  defp advance(socket, :feed) do
    url = socket.assigns.site.url

    if connected?(socket) do
      assign_async(socket, :feeds, fn ->
        with {:ok, feeds} <- Client.discover(url) do
          {:ok, %{feeds: feeds}}
        end
      end)
    else
      assign(socket, feeds: AsyncResult.loading())
    end
  end

  defp advance(socket, :publication) do
    %{site: site, current_scope: scope} = socket.assigns

    if connected?(socket) do
      assign_async(socket, :publications, fn ->
        with {:ok, pubs} <- StandardSite.list_publications(scope.user.id) do
          {:ok, %{publications: Enum.filter(pubs, &matches_url?(&1, site.url))}}
        end
      end)
    else
      assign(socket, publications: AsyncResult.loading())
    end
  end

  defp advance(socket, :well_known) do
    %{site: site, current_scope: scope} = socket.assigns
    at_uri = StandardSite.publication_uri(scope.user.did, site.rkey)
    socket = assign(socket, at_uri: at_uri)

    if connected?(socket) do
      assign_async(socket, :verification, fn ->
        case StandardSite.verify_ownership(site.url, at_uri) do
          :ok -> {:ok, %{verification: :ok}}
          {:error, _reason} = error -> error
        end
      end)
    else
      assign(socket, verification: AsyncResult.loading())
    end
  end

  defp advance(socket, :done) do
    %{site: site, current_scope: scope} = socket.assigns

    if connected?(socket) do
      socket
      |> assign_async(:record, fn -> fetch_record(site, scope) end)
      |> assign_async(:feed, fn ->
        with {:ok, feed} <- Client.load(site.feed_url) do
          {:ok, %{feed: feed}}
        end
      end)
    else
      assign(socket, record: AsyncResult.loading(), feed: AsyncResult.loading())
    end
  end

  defp matches_url?(%{url: url}, site_url) when is_binary(url) do
    URL.canonical(url) == site_url
  end

  defp matches_url?(_pub, _site_url), do: false

  defp fetch_record(%Site{published_at: %DateTime{}} = site, scope) do
    with {:ok, doc} <- StandardSite.get_publication(scope.user.id, site.rkey) do
      {:ok, %{record: doc}}
    end
  end

  defp fetch_record(%Site{} = site, _scope) do
    with {:ok, metadata} <- Client.metadata(site.url) do
      {:ok, %{record: StandardSite.draft_publication(site.url, metadata)}}
    end
  end

  attr :feeds, :any, required: true

  defp feed_step(assigns) do
    ~H"""
    <div class="rounded-2xl border-2 border-ink bg-paper p-6">
      <div class="flex items-center gap-3">
        <div class="grid size-11 flex-none -rotate-3 place-items-center
    rounded-xl border-2 border-ink bg-sky-bold
    shadow-[3px_3px_0px_0px_var(--color-ink)]">
          <.icon name="hero-rss" class="size-6" />
        </div>
        <div>
          <h2 class="font-display text-xl font-bold tracking-tight">Discovering
            your feed</h2>
          <p class="text-sm text-ink/60">We look for an RSS or Atom feed on your
            site.</p>
        </div>
      </div>

      <.async_result :let={feeds} assign={@feeds}>
        <:loading>
          <div class="mt-6 flex items-center gap-2 text-ink/60">
            <.icon name="hero-arrow-path" class="size-5 animate-spin" /> Looking…
          </div>
        </:loading>
        <:failed :let={_}>
          <p class="mt-6 text-sm font-bold text-red-600">Couldn't reach the
            site.</p>
        </:failed>

        <p :if={feeds == []} class="mt-6 text-sm text-ink/60">No feed found on
          this site.</p>

        <div :if={feeds != []} class="mt-6 grid gap-3 sm:grid-cols-2">
          <button
            :for={feed <- feeds}
            phx-click="pick_feed"
            phx-value-url={feed.url}
            class="flex cursor-pointer flex-col items-start gap-2 rounded-2xl
    border-2 border-ink bg-paper p-4 text-left transition-all
    shadow-[4px_4px_0px_0px_var(--color-sky-bold)] hover:-translate-y-0.5
    hover:shadow-[6px_6px_0px_0px_var(--color-sky-bold)] active:translate-y-0
    active:shadow-[2px_2px_0px_0px_var(--color-sky-bold)]"
          >
            <span class="inline-flex items-center rounded-full border-2
    border-ink bg-peach-light px-2.5 py-0.5 text-xs font-bold uppercase
    tracking-wide">
              {feed.format}
            </span>
            <span class="font-bold leading-snug">{feed.title || "Untitled
    feed"}</span>
            <span class="w-full truncate text-xs text-ink/50">{feed.url}</span>
          </button>
        </div>
      </.async_result>
    </div>
    """
  end

  attr :publications, :any, required: true

  defp publication_step(assigns) do
    ~H"""
    <div class="rounded-2xl border-2 border-ink bg-paper p-6">
      <div class="flex items-center gap-3">
        <div class="grid size-11 flex-none -rotate-3 place-items-center
    rounded-xl border-2 border-ink bg-peach-bold
    shadow-[3px_3px_0px_0px_var(--color-ink)]">
          <.icon name="hero-newspaper" class="size-6" />
        </div>
        <div>
          <h2 class="font-display text-xl font-bold tracking-tight">Your
            publication</h2>
          <p class="text-sm text-ink/60">Reuse a publication you already have,
            or create a new one.</p>
        </div>
      </div>

      <.async_result :let={publications} assign={@publications}>
        <:loading>
          <div class="mt-6 flex items-center gap-2 text-ink/60">
            <.icon name="hero-arrow-path" class="size-5 animate-spin" /> repo.
          </div>
        </:loading>

        <div :if={publications != []} class="mt-6 grid gap-3 sm:grid-cols-2">
          <button
            :for={pub <- publications}
            phx-click="use_existing"
            phx-value-rkey={pub.rkey}
            class="flex cursor-pointer flex-col items-start gap-2 rounded-2xl
    border-2 border-ink bg-paper p-4 text-left transition-all
    shadow-[4px_4px_0px_0px_var(--color-peach-bold)] hover:-translate-y-0.5
    hover:shadow-[6px_6px_0px_0px_var(--color-peach-bold)] active:translate-y-0
    active:shadow-[2px_2px_0px_0px_var(--color-peach-bold)]"
          >
            <span class="inline-flex items-center rounded-full border-2
    border-ink bg-sky-light px-2.5 py-0.5 text-xs font-bold uppercase
    tracking-wide">
              Existing
            </span>
            <span class="font-bold leading-snug">{pub.name || "Untitled
    publication"}</span>
            <span class="w-full truncate text-xs text-ink/50">{pub.rkey}</span>
          </button>
        </div>

        <button
          phx-click="use_new"
          class="mt-6 flex w-full cursor-pointer items-center gap-3 rounded-2xl
    border-2 border-dashed border-ink bg-sky-light p-4 text-left transition-all
    hover:-translate-y-0.5 active:translate-y-0"
        >
          <.icon name="hero-plus-circle" class="size-6 flex-none" />
          <div>
            <div class="font-bold">Create a new publication</div>
            <div class="text-xs text-ink/55">We'll mint a fresh record for this
              site.</div>
          </div>
        </button>
      </.async_result>
    </div>
    """
  end

  attr :verification, :any, required: true
  attr :at_uri, :string, required: true

  defp well_known_step(assigns) do
    ~H"""
    <div class="rounded-2xl border-2 border-ink bg-paper p-6">
      <div class="flex items-center gap-3">
        <div class="grid size-11 flex-none -rotate-3 place-items-center
    rounded-xl border-2 border-ink bg-sky-bold
    shadow-[3px_3px_0px_0px_var(--color-ink)]">
          <.icon name="hero-shield-check" class="size-6" />
        </div>
        <div>
          <h2 class="font-display text-xl font-bold tracking-tight">Verify your
            domain</h2>
          <p class="text-sm text-ink/60">Prove you control this site by hosting
            a small file.</p>
        </div>
      </div>

      <.async_result :let={_v} assign={@verification}>
        <:loading>
          <div class="mt-6 flex items-center gap-2 text-ink/60">
            <.icon name="hero-arrow-path" class="size-5 animate-spin" /> Checking your .well-known…
          </div>
        </:loading>
        <:failed :let={_reason}>
          <div class="mt-6 space-y-4">
            <p class="text-sm text-ink/70">Host this file on your site, then
              check again:</p>
            <div class="rounded-xl border-2 border-ink bg-sky-light p-4">
              <div class="text-xs font-bold uppercase tracking-wide
    text-ink/55">Path</div>
              <code class="mt-1 block break-all text-sm
    font-medium">
                /.well-known/site.standard.publication
              </code>
              <div class="mt-3 text-xs font-bold uppercase tracking-wide
    text-ink/55">Contents</div>
              <code class="mt-1 block break-all text-sm
    font-medium">{@at_uri}</code>
            </div>
            <button
              phx-click="revalidate"
              class="inline-flex cursor-pointer items-center gap-1.5 rounded-xl
    border-2 border-ink bg-paper px-5 py-3 text-sm font-bold transition-all
    hover:-translate-y-0.5 active:translate-y-0"
            >
              <.icon name="hero-arrow-path" class="size-5" /> Check again
            </button>
          </div>
        </:failed>

        <div class="mt-6 space-y-4">
          <div class="flex items-center gap-2 font-bold text-green-600">
            <.icon name="hero-check-circle" class="size-6" /> Verified, you
            control this domain.
          </div>
          <button
            phx-click="confirm_verified"
            class="inline-flex cursor-pointer items-center gap-1.5 rounded-xl
    border-2 border-ink bg-ink px-6 py-3 text-sm font-bold text-paper transition-all
    hover:-translate-y-0.5 active:translate-y-0"
          >
            Finish setup <.icon name="hero-arrow-right" class="size-5" />
          </button>
        </div>
      </.async_result>
    </div>
    """
  end

  attr :icon, :string, required: true
  attr :title, :string, required: true
  attr :tint, :string, default: "sky"
  slot :badge
  slot :inner_block, required: true
  slot :actions

  defp info_card(assigns) do
    ~H"""
    <div class={[
      "rounded-2xl border-2 border-ink p-6",
      @tint == "sky" && "bg-sky-light
    shadow-[6px_6px_0px_0px_var(--color-sky-bold)]",
      @tint == "peach" && "bg-peach-light
    shadow-[6px_6px_0px_0px_var(--color-peach-bold)]"
    ]}>
      <div class="flex items-start justify-between gap-3">
        <div class="flex items-center gap-3">
          <div class={[
            "grid size-10 flex-none -rotate-3 place-items-center rounded-xl
    border-2 border-ink shadow-[2px_2px_0px_0px_var(--color-ink)]",
            @tint == "sky" && "bg-sky-bold",
            @tint == "peach" && "bg-peach-bold"
          ]}>
            <.icon name={@icon} class="size-5" />
          </div>
          <h3 class="font-display text-lg font-bold
    tracking-tight">{@title}</h3>
        </div>
        <div :if={@badge != []}>{render_slot(@badge)}</div>
      </div>

      <div class="mt-4">{render_slot(@inner_block)}</div>

      <div :if={@actions != []} class="mt-4 flex items-center gap-2 border-t-2
    border-ink/20 pt-3">
        {render_slot(@actions)}
      </div>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :value, :string, default: nil

  defp record_field(assigns) do
    ~H"""
    <div>
      <dt class="text-xs font-bold uppercase tracking-wide
    text-ink/45">{@label}</dt>
      <dd :if={@value} class="break-all font-medium">{@value}</dd>
      <dd :if={is_nil(@value)} class="text-sm italic text-ink/40">Not set
        yet</dd>
    </div>
    """
  end

  attr :site, :map, required: true
  attr :record, :any, required: true
  attr :feed, :any, required: true

  defp site_cards(assigns) do
    ~H"""
    <div class="grid gap-5 sm:grid-cols-2">
      <.info_card icon="hero-rss" title="Feed" tint="sky">
        <:badge>
          <span
            :if={@feed.ok?}
            class="inline-flex items-center gap-1 rounded-full border-2
    border-ink bg-paper px-2.5 py-0.5 text-xs font-bold text-ink/60"
          >
            <.icon name="hero-clock" class="size-3.5" /> Checked just now
          </span>
        </:badge>

        <.async_result :let={feed} assign={@feed}>
          <:loading>
            <div class="flex items-center gap-2 text-ink/60">
              <.icon name="hero-arrow-path" class="size-5 animate-spin" /> Reading the feed…
            </div>
          </:loading>
          <:failed :let={_}>
            <p class="text-sm font-bold text-red-600">Couldn't read the
              feed.</p>
          </:failed>

          <div class="space-y-3">
            <%= case List.first(feed.entries) do %>
              <% nil -> %>
                <p class="text-sm text-ink/60">No posts in this feed yet.</p>
              <% latest -> %>
                <div>
                  <dt class="text-xs font-bold uppercase tracking-wide
    text-ink/45">Latest post</dt>
                  <dd class="font-medium">{latest.title}</dd>
                  <dd :if={latest.published_at} class="mt-0.5 text-xs
    text-ink/50">
                    {Calendar.strftime(latest.published_at, "%b %d, %Y")}
                  </dd>
                </div>
            <% end %>

            <p class="text-sm font-medium text-ink/55">{length(feed.entries)} posts in the feed</p>
          </div>
        </.async_result>

        <a
          href={@site.feed_url}
          target="_blank"
          rel="noopener"
          class="mt-4 block break-all font-mono text-xs text-ink/40
    hover:text-ink/70"
        >
          {@site.feed_url}
        </a>
      </.info_card>

      <.info_card icon="hero-newspaper" title="Publication" tint="peach">
        <:badge>
          <span class={[
            "rounded-full border-2 border-ink px-2.5 py-0.5 text-xs font-bold",
            @site.published_at && "bg-sky-light",
            is_nil(@site.published_at) && "bg-peach-light"
          ]}>
            {if @site.published_at, do: "Published", else: "Not published yet"}
          </span>
        </:badge>

        <.async_result :let={record} assign={@record}>
          <:loading>
            <div class="flex items-center gap-2 text-ink/60">
              <.icon name="hero-arrow-path" class="size-5 animate-spin" /> Reading your site…
            </div>
          </:loading>
          <:failed :let={_}>
            <p class="text-sm font-bold text-red-600">Couldn't read your
              site.</p>
          </:failed>

          <dl class="space-y-3">
            <.record_field label="Name" value={record["name"]} />
            <.record_field label="URL" value={record["url"]} />
            <.record_field label="Description" value={record["description"]} />
            <.record_field label="Type" value={record["$type"]} />
            <div>
              <dt class="text-xs font-bold uppercase tracking-wide
    text-ink/45">Show in discover</dt>
              <dd class="font-medium">
                {if get_in(record, ["preferences", "showInDiscover"]),
                  do: "Yes",
                  else: "No"}
              </dd>
            </div>
          </dl>
        </.async_result>
      </.info_card>
    </div>
    """
  end
end
