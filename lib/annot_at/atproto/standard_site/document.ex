defmodule AnnotAt.Atproto.StandardSite.Document do
  @moduledoc "A `site.standard.document` record (a published post)."

  @enforce_keys [:rkey, :site, :title, :published_at]
  defstruct [
    :rkey,
    :site,
    :title,
    :path,
    :published_at,
    :updated_at,
    :description,
    :text_content,
    :content,
    :tags,
    :cover_image
  ]

  @type t :: %__MODULE__{
          rkey: String.t(),
          site: String.t(),
          title: String.t(),
          path: String.t() | nil,
          published_at: DateTime.t(),
          updated_at: DateTime.t() | nil,
          description: String.t() | nil,
          text_content: String.t() | nil,
          content: String.t() | nil,
          tags: [String.t()] | nil,
          cover_image: {binary(), String.t()} | nil
        }

  def split_aturi(aturi) do
    case String.split(aturi, "/") do
      ["at:", "", did, "site.standard.document", rkey] ->
        {:ok, %{did: did, rkey: rkey}}

      _ ->
        {:error, :invalid}
    end
  end
end
