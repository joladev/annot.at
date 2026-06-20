defmodule AnnotAt.Feeds.Entry do
  @moduledoc """
  A normalized feed entry, format-agnostic.

  Used as a normalized feed entry format, where entries come from
  different forms like RSS and atom.
  """

  defstruct [:id, :url, :title, :published_at, :summary, :content]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          url: String.t() | nil,
          title: String.t() | nil,
          published_at: DateTime.t() | nil,
          summary: String.t() | nil,
          content: String.t() | nil
        }
end
