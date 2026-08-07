defmodule AnnotAt.Feeds.JSON do
  @moduledoc """
  Feed "parser" module for JSON feeds, compliant with https://www.jsonfeed.org/version/1.1/

  Doesn't enforce required fields.
  """

  alias AnnotAt.Feeds.Entry
  alias AnnotAt.Feeds.Feed

  def parse(data) do
    case Jason.decode(data) do
      {:ok, json} ->
        to_feed(json)

      {:error, _reason} ->
        {:error, :invalid_feed}
    end
  end

  defp to_feed(%{"items" => items} = json) do
    entries = Enum.map(items, &to_entry/1)

    {:ok,
     %Feed{
       title: json["title"],
       description: json["description"],
       url: json["home_page_url"],
       entries: entries
     }}
  end

  defp to_feed(_json) do
    {:error, :invalid_feed}
  end

  defp to_entry(raw_entry) do
    %Entry{
      id: raw_entry["id"],
      url: raw_entry["url"],
      title: raw_entry["title"],
      published_at: to_datetime(raw_entry["date_published"]),
      updated_at: to_datetime(raw_entry["date_modified"]),
      summary: raw_entry["summary"],
      content: raw_entry["content_html"] || raw_entry["content_text"],
      categories: raw_entry["tags"] || [],
      image: raw_entry["image"]
    }
  end

  defp to_datetime(raw) when is_binary(raw) do
    case DateTime.from_iso8601(raw) do
      {:ok, datetime, _calendar_offset} ->
        datetime

      _ ->
        nil
    end
  end

  defp to_datetime(_), do: nil
end
