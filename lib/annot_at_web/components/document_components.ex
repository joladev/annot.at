defmodule AnnotAtWeb.DocumentComponents do
  @moduledoc """
  Renders a `site.standard.document` record, reading mode.
  """

  use Phoenix.Component
  import Phoenix.HTML, only: [raw: 1]

  attr :doc, :map, required: true
  attr :author, :map, required: true
  attr :cover_url, :string, default: nil

  def document(assigns) do
    ~H"""
    <article class="mx-auto max-w-2xl">
      <img
        :if={@cover_url}
        src={@cover_url}
        alt={@doc["title"]}
        class="aspect-[1.91/1] w-full rounded-2xl border-2 border-ink object-cover"
      />

      <h1 class="mt-6 font-display text-4xl font-bold tracking-tight">{@doc["title"]}</h1>
      <div class="mt-3 flex items-center gap-2.5 text-sm text-ink/55">
        <img
          :if={@author.avatar_url}
          src={@author.avatar_url}
          alt={@author.display_name || @author.handle}
          class="size-6 rounded-full border-2 border-ink"
        />
        <span class="font-bold text-ink/75">{@author.display_name || @author.handle}</span>
        <span aria-hidden="true">-</span>
        <time :if={@doc["publishedAt"]}>{format_date(@doc["publishedAt"])}</time>
      </div>

      <div :if={@doc["tags"] not in [nil, []]} class="mt-4 flex flex-wrap gap-2">
        <span
          :for={tag <- @doc["tags"]}
          class="rounded-full border-2 border-ink px-2.5 py-0.5 text-xs font-bold"
        >
          {tag}
        </span>
      </div>

      <div class="doc-prose mt-8">
        <%= case @doc["content"] do %>
          <% %{"$type" => "org.wordpress.html", "html" => html} -> %>
            {raw(sanitize(html))}
          <% _ -> %>
            <p>{preview(@doc["textContent"])}</p>
        <% end %>
      </div>
    </article>
    """
  end

  defp sanitize(html) do
    html
    |> HtmlSanitizeEx.markdown_html()
    |> String.replace(~r{</?span>}, "")
  end

  defp preview(nil), do: nil
  defp preview(text) when byte_size(text) <= 280, do: text
  defp preview(text), do: String.slice(text, 0, 280) <> "..."

  defp format_date(iso) do
    case DateTime.from_iso8601(iso) do
      {:ok, dt, _} -> Calendar.strftime(dt, "%B %-d, %Y")
      _ -> iso
    end
  end
end
