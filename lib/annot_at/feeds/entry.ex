defmodule AnnotAt.Feeds.Entry do
  @moduledoc """
  A normalized feed entry, format-agnostic.

  Used as a normalized feed entry format, where entries come from
  different forms like RSS and atom.
  """

  defstruct [
    :id,
    :url,
    :title,
    :published_at,
    :summary,
    :content,
    :rkey,
    :image,
    cover_status: :none
  ]

  @type cover_status :: :ok | :too_large | :not_image | :unknown | :none

  @type t :: %__MODULE__{
          id: String.t() | nil,
          url: String.t() | nil,
          title: String.t() | nil,
          published_at: DateTime.t() | nil,
          summary: String.t() | nil,
          content: String.t() | nil,
          rkey: String.t() | nil,
          image: String.t() | nil,
          cover_status: cover_status()
        }

  def hash(%__MODULE__{} = entry) do
    # Join collapses the potential nils that :crypto.hash doesn't accept.
    iodata = Enum.join([entry.title, entry.summary, entry.content])
    hash = :crypto.hash(:sha256, iodata)
    Base.encode16(hash, case: :lower)
  end
end
