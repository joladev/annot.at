defmodule AnnotAt.Feeds.Feed do
  @moduledoc """
  Normalized feed metadata plus entries, format-agnostic.

  Note that the `url` field is the channel's canonical URL.
  """

  alias AnnotAt.Feeds.Entry

  defstruct [:title, :description, :url, entries: []]

  @type t :: %__MODULE__{
          title: String.t(),
          description: String.t() | nil,
          url: String.t() | nil,
          entries: [Entry.t()]
        }
end
