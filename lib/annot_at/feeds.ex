defmodule AnnotAt.Feeds do
  @moduledoc """
  Feed handling entry point. Discovers feed URLs from a page HTML,
  detects format and parses.
  """

  alias AnnotAt.Feeds.Feed
  alias AnnotAt.Feeds.RSS
  alias AnnotAt.Feeds.Source

  @feed_formats %{
    "application/rss+xml" => :rss,
    "application/atom+xml" => :atom,
    "application/feed+json" => :json
  }

  @feed_selector Enum.map_join(Map.keys(@feed_formats), ", ", fn type ->
                   ~s(link[rel="alternate"][type="#{type}"])
                 end)

  @doc """
  Parses a feed body into a `Feed`, detecting the format from body and
  content type.
  """
  @spec parse(binary(), String.t() | nil) ::
          {:ok, Feed.t()} | {:error, :invalid_feed | :unsupported_feed | :unrecognized_feed}
  def parse(body, content_type \\ nil) when is_binary(body) do
    case detect(body, content_type) do
      :rss -> RSS.parse(body)
      :atom -> {:error, :unsupported_feed}
      :json -> {:error, :unsupported_feed}
      :unknown -> {:error, :unrecognized_feed}
    end
  end

  @doc """
  Finds every feed URL on a page.

  Looks for link alternate pointing to feeds and returns all matches.
  """
  @spec discover(binary(), String.t()) :: [Source.t()]
  def discover(html, base_url) when is_binary(html) and is_binary(base_url) do
    html
    |> LazyHTML.from_document()
    |> LazyHTML.query(@feed_selector)
    |> LazyHTML.attributes()
    |> Enum.map(&source_from_attributes(&1, base_url))
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq_by(& &1.url)
  end

  @doc """
  Extracts a page's title and description from its HTML.
  """
  @spec metadata(binary()) :: %{title: String.t() | nil, description: String.t() | nil}
  def metadata(html) when is_binary(html) do
    doc = LazyHTML.from_document(html)

    %{
      title:
        text_of(doc, "title") ||
          meta_content(
            doc,
            ~s(meta[property="og:title"])
          ),
      description:
        meta_content(doc, ~s(meta[name="description"])) ||
          meta_content(doc, ~s(meta[property="og:description"]))
    }
  end

  defp source_from_attributes(attributes, base_url) do
    attributes = Map.new(attributes)

    case attributes do
      %{"href" => href, "type" => type} ->
        url =
          base_url
          |> URI.merge(href)
          |> URI.to_string()

        %Source{
          url: url,
          title: attributes["title"],
          format: Map.fetch!(@feed_formats, type)
        }

      _ ->
        nil
    end
  end

  defp detect(body, content_type) do
    head =
      body
      |> String.slice(0..1023)
      |> String.trim_leading()

    cond do
      String.starts_with?(head, "{") -> :json
      is_binary(content_type) and String.contains?(content_type, "json") -> :json
      String.contains?(head, "<rss") -> :rss
      String.contains?(head, "<feed") -> :atom
      true -> :unknown
    end
  end

  defp text_of(doc, selector) do
    doc
    |> LazyHTML.query(selector)
    |> LazyHTML.text()
    |> presence()
  end

  defp meta_content(doc, selector) do
    doc
    |> LazyHTML.query(selector)
    |> LazyHTML.attribute("content")
    |> List.first()
    |> presence()
  end

  defp presence(nil), do: nil

  defp presence(str) do
    case String.trim(str) do
      "" -> nil
      trimmed -> trimmed
    end
  end
end
