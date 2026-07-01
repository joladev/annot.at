defmodule AnnotAt.Feeds.RSS do
  @moduledoc """
  Saxy SAX parser for RSS 2.0 feeds into `AnnotAt.Feeds.Feed`.

  Used Gluttony as a reference implementation.
  """

  @behaviour Saxy.Handler

  alias AnnotAt.Feeds.Entry
  alias AnnotAt.Feeds.Feed

  require Logger

  @doc """
  Returns `AnnotAt.Feeds.Feed` with entries. The list of entries can be empty.

  If the feed is invalid or not usable, it returns `{:error, :invalid_feed}`.
  """
  @spec parse(binary()) :: {:ok, Feed.t()} | {:error, :invalid_feed}
  def parse(body) when is_binary(body) do
    case Saxy.parse_string(body, __MODULE__, initial_state()) do
      {:ok, state} ->
        feed = %{state.feed | entries: Enum.reverse(state.entries)}

        if is_binary(feed.title) do
          {:ok, feed}
        else
          {:error, :invalid_feed}
        end

      {:error, %Saxy.ParseError{} = saxy_error} ->
        Logger.warning("Feeds.RSS saxy error",
          error: inspect(saxy_error)
        )

        {:error, :invalid_feed}
    end
  end

  defp initial_state do
    %{
      feed: %Feed{},
      entries: [],
      stack: [],
      current_text: []
    }
  end

  def handle_event(:start_document, _data, state), do: {:ok, state}

  def handle_event(:start_element, {"item", _attrs}, state) do
    {:ok,
     %{
       state
       | entries: [%Entry{categories: []} | state.entries],
         stack: ["item" | state.stack],
         current_text: []
     }}
  end

  def handle_event(:start_element, {name, _attrs}, state) do
    {:ok, %{state | stack: [name | state.stack], current_text: []}}
  end

  def handle_event(:characters, chars, state) do
    {:ok, %{state | current_text: [chars | state.current_text]}}
  end

  def handle_event(:end_element, "item", state) do
    ["item" | rest_stack] = state.stack
    [entry | rest] = state.entries
    entry = finalize_entry(entry)
    {:ok, %{state | entries: [entry | rest], stack: rest_stack, current_text: []}}
  end

  def handle_event(:end_element, name, state) do
    text = text(state.current_text)
    [^name | parent_stack] = state.stack
    parent = List.first(parent_stack)

    state = %{state | stack: parent_stack, current_text: []}

    state =
      cond do
        parent == "item" ->
          [current | entries] = state.entries
          %{state | entries: [apply_entry_field(current, name, text) | entries]}

        parent == "channel" ->
          %{state | feed: apply_feed_field(state.feed, name, text)}

        true ->
          state
      end

    {:ok, state}
  end

  def handle_event(:end_document, _data, state), do: {:ok, state}

  defp apply_entry_field(entry, "title", text), do: %{entry | title: text}
  defp apply_entry_field(entry, "link", text), do: %{entry | url: text}
  defp apply_entry_field(entry, "guid", text), do: %{entry | id: text}
  defp apply_entry_field(entry, "description", text), do: %{entry | summary: text}
  defp apply_entry_field(entry, "content:encoded", text), do: %{entry | content: text}
  defp apply_entry_field(entry, "pubDate", text), do: %{entry | published_at: parse_date(text)}

  defp apply_entry_field(entry, "category", text),
    do: %{entry | categories: [text | entry.categories]}

  defp apply_entry_field(entry, _name, _text), do: entry

  defp apply_feed_field(feed, "title", text), do: %{feed | title: text}
  defp apply_feed_field(feed, "description", text), do: %{feed | description: text}
  defp apply_feed_field(feed, "link", text), do: %{feed | url: text}
  defp apply_feed_field(feed, _name, _text), do: feed

  defp finalize_entry(%Entry{} = entry) do
    id =
      if is_nil(entry.id) and is_binary(entry.url) do
        entry.url
      else
        entry.id
      end

    %{entry | id: id, categories: Enum.reverse(entry.categories)}
  end

  defp text(parts) do
    result =
      parts
      |> Enum.reverse()
      |> IO.iodata_to_binary()
      |> String.trim()

    case result do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp parse_date(nil), do: nil

  defp parse_date(text) do
    case DateTimeParser.parse_datetime(text) do
      {:ok, datetime} ->
        datetime

      {:error, reason} ->
        Logger.debug("Feeds.RSS: unparseable pubDate - #{text}", reason: inspect(reason))
        nil
    end
  end
end
