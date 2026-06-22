defmodule AnnotAtWeb.SiteNewLive do
  use AnnotAtWeb, :live_view

  import AnnotAtWeb.SiteComponents, only: [site_row: 1]

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

      <%= if @matches == [] do %>
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
                  class="w-full rounded-xl border-2 border-ink bg-paper px-5
    py-4 text-lg font-medium placeholder:text-ink/30 focus:outline-none focus:ring-2
    focus:ring-sky-bold"
                />
              </div>
              <button
                type="submit"
                disabled={!@valid?}
                class={[
                  "w-full rounded-xl border-2 border-ink bg-ink px-6 py-4
    text-lg font-bold text-paper transition-all whitespace-nowrap sm:mb-3
    sm:w-auto",
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
      <% else %>
        <div class="mt-6 rounded-3xl border-2 border-ink bg-sky-light p-8
    shadow-[10px_10px_0px_0px_var(--color-sky-bold)] sm:p-10">
          <h1 class="font-display text-3xl font-bold tracking-tight">You've
            added this before</h1>
          <p class="mt-1 text-ink/60">Continue an existing site for {@url}, or
            start a fresh one.</p>

          <div class="mt-6 space-y-3">
            <.site_row :for={site <- @matches} site={site} />

            <button
              phx-click="create_new"
              class="flex w-full cursor-pointer items-center gap-3 rounded-2xl
    border-2 border-dashed border-ink bg-paper p-5 text-left transition-all
    hover:-translate-y-0.5 active:translate-y-0"
            >
              <.icon name="hero-plus-circle" class="size-6 flex-none" />
              <div>
                <div class="font-bold">Start a new one</div>
                <div class="text-xs text-ink/55">Register {@url} again as a
                  separate site.</div>
              </div>
            </button>
          </div>

          <button phx-click="reset" class="mt-5 text-sm font-bold text-ink/50
    hover:text-ink">
            ← Use a different URL
          </button>
        </div>
      <% end %>
    </Layouts.dashboard>
    """
  end

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Add a site",
       form: to_form(%{"url" => ""}, as: :site),
       valid?: false,
       matches: [],
       url: nil
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
      canonical = URL.canonical(url)
      scope = socket.assigns.current_scope

      case Publishing.list_sites_for_url(scope, canonical) do
        [] ->
          case Publishing.create_site(scope, canonical) do
            {:ok, site} ->
              {:noreply, push_navigate(socket, to: ~p"/sites/#{site.id}")}

            {:error, changeset} ->
              {:noreply, assign(socket, form: to_form(changeset, as: :site))}
          end

        matches ->
          {:noreply, assign(socket, matches: matches, url: canonical)}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("create_new", _params, socket) do
    case Publishing.create_site(socket.assigns.current_scope, socket.assigns.url) do
      {:ok, site} ->
        {:noreply, push_navigate(socket, to: ~p"/sites/#{site.id}")}

      {:error, changeset} ->
        {:noreply,
         assign(socket,
           form:
             to_form(changeset,
               as: :site
             )
         )}
    end
  end

  def handle_event("reset", _params, socket) do
    {:noreply, assign(socket, matches: [], url: nil)}
  end
end
