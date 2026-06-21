defmodule AnnotAt.Feeds.Source do
  @moduledoc """
  A nice wrapper for links to feeds containing metadata about them.
  """

  @type format :: :rss | :atom | :json

  @type t :: %__MODULE__{
          url: String.t(),
          title: String.t() | nil,
          format: format()
        }

  @enforce_keys [:url, :format]
  defstruct [:url, :title, :format]
end
