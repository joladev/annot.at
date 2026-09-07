defmodule AnnotAt.Atproto.StandardSite.Document do
  @moduledoc "A `site.standard.document` record (a published post)."

  alias AnnotAt.URL

  @enforce_keys [:rkey, :site, :title, :published_at]
  defstruct [
    :rkey,
    :site,
    :title,
    :path,
    :published_at,
    :updated_at,
    :description,
    :text_content,
    :content,
    :tags,
    :cover_image
  ]

  @type t :: %__MODULE__{
          rkey: String.t(),
          site: String.t(),
          title: String.t(),
          path: String.t() | nil,
          published_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil,
          description: String.t() | nil,
          text_content: String.t() | nil,
          content: {:html, String.t()} | {:unknown, map()} | nil,
          tags: [String.t()] | nil,
          cover_image: map() | nil
        }

  def from_record(uri, value) when is_binary(uri) and is_map(value) do
    {:ok, %Latch.AtURI{rkey: rkey, collection: "site.standard.document"}} = Latch.AtURI.parse(uri)

    %__MODULE__{
      rkey: rkey,
      site: value["site"],
      title: value["title"],
      path: value["path"],
      published_at: parse_datetime(value["publishedAt"]),
      updated_at: parse_datetime(value["updatedAt"]),
      description: value["description"],
      text_content: value["textContent"],
      content: parse_content(value["content"]),
      tags: value["tags"],
      cover_image: value["coverImage"]
    }
  end

  def split_aturi(aturi) do
    case String.split(aturi, "/") do
      ["at:", "", did, "site.standard.document", rkey] ->
        {:ok, %{did: did, rkey: rkey}}

      _ ->
        {:error, :invalid}
    end
  end

  def path_of(nil, _site), do: nil

  def path_of(url, site_url) do
    canonical_url = URL.canonical(url)
    canonical_site_url = URL.canonical(site_url)

    path = URI.parse(canonical_url).path
    base = URI.parse(canonical_site_url).path || ""

    String.replace_prefix(path, base, "")
  end

  defp parse_datetime(nil), do: nil

  defp parse_datetime(iso) when is_binary(iso) do
    {:ok, dt, _} = DateTime.from_iso8601(iso)
    dt
  end

  defp parse_content(%{"$type" => "org.wordpress.html", "html" => html}), do: {:html, html}
  defp parse_content(%{"$type" => _} = other), do: {:unknown, other}
  defp parse_content(_), do: nil
end
