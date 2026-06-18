defmodule AnnotAtWeb.DashboardLive do
  use AnnotAtWeb, :live_view

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Dashboard", sites: [])}
  end

  @impl Phoenix.LiveView
  def handle_event("add_site", _params, socket) do
    {:noreply, put_flash(socket, :info, "Adding sites is coming next.")}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <Layouts.dashboard flash={@flash} current_scope={@current_scope} active={:overview}>
      <div class="flex justify-end">
        <button
          phx-click="add_site"
          class="inline-flex items-center gap-1.5 rounded-xl bg-ink px-4 py-2.5 text-sm font-bold text-paper transition-all hover:scale-[1.02] active:scale-[0.98]"
        >
          <.icon name="hero-plus" class="size-4" /> Add a site
        </button>
      </div>

      <h1 class="mt-2 font-display text-3xl font-bold tracking-tight sm:text-4xl">
        Hi {@current_scope.user.display_name || @current_scope.user.handle}
      </h1>
      <p class="mt-2 text-ink/60">Here's what you're publishing to the ATmosphere.</p>

      <div class="mt-8 grid grid-cols-2 gap-4 lg:grid-cols-4">
        <.stat_card
          label="Sites"
          value="0"
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

      <h2 class="mt-10 mb-4 text-lg font-bold">Your sites</h2>

      <div
        :if={@sites == []}
        class="max-w-xl -rotate-1 rounded-2xl border-2 border-ink bg-sky-light p-8 text-center shadow-[8px_8px_0px_0px_var(--color-sky-bold)]"
      >
        <div class="mx-auto grid size-14 place-items-center rounded-full border-2 border-ink bg-peach-bold">
          <.icon name="hero-globe-alt" class="size-7" />
        </div>
        <p class="mt-4 font-bold">You haven't added any sites yet</p>
        <p class="mx-auto mt-1 max-w-sm text-sm text-ink/65">
          Connect a blog's RSS feed and we'll publish every new post to the ATmosphere.
        </p>
        <button
          phx-click="add_site"
          class="mt-5 inline-flex items-center gap-1.5 rounded-xl bg-ink px-5 py-2.5 text-sm font-bold text-paper transition-all hover:scale-[1.02] active:scale-[0.98]"
        >
          <.icon name="hero-plus" class="size-4" /> Add your first site
        </button>
      </div>
    </Layouts.dashboard>
    """
  end

  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :sub, :string, required: true
  attr :tint, :string, required: true
  attr :shadow, :string, required: true

  defp stat_card(assigns) do
    ~H"""
    <div class={["rounded-2xl border-2 border-ink p-5", @tint, @shadow]}>
      <div class="text-xs font-bold text-ink/70">{@label}</div>
      <div class="mt-2 font-display text-3xl font-bold">{@value}</div>
      <div class="mt-1 text-xs text-ink/55">{@sub}</div>
    </div>
    """
  end
end
