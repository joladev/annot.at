defmodule AnnotAt.Feeds.Client do
  @moduledoc """
  Network stuff for feeds, like fetching pages or feeds and handing
  them to the dicovery/parsing.
  """

  alias AnnotAt.Feeds
  alias AnnotAt.Feeds.Feed
  alias AnnotAt.Feeds.Source

  @receive_timeout 10_000

  @doc """
  Fetches a page and returns the feeds discovered.
  """
  @spec discover(String.t()) ::
          {:ok, [Source.t()]} | {:error, {:http_status, pos_integer()} | {:transport, term()}}
  def discover(url) do
    with {:ok, html} <- get(url) do
      {:ok, Feeds.discover(html, url)}
    end
  end

  @doc """
  Fetches and parses a single feed.
  """
  @spec load(String.t()) ::
          {:ok, Feed.t()}
          | {:error,
             :invalid_feed
             | :unsupported_feed
             | :unrecognized_feed
             | {:http_status, pos_integer()}
             | {:transport, term()}}
  def load(feed_url) do
    with {:ok, body} <- get(feed_url) do
      Feeds.parse(body)
    end
  end

  @doc """
  Fetches a page and extracts its title/description.
  """
  @spec metadata(String.t()) ::
          {:ok, map()} | {:error, {:http_status, pos_integer()} | {:transport, term()}}
  def metadata(url) do
    with {:ok, html} <- get(url) do
      {:ok, Feeds.metadata(html)}
    end
  end

  defp get(url) do
    case Req.get(url, decode_body: false, receive_timeout: @receive_timeout) do
      {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
        {:ok, body}

      {:ok, %Req.Response{status: status}} ->
        {:error, {:http_status, status}}

      {:error, reason} ->
        {:error, {:transport, reason}}
    end
  end
end
