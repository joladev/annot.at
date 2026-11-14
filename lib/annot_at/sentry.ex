defmodule AnnotAt.Sentry do
  @moduledoc """
  Sentry callbacks that keep identifying request data and metrics out of events.
  """

  @identifying_header_terms ["forwarded", "-ip", "remote-", "via", "-user"]

  def drop_metric(_metric), do: nil

  def scrub_headers(conn) do
    conn
    |> Sentry.PlugContext.default_header_scrubber()
    |> Map.reject(fn {name, _value} -> String.contains?(name, @identifying_header_terms) end)
  end
end
