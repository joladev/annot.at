defmodule AnnotAtWeb.DashboardLive do
  use AnnotAtWeb, :live_view

  import AnnotAtWeb.SiteComponents, only: [site_row: 1]

  alias AnnotAt.Publishing

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <Layouts.dashboard flash={@flash} current_scope={@current_scope} active={:overview}>
      <div class="flex flex-col gap-4 sm:flex-row sm:items-center
    sm:justify-between">
        <div>
          <h1 class="font-display text-3xl font-bold tracking-tight
    sm:text-4xl">
            Hi {@current_scope.user.display_name || @current_scope.user.handle}
          </h1>
          <p class="mt-2 text-ink/60">Here's what you're publishing to the
            ATmosphere.</p>
        </div>
        <.link
          navigate={~p"/sites/new"}
          class="inline-flex items-center gap-1.5 self-start rounded-xl border-2
    border-ink bg-ink px-5 py-2.5 text-sm font-bold text-paper
    shadow-[4px_4px_0px_0px_var(--color-peach-bold)] transition-all
    hover:-translate-y-0.5 active:translate-y-0 sm:self-auto"
        >
          <.icon name="hero-plus" class="size-5" /> Add a site
        </.link>
      </div>
      <div class="mt-8 grid grid-cols-2 gap-4 lg:grid-cols-4">
        <.stat_card
          label="Sites"
          value={"#{length(@sites)}"}
          sub="in your account"
          tint="bg-sky-light"
          shadow="shadow-[5px_5px_0px_0px_var(--color-sky-bold)]"
        />
        <.stat_card
          label="Posts"
          value="0"
          sub="published"
          tint="bg-peach-light"
          shadow="shadow-[5px_5px_0px_0px_var(--color-peach-bold)]"
        />
        <.stat_card
          label="This week"
          value="0"
          sub="last 7 days"
          tint="bg-sky-light"
          shadow="shadow-[5px_5px_0px_0px_var(--color-sky-bold)]"
        />
        <.stat_card
          label="Bluesky"
          value="Off"
          sub="cross-posting"
          tint="bg-peach-light"
          shadow="shadow-[5px_5px_0px_0px_var(--color-peach-bold)]"
        />
      </div>

      <div class="mt-10 mb-4 flex items-center justify-between">
        <h2 class="text-lg font-bold">Your sites</h2>
        <.link
          :if={@sites != []}
          navigate={~p"/sites"}
          class="text-sm font-bold text-ink/55 hover:text-ink"
        >
          View all →
        </.link>
      </div>

      <div
        :if={@sites == []}
        class="-rotate-1 rounded-2xl border-2 border-ink bg-sky-light p-8
    text-center shadow-[8px_8px_0px_0px_var(--color-sky-bold)]"
      >
        <div class="mx-auto grid size-14 place-items-center rounded-full
    border-2 border-ink bg-peach-bold">
          <.icon name="hero-globe-alt" class="size-7" />
        </div>
        <p class="mt-4 font-bold">You haven't added any sites yet</p>
        <p class="mx-auto mt-1 max-w-sm text-sm text-ink/65">
          Connect a blog's RSS feed and we'll publish every new post to the
          ATmosphere.
        </p>
        <.link
          navigate={~p"/sites/new"}
          class="mt-5 inline-flex items-center gap-1.5 rounded-xl bg-ink px-5
    py-2.5 text-sm font-bold text-paper transition-all hover:scale-[1.02]
    active:scale-[0.98]"
        >
          <.icon name="hero-plus" class="size-4" /> Add your first site
        </.link>
      </div>

      <div :if={@sites != []} class="space-y-3">
        <.site_row :for={site <- Enum.take(@sites, 5)} site={site} />
      </div>
    </Layouts.dashboard>
    """
  end

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    sites = Publishing.list_sites(socket.assigns.current_scope)
    {:ok, assign(socket, page_title: "Dashboard", sites: sites)}
  end
end
