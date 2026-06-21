defmodule AnnotAt.URL do
  @moduledoc """
  URL helpers.
  """

  @doc """
  Clean up URLs so we got consistent site "identifiers".
  """
  def canonical(url) do
    uri =
      url
      |> with_scheme()
      |> URI.parse()

    URI.to_string(%{
      uri
      | host: downcase(uri.host),
        path: trim_slash(uri.path)
    })
  end

  def valid?(url) do
    uri =
      url
      |> String.trim()
      |> canonical()
      |> URI.parse()

    case uri do
      %URI{host: host} when is_binary(host) ->
        String.contains?(host, ".")

      _ ->
        false
    end
  end

  defp with_scheme(url) do
    if url =~ ~r{^https?://}i do
      url
    else
      "https://" <> url
    end
  end

  defp downcase(nil), do: nil
  defp downcase(host), do: String.downcase(host)

  defp trim_slash(nil), do: nil
  defp trim_slash("/"), do: nil
  defp trim_slash(path), do: String.trim_trailing(path, "/")
end
