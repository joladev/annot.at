defmodule AnnotAtWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use AnnotAtWeb, :html

  alias Phoenix.LiveView.JS

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div class="min-h-screen bg-paper text-ink antialiased">
      {render_slot(@inner_block)}
    </div>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  The authenticated dashboard shell: sidebar nav + main content slot.
  """
  attr :flash, :map, required: true
  attr :current_scope, :map, required: true
  attr :active, :atom, default: :overview, doc: "the active nav item"
  slot :inner_block, required: true

  def dashboard(assigns) do
    ~H"""
    <div class="min-h-screen bg-paper text-ink lg:flex">
      <div class="flex items-center justify-between border-b-2 border-ink p-4
    lg:hidden">
        <.link navigate={~p"/dashboard"} class="font-display text-xl font-bold
    tracking-tight">
          annot.at
        </.link>
        <button
          phx-click={toggle_sidebar()}
          class="grid size-10 place-items-center rounded-xl border-2 border-ink
    bg-paper transition-all active:scale-95"
          aria-label="Open menu"
        >
          <.icon name="hero-bars-3" class="size-6" />
        </button>
      </div>

      <div
        id="sidebar-backdrop"
        phx-click={toggle_sidebar()}
        class="fixed inset-0 z-40 hidden bg-ink/40 lg:hidden"
      />

      <aside
        id="sidebar"
        class="fixed inset-y-0 left-0 z-50 flex w-60 -translate-x-full flex-col
    border-r-2 border-ink bg-paper p-4 transition-transform duration-200 lg:static
    lg:z-auto lg:translate-x-0"
      >
        <div class="flex items-center justify-between">
          <.link
            navigate={~p"/dashboard"}
            class="px-3 py-2 font-display text-xl font-bold tracking-tight"
          >
            annot.at
          </.link>
          <button
            phx-click={toggle_sidebar()}
            class="grid size-9 place-items-center rounded-lg border-2 border-ink
    lg:hidden"
            aria-label="Close menu"
          >
            <.icon name="hero-x-mark" class="size-5" />
          </button>
        </div>

        <nav class="mt-4 flex flex-col gap-1">
          <.dash_nav_item
            navigate={~p"/dashboard"}
            icon="hero-squares-2x2"
            active={@active == :overview}
          >
            Overview
          </.dash_nav_item>

          <div class="px-3 pt-5 pb-1.5 text-[11px] font-bold uppercase
    tracking-widest text-ink/40">
            Publish
          </div>
          <.dash_nav_item icon="hero-globe-alt" navigate={~p"/sites"} active={@active == :sites}>
            Sites
          </.dash_nav_item>
          <.dash_nav_item icon="hero-document-text">Posts</.dash_nav_item>

          <div class="px-3 pt-5 pb-1.5 text-[11px] font-bold uppercase
    tracking-widest text-ink/40">
            Account
          </div>
          <.dash_nav_item icon="hero-cog-6-tooth">Settings</.dash_nav_item>
        </nav>

        <div class="mt-auto border-t-2 border-ink/10 pt-3">
          <div class="flex items-center gap-3 px-3 py-2">
            <img
              :if={@current_scope.user.avatar_url}
              src={@current_scope.user.avatar_url}
              alt=""
              class="size-9 flex-none rounded-full border-2 border-ink"
            />
            <div
              :if={!@current_scope.user.avatar_url}
              class="size-9 flex-none rounded-full border-2 border-ink
    bg-gradient-to-br from-sky-bold to-peach-bold"
            />
            <div class="min-w-0">
              <div class="truncate text-sm font-bold leading-tight">
                {@current_scope.user.display_name || @current_scope.user.handle}
              </div>
              <div class="truncate text-xs text-ink/55">
                {"@" <>
                  @current_scope.user.handle}
              </div>
            </div>
          </div>
          <.link
            href={~p"/logout"}
            method="delete"
            class="block px-3 py-1.5 text-[11px] font-bold uppercase
    tracking-widest text-ink/45 hover:text-ink"
          >
            Sign out
          </.link>
        </div>
      </aside>

      <main class="flex-1 px-6 py-8 sm:px-10">
        {render_slot(@inner_block)}
      </main>
    </div>
    """
  end

  defp toggle_sidebar(js \\ %JS{}) do
    js
    |> JS.toggle_class("-translate-x-full", to: "#sidebar")
    |> JS.toggle(to: "#sidebar-backdrop")
  end

  attr :icon, :string, required: true
  attr :active, :boolean, default: false
  attr :navigate, :string, default: nil
  slot :inner_block, required: true

  defp dash_nav_item(%{navigate: nil} = assigns) do
    ~H"""
    <span class="flex cursor-default items-center gap-3 rounded-xl border-2 border-transparent px-3 py-2 text-sm font-semibold text-ink/35">
      <.icon name={@icon} class="size-5" />
      {render_slot(@inner_block)}
    </span>
    """
  end

  defp dash_nav_item(assigns) do
    ~H"""
    <.link
      navigate={@navigate}
      class={[
        "flex items-center gap-3 rounded-xl border-2 px-3 py-2 text-sm font-semibold transition",
        if(@active,
          do: "border-ink bg-peach-bold text-ink",
          else: "border-transparent text-ink/65 hover:bg-ink/5"
        )
      ]}
    >
      <.icon name={@icon} class="size-5" />
      {render_slot(@inner_block)}
    </.link>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end
end
