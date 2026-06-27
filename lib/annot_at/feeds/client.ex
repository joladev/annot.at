defmodule AnnotAt.Feeds.Client do
  @moduledoc """
  Network stuff for feeds, like fetching pages or feeds and handing
  them to the dicovery/parsing.
  """

  alias AnnotAt.Atproto.StandardSite.Document
  alias AnnotAt.Feeds
  alias AnnotAt.Feeds.Entry
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

  @doc """
  Fetches a page to extract the <link rel="site.standard.document"> href if it exists.
  """
  @spec document_rkey(String.t(), String.t()) ::
          {:ok, String.t()}
          | {:error,
             :invalid
             | :not_declared
             | :did_mismatch
             | {:http_status, pos_integer()}
             | {:transport, term()}}
  def document_rkey(url, expected_did) do
    with {:ok, html} <- get(url),
         {:ok, uri} <- document_uri(html) do
      extract_rkey(uri, expected_did)
    end
  end

  def resolve_documents(%Feed{entries: entries} = feed, did) do
    entries =
      entries
      |> Task.async_stream(&put_rkey(&1, did), timeout: :infinity, max_concurrency: 4)
      |> Enum.map(fn {:ok, entry} -> entry end)

    %{feed | entries: entries}
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

  defp document_uri(html) do
    if uri = Feeds.document_uri(html) do
      {:ok, uri}
    else
      {:error, :not_declared}
    end
  end

  defp extract_rkey(uri, expected_did) do
    case Document.split_aturi(uri) do
      {:ok, %{rkey: rkey, did: ^expected_did}} ->
        {:ok, rkey}

      {:ok, _} ->
        {:error, :did_mismatch}

      {:error, _error} = error ->
        error
    end
  end

  defp put_rkey(%Entry{url: url} = entry, did) do
    case document_rkey(url, did) do
      {:ok, rkey} ->
        %{entry | rkey: rkey}

      {:error, _} ->
        entry
    end
  end
end
