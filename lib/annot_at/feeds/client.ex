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
  @cover_max_bytes 1_000_000

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

  def resolve_documents(%Feed{entries: entries} = feed, did) do
    entries =
      entries
      |> Task.async_stream(&resolve_entry(&1, did), timeout: :infinity, max_concurrency: 4)
      |> Enum.map(fn {:ok, entry} -> entry end)

    %{feed | entries: entries}
  end

  @spec fetch_image(String.t()) ::
          {:ok, {binary(), String.t()}}
          | {:error,
             :not_an_image | :too_large | {:http_status, pos_integer()} | {:transport, term()}}
  def fetch_image(url) do
    case Req.get(url, decode_body: false, receive_timeout: @receive_timeout) do
      {:ok, %Req.Response{status: status, body: body, headers: headers}}
      when status in 200..299 ->
        type = content_type(headers)

        cond do
          is_nil(type) or not image_type?(type) -> {:error, :not_an_image}
          byte_size(body) > @cover_max_bytes -> {:error, :too_large}
          true -> {:ok, {body, type}}
        end

      {:ok, %Req.Response{status: status}} ->
        {:error, {:http_status, status}}

      {:error, reason} ->
        {:error, {:transport, reason}}
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

  defp resolve_entry(%Entry{url: url} = entry, did) when is_binary(url) do
    case get(url) do
      {:ok, html} ->
        entry
        |> put_cover(html, url)
        |> put_rkey(html, did)

      {:error, _} ->
        entry
    end
  end

  defp resolve_entry(entry, _did), do: entry

  defp put_cover(entry, html, url) do
    image = Feeds.image(html, url)
    %{entry | image: image, cover_status: cover_status(image)}
  end

  defp put_rkey(entry, html, did) do
    case resolve_rkey(html, did) do
      {:ok, rkey} -> %{entry | rkey: rkey}
      {:error, _} -> entry
    end
  end

  defp resolve_rkey(html, did) do
    with {:ok, uri} <- document_uri(html) do
      extract_rkey(uri, did)
    end
  end

  defp cover_status(nil), do: :none

  defp cover_status(url) do
    case Req.request(url: url, method: :head, receive_timeout: @receive_timeout) do
      {:ok, %Req.Response{status: status, headers: headers}} when status in 200..299 ->
        classify(content_type(headers), content_length(headers))

      _ ->
        :unknown
    end
  end

  defp classify(nil, _length), do: :unknown

  defp classify(type, length) do
    cond do
      not image_type?(type) -> :not_image
      is_nil(length) -> :unknown
      length > @cover_max_bytes -> :too_large
      true -> :ok
    end
  end

  defp content_type(headers) do
    case headers["content-type"] do
      [value | _] ->
        value
        |> String.split(";")
        |> List.first()
        |> String.trim()

      _ ->
        nil
    end
  end

  defp content_length(headers) do
    case headers["content-length"] do
      [value | _] ->
        case Integer.parse(value) do
          {bytes, _} -> bytes
          :error -> nil
        end

      _ ->
        nil
    end
  end

  defp image_type?(type), do: String.starts_with?(type, "image/")
end
