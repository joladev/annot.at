defmodule AnnotAtWeb.SitesLive do
  use AnnotAtWeb, :live_view

  import AnnotAtWeb.SiteComponents, only: [site_row: 1]

  alias AnnotAt.Publishing
  alias AnnotAt.Publishing.Site

  @impl Phoenix.LiveView
  def render(assigns) do
    assigns = assign(assigns, :visible, filter_sites(assigns.sites, assigns.filter))

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
    </Layouts.dashboard>
    """
  end

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    sites = Publishing.list_sites(socket.assigns.current_scope)
    {:ok, assign(socket, page_title: "Sites", sites: sites, filter: "all")}
  end

  @impl Phoenix.LiveView
  def handle_event("filter", %{"status" => status}, socket) do
    {:noreply, assign(socket, filter: String.to_existing_atom(status))}
  end

  defp filter_sites(sites, "all"), do: sites

  defp filter_sites(sites, status) do
    Enum.filter(sites, &(Site.status(&1) == status))
  end

  defp filter_label("all"), do: "All"

  defp filter_label(status) do
    String.capitalize(status)
  end
end
