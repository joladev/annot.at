defmodule AnnotAtWeb.SiteNewLive do
  use AnnotAtWeb, :live_view

  alias AnnotAt.Publishing
  alias AnnotAt.URL

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <Layouts.dashboard flash={@flash} current_scope={@current_scope} active={:overview}>
      <.link navigate={~p"/dashboard"} class="text-sm font-bold text-ink/50
    hover:text-ink">
        ← Back
      </.link>

      <div class="mt-6 rounded-3xl border-2 border-ink bg-sky-light p-8
    shadow-[10px_10px_0px_0px_var(--color-sky-bold)] sm:p-12">
        <div class="flex items-center gap-4">
          <div class="grid size-16 flex-none -rotate-3 place-items-center
    rounded-2xl border-2 border-ink bg-peach-bold
    shadow-[4px_4px_0px_0px_var(--color-ink)]">
            <.icon name="hero-rss" class="size-8" />
          </div>
          <div>
            <h1 class="font-display text-4xl font-bold tracking-tight">Add a
              site</h1>
            <p class="mt-1 text-ink/60">Paste your blog's URL, we'll sniff out
              its feed.</p>
          </div>
        </div>

        <.form for={@form} id="site-form" phx-change="validate" phx-submit="submit" class="mt-8">
          <div class="flex flex-col gap-3 sm:flex-row sm:items-end">
            <div class="flex-1">
              <.input
                field={@form[:url]}
                type="url"
                label="Website URL"
                placeholder="https://yourblog.com"
                class="w-full rounded-xl border-2 border-ink bg-paper px-5 py-4
    text-lg font-medium placeholder:text-ink/30 focus:outline-none focus:ring-2
    focus:ring-sky-bold"
              />
            </div>
            <button
              type="submit"
              disabled={!@valid?}
              class={[
                "w-full rounded-xl border-2 border-ink bg-ink px-6 py-4 text-lg
    font-bold text-paper transition-all whitespace-nowrap sm:mb-3 sm:w-auto",
                @valid? &&
                  "cursor-pointer
    shadow-[4px_4px_0px_0px_var(--color-peach-bold)] hover:-translate-y-0.5
    hover:shadow-[6px_6px_0px_0px_var(--color-peach-bold)] active:translate-y-0
    active:shadow-[2px_2px_0px_0px_var(--color-peach-bold)]",
                !@valid? && "cursor-not-allowed opacity-40"
              ]}
            >
              Check feed
            </button>
          </div>
        </.form>
      </div>
    </Layouts.dashboard>
    """
  end

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Add a site",
       form: to_form(%{"url" => ""}, as: :site),
       valid?: false
     )}
  end

  @impl Phoenix.LiveView
  def handle_event("validate", %{"site" => %{"url" => url} = params}, socket) do
    {:noreply,
     assign(socket,
       form: to_form(params, as: :site),
       valid?: URL.valid?(url)
     )}
  end

  def handle_event("submit", %{"site" => %{"url" => url}}, socket) do
    if URL.valid?(url) do
      case Publishing.create_site(socket.assigns.current_scope, URL.canonical(url)) do
        {:ok, site} ->
          {:noreply, push_navigate(socket, to: ~p"/sites/#{site.id}")}

        {:error, changeset} ->
          {:noreply, assign(socket, form: to_form(changeset, as: :site))}
      end
    else
      {:noreply, socket}
    end
  end
end
