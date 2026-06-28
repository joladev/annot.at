defmodule AnnotAtWeb.LoginLive do
  use AnnotAtWeb, :live_view

  alias AnnotAt.Atproto.Directory
  alias AnnotAt.Atproto.OAuth.Login

  @min_query_length 2

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="flex min-h-screen flex-col items-center justify-center px-6 py-12">
        <.link href={~p"/"} class="mb-8 font-display text-2xl font-bold tracking-tight">
          annot.at
        </.link>

        <div class="w-full max-w-sm -rotate-1 rounded-3xl border-2 border-ink bg-paper p-8 shadow-[10px_10px_0px_0px_var(--color-sky-bold)] transition-transform focus-within:rotate-0">
          <h1 class="font-display text-3xl font-bold tracking-tight">
            Sign in
          </h1>

          <p class="mt-2 text-sm text-ink/60">
            Enter your atproto handle to Publish to the ATmosphere.
          </p>

          <.form for={@form} phx-change="suggest" phx-submit="login" class="mt-6 space-y-4">
            <div
              id="handle-combobox"
              class="relative"
              phx-hook=".HandleNav"
              phx-click-away={@open && "close"}
            >
              <label for="handle" class="mb-1.5 block text-sm font-bold">Handle</label>
              <div class="relative">
                <span class="pointer-events-none absolute left-3 top-1/2 size-8 -translate-y-1/2">
                  <span
                    :if={!@selected}
                    class="absolute inset-0 flex items-center justify-center rounded-full border-2 border-dashed border-ink/25 text-ink/30"
                  >
                    <.icon name="hero-user" class="size-4" />
                  </span>
                  <span
                    :if={@selected}
                    class="absolute inset-0 flex items-center justify-center rounded-full border-2 border-ink bg-sky-bold/30 text-sm font-bold"
                  >
                    {@selected.handle |> String.first() |> String.upcase()}
                  </span>
                  <img
                    :if={@selected && @selected.avatar}
                    src={@selected.avatar}
                    alt=""
                    class="absolute inset-0 size-8 rounded-full border-2 border-ink object-cover"
                  />
                </span>

                <input
                  type="text"
                  name="handle"
                  id="handle"
                  value={@form[:handle].value}
                  placeholder="alice.bsky.social"
                  phx-debounce="150"
                  role="combobox"
                  aria-autocomplete="list"
                  aria-controls="handle-listbox"
                  aria-expanded={to_string(@open)}
                  autocomplete="off"
                  required
                  autofocus
                  autocapitalize="none"
                  autocorrect="off"
                  spellcheck="false"
                  class="w-full rounded-xl border-2 border-ink bg-paper py-3 pl-14 pr-4 placeholder:text-ink/35 focus:outline-none focus:ring-4 focus:ring-sky-bold/40"
                />

                <ul
                  :if={@open}
                  id="handle-listbox"
                  role="listbox"
                  class="absolute left-0 right-0 top-full z-10 mt-2 max-h-72 overflow-auto rounded-xl border-2 border-ink bg-paper py-1 shadow-[4px_4px_0px_0px_var(--color-ink)]"
                >
                  <li
                    :for={{actor, index} <- Enum.with_index(@suggestions)}
                    id={"suggestion-#{index}"}
                    role="option"
                    aria-selected="false"
                    phx-click="select"
                    phx-value-handle={actor.handle}
                    class="flex cursor-pointer items-center gap-3 px-3 py-2 hover:bg-ink/5"
                  >
                    <img
                      :if={actor.avatar}
                      src={actor.avatar}
                      class="size-8 shrink-0 rounded-full border-2 border-ink object-cover"
                      alt=""
                    />
                    <div
                      :if={!actor.avatar}
                      class="flex size-8 shrink-0 items-center justify-center rounded-full border-2 border-ink bg-sky-bold/30 text-sm font-bold"
                    >
                      {actor.handle |> String.first() |> String.upcase()}
                    </div>
                    <div class="min-w-0">
                      <p class="truncate text-sm font-bold">{actor.handle}</p>
                      <p :if={actor.display_name} class="truncate text-xs text-ink/50">
                        {actor.display_name}
                      </p>
                    </div>
                  </li>

                  <li :if={@suggestions == []} class="px-3 py-2 text-sm text-ink/50">
                    No matches.
                  </li>
                </ul>
              </div>
            </div>

            <button
              type="submit"
              class="inline-flex w-full items-center justify-center gap-2 rounded-xl bg-ink px-5 py-3 font-bold text-paper transition-all hover:scale-[1.01] active:scale-[0.99] [.phx-submit-loading_&]:pointer-events-none [.phx-submit-loading_&]:opacity-70"
            >
              <span class="hidden items-center gap-2 [.phx-submit-loading_&]:inline-flex">
                <span class="size-5 animate-spin rounded-full border-2 border-current border-t-transparent" />
                Connecting…
              </span>
              <span class="[.phx-submit-loading_&]:hidden">Continue</span>
            </button>
          </.form>

          <p class="mt-5 text-center text-xs text-ink/50">
            Any atproto handle works, Bluesky, Eurosky, or your own domain.
          </p>
        </div>

        <.link href={~p"/"} class="mt-8 text-sm text-ink/55 transition hover:text-ink">
          ← Back to home
        </.link>
      </div>

      <script :type={Phoenix.LiveView.ColocatedHook} name=".HandleNav">
        export default {
          mounted() {
            this.active = -1;
            this.input = this.el.querySelector("input");
            this.onKey = this.onKey.bind(this);
            this.onPick = this.onPick.bind(this);
            this.onError = this.onError.bind(this);
            this.el.addEventListener("error", this.onError, true);
            this.input.addEventListener("keydown", this.onKey);
            this.el.addEventListener("click", this.onPick);
          },

          updated() {
            this.active = -1;
            this.paint();
          },

          destroyed() {
            this.input.removeEventListener("keydown", this.onKey);
            this.el.removeEventListener("click", this.onPick);
            this.el.removeEventListener("error", this.onError, true);
          },

          options() {
            return Array.from(this.el.querySelectorAll('[role="option"]'));
          },

          paint() {
            const options = this.options();
            options.forEach((option, index) => {
              const isActive = index === this.active;
              option.classList.toggle("bg-ink/10", isActive);
              option.setAttribute("aria-selected", isActive);
            });

            const current = options[this.active];

            if (current) {
              this.input.setAttribute("aria-activedescendant", current.id);
              current.scrollIntoView({block: "nearest"});
            } else {
              this.input.removeAttribute("aria-activedescendant");
            }
          },

          move(delta) {
            const count = this.options().length;
            if (count === 0) return;
            this.active = (this.active + delta + count) % count;
            this.paint();
          },

          onKey(e) {
            const options = this.options();
            if (e.key === "ArrowDown") {
              e.preventDefault();
              this.move(1);
            } else if (e.key === "ArrowUp") {
              e.preventDefault();
              this.move(-1);
            } else if (e.key === "Enter" && this.active >= 0 && options[this.active]) {
              e.preventDefault();
              options[this.active].click();
            } else if (e.key === "Escape" && options.length > 0) {
              e.preventDefault();
              this.pushEvent("close");
            }
          },

          onPick(e) {
            const option = e.target.closest('[role="option"]');
            if (option) this.input.value = option.getAttribute("phx-value-handle");
          },

          onError(e) {
            if (e.target.tagName === "IMG") e.target.remove();
          },
        }
      </script>
    </Layouts.app>
    """
  end

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       form: to_form(%{"handle" => ""}),
       suggestions: [],
       open: false,
       selected: nil
     )}
  end

  @impl Phoenix.LiveView
  def handle_event("suggest", %{"handle" => raw}, socket) do
    query =
      raw
      |> String.trim()
      |> String.trim_leading("@")

    {open, suggestions} =
      if String.length(query) >= @min_query_length do
        {true, Directory.search_handles(query)}
      else
        {false, []}
      end

    {:noreply,
     assign(socket,
       form: to_form(%{"handle" => raw}),
       suggestions: suggestions,
       open: open,
       selected: resolve_selected(suggestions, raw)
     )}
  end

  def handle_event("select", %{"handle" => handle}, socket) do
    {:noreply,
     assign(socket,
       form: to_form(%{"handle" => handle}),
       open: false,
       selected: resolve_selected(socket.assigns.suggestions, handle)
     )}
  end

  def handle_event("close", _params, socket) do
    {:noreply, assign(socket, open: false)}
  end

  def handle_event("login", %{"handle" => handle}, socket) do
    case Login.start_login(handle) do
      {:ok, url} ->
        {:noreply, redirect(socket, external: url)}

      {:error, reason} ->
        socket =
          socket
          |> put_flash(:error, error_message(reason))
          |> assign(form: to_form(%{"handle" => handle}), open: false)

        {:noreply, socket}
    end
  end

  defp resolve_selected(suggestions, raw) do
    handle =
      raw
      |> String.trim()
      |> String.trim_leading("@")
      |> String.downcase()

    Enum.find(suggestions, fn suggestion -> String.downcase(suggestion.handle) == handle end)
  end

  defp error_message(:invalid_handle), do: "That doesn't look like a valid handle."
  defp error_message(:login_failed), do: "Authorization was denied or failed."
end
