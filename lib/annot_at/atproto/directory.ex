defmodule AnnotAt.Atproto.Directory do
  @moduledoc """
  Public atproto handle search, used for login page typeahead.
  """

  alias AnnotAt.Atproto.HTTP

  @endpoint "https://typeahead.cove.town/xrpc/town.cove.actor.searchActorsTypeahead"

  @type suggestion :: %{
          handle: String.t(),
          display_name: String.t() | nil,
          avatar: String.t() | nil
        }

  @spec search_handles(String.t()) :: [suggestion()]
  def search_handles(query) do
    encoded_query = URI.encode_query(q: query, limit: 6)

    url =
      @endpoint
      |> URI.new!()
      |> URI.append_query(encoded_query)
      |> URI.to_string()

    case HTTP.get_json(url, headers: [{"x-client", "annot.at"}]) do
      {:ok, %{"actors" => actors}} ->
        Enum.map(actors, fn actor ->
          %{
            handle: actor["handle"],
            display_name: actor["displayName"],
            avatar: actor["avatar"]
          }
        end)

      _ ->
        []
    end
  end
end
