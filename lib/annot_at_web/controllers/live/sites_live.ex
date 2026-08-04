defmodule AnnotAtWeb.SitesLive do
  use AnnotAtWeb, :live_view

  import AnnotAtWeb.SiteComponents, only: [site_row: 1]

  alias AnnotAt.Atproto.StandardSite
  alias AnnotAt.Publishing
  alias AnnotAt.Publishing.Site
  alias Phoenix.LiveView.AsyncResult

  require Logger

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <Layouts.dashboard flash={@flash} current_scope={@current_scope} active={:sites}>
      <div class="flex flex-col gap-4 sm:flex-row sm:items-center
    sm:justify-between">
        <h1 class="font-display text-3xl font-bold tracking-tight">Sites</h1>
        <.link
          navigate={~p"/sites/new"}
          class="inline-flex items-center gap-1.5 self-start rounded-xl border-2
    border-ink bg-ink px-5 py-2.5 text-sm font-bold text-paper
    shadow-[4px_4px_0px_0px_var(--color-peach-bold)] transition-all
    hover:-translate-y-0.5 active:translate-y-0"
        >
          <.icon name="hero-plus" class="size-5" /> Add a site
        </.link>
      </div>

      <nav class="mt-6 flex flex-wrap items-center gap-2">
        <.tab_link patch={~p"/sites?tab=setup"} active={@tab == :setup}>
          Set up ({length(@sites)})
        </.tab_link>
        <.tab_link patch={~p"/sites?tab=discovered"} active={@tab == :discovered}>
          Discovered ({length(@discovered)})
        </.tab_link>
      </nav>

      <%= case @tab do %>
        <% :setup -> %>
          <div class="mt-6 flex flex-wrap gap-2">
            <button
              :for={f <- ["all", "draft", "verified", "published"]}
              phx-click="filter"
              phx-value-status={f}
              class={[
                "rounded-full border-2 border-ink px-4 py-1.5 text-sm font-bold
    transition-all",
                @filter == f && "bg-ink text-paper",
                @filter != f && "bg-paper hover:bg-sky-light"
              ]}
            >
              {filter_label(f)}
            </button>
          </div>

          <div class="mt-6 space-y-3">
            <p :if={@visible == []} class="text-ink/55">No sites here yet.</p>
            <.site_row :for={site <- @visible} site={site} />
          </div>
          <div :if={@broken != []} class="mt-6 space-y-3">
            <div
              :for={site <- @broken}
              class="flex items-center gap-4 rounded-2xl border-2 border-dashed
       border-ink/30 p-4 opacity-60"
            >
              <div class="min-w-0 flex-1">
                <div class="truncate font-bold text-ink/60">{site.url}</div>
                <div class="mt-0.5 text-sm text-ink/45">Publication missing from your
                  repo</div>
              </div>

              <.button variant="ghost" size="sm" phx-value-id={site.id} phx-click="delete_site">
                <.icon name="hero-trash" class="size-4" /> Delete
              </.button>
            </div>
          </div>
        <% :discovered -> %>
          <.async_result :let={_pubs} assign={@publications}>
            <:loading>
              <div class="mt-6 flex items-center gap-2 text-ink/60">
                <.icon name="hero-arrow-path" class="size-5 animate-spin" /> Reading your
                repo…
              </div>
            </:loading>
            <:failed :let={_}>
              <p class="mt-6 text-sm font-bold text-red-600">Couldn't read your repo.</p>
            </:failed>

            <p :if={@discovered == []} class="mt-6 text-ink/55">
              No new publications found in your repo.
            </p>

            <div class="mt-6 space-y-3">
              <div
                :for={pub <- @discovered}
                class="flex items-center gap-4 rounded-2xl border-2 border-ink bg-paper
       p-4"
              >
                <div class="min-w-0 flex-1">
                  <div class="truncate font-bold">{pub.name || pub.url}</div>
                  <div class="mt-0.5 truncate text-sm text-ink/55">{pub.url}</div>
                  <div class="mt-1 truncate text-xs text-ink/40">{pub.rkey}</div>
                </div>

                <.link
                  navigate={~p"/sites/import/#{pub.rkey}"}
                  class="inline-flex flex-none items-center gap-1.5 rounded-xl border-2
       border-ink bg-ink px-4 py-1.5 text-xs font-bold text-paper transition-all
       hover:-translate-y-0.5"
                >
                  Import
                </.link>
              </div>
            </div>
          </.async_result>
      <% end %>
    </Layouts.dashboard>
    """
  end

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    sites = Publishing.list_sites(socket.assigns.current_scope)

    socket =
      socket
      |> assign(
        page_title: "Sites",
        sites: sites,
        filter: "all",
        visible: sites,
        broken: [],
        discovered: []
      )
      |> load_publications()

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(params, _uri, socket) do
    tab =
      if Map.get(params, "tab") == "discovered" do
        :discovered
      else
        :setup
      end

    {:noreply, assign(socket, tab: tab)}
  end

  @impl Phoenix.LiveView
  def handle_event("filter", %{"status" => status}, socket) do
    visible = filter_sites(socket.assigns.sites -- socket.assigns.broken, status)

    {:noreply,
     assign(socket,
       filter: status,
       visible: visible
     )}
  end

  def handle_event("delete_site", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope
    site = Publishing.get_site!(scope, id)
    {:ok, _} = Publishing.delete_site(scope, site)

    sites = Enum.reject(socket.assigns.sites, &(&1.id == site.id))
    broken = Enum.reject(socket.assigns.broken, &(&1.id == site.id))

    {:noreply,
     assign(socket,
       sites: sites,
       broken: broken,
       visible: filter_sites(sites -- broken, socket.assigns.filter)
     )}
  end

  @impl Phoenix.LiveView
  def handle_async(:load_publications, {:ok, {:ok, publications}}, socket) do
    rkeys = MapSet.new(publications, & &1.rkey)
    broken = Enum.filter(socket.assigns.sites, &broken?(&1, rkeys))

    {:noreply,
     assign(socket,
       publications: AsyncResult.ok(socket.assigns.publications, publications),
       broken: broken,
       discovered: discovered(publications, socket.assigns.sites),
       visible: filter_sites(socket.assigns.sites -- broken, socket.assigns.filter)
     )}
  end

  def handle_async(:load_publications, {:ok, {:error, reason}}, socket) do
    Logger.warning("SitesLive: failed to load publications", reason: inspect(reason))

    {:noreply,
     assign(socket,
       publications:
         AsyncResult.failed(
           socket.assigns.publications,
           reason
         )
     )}
  end

  defp filter_sites(sites, "all"), do: sites

  defp filter_sites(sites, status) do
    Enum.filter(sites, &(Site.status(&1) == status))
  end

  defp filter_label("all"), do: "All"

  defp filter_label(status) do
    String.capitalize(status)
  end

  defp load_publications(socket) do
    if connected?(socket) do
      user = socket.assigns.current_scope.user

      socket
      |> assign(publications: AsyncResult.loading())
      |> start_async(:load_publications, fn -> StandardSite.list_publications(user.id) end)
    else
      assign(socket, publications: AsyncResult.loading())
    end
  end

  defp broken?(site, publication_rkeys) do
    is_binary(site.rkey) and not is_nil(site.published_at) and
      not MapSet.member?(publication_rkeys, site.rkey)
  end

  defp discovered(publications, sites) do
    site_rkeys = MapSet.new(sites, & &1.rkey)
    Enum.reject(publications, &MapSet.member?(site_rkeys, &1.rkey))
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
end
