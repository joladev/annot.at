defmodule AnnotAtWeb.SiteComponents do
  @moduledoc """
  Shared components for rendering sites.
  """

  use AnnotAtWeb, :html

  alias AnnotAt.Publishing.Site

  attr :site, :map, required: true

  def site_row(assigns) do
    ~H"""
    <.link
      navigate={~p"/sites/#{@site.id}"}
      class="block rounded-2xl border-2 border-ink bg-paper p-5 transition-all
    hover:-translate-y-0.5 hover:shadow-[5px_5px_0px_0px_var(--color-ink)]"
    >
      <div class="flex items-center justify-between gap-3">
        <div class="min-w-0">
          <div class="truncate font-display text-lg font-bold
    tracking-tight">{@site.url}</div>
          <div class="mt-0.5 truncate text-sm
    text-ink/50">
            {@site.feed_url || "No feed selected"}
          </div>
        </div>
        <.status_badge status={Site.status(@site)} />
      </div>
    </.link>
    """
  end

  attr :status, :atom, required: true

  def status_badge(assigns) do
    ~H"""
    <span class={[
      "flex-none rounded-full border-2 border-ink px-3 py-0.5 text-xs
    font-bold",
      @status == :draft && "bg-peach-light",
      @status == :verified && "bg-sky-light",
      @status == :published && "bg-sky-bold"
    ]}>
      {@status |> Atom.to_string() |> String.capitalize()}
    </span>
    """
  end
end
