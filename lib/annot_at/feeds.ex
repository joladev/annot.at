defmodule AnnotAt.Feeds do
  @moduledoc """
  Feed handling entry point. Discovers feed URLs from a page HTML,
  detects format and parses.
  """

  alias AnnotAt.Feeds.Feed
  alias AnnotAt.Feeds.RSS

  @feed_types ~w(application/rss+xml application/atom+xml appliation/feed+json)

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
  Finds a feed URL on a page.

  Looks for link alternate pointing to a feed and returns the first match.
  """
  @spec discover(binary(), String.t()) :: {:ok, String.t()} | :error
  def discover(html, base_url) when is_binary(html) and is_binary(base_url) do
    selector =
      Enum.map_join(@feed_types, ", ", fn type ->
        ~s(link[rel="alternate"][type="#{type}"])
      end)

    href =
      html
      |> LazyHTML.from_document()
      |> LazyHTML.query(selector)
      |> LazyHTML.attribute("href")
      |> List.first()

    if href do
      url =
        base_url
        |> URI.merge(href)
        |> URI.to_string()

      {:ok, url}
    else
      :error
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
end
