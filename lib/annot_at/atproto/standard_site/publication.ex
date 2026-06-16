defmodule AnnotAt.Atproto.StandardSite.Publication do
  @moduledoc "A `site.standard.publication` record (the site itself)."

  @enforce_keys [:name, :url]
  defstruct [:name, :url, :description, :icon]

  @type t :: %__MODULE__{
          name: String.t(),
          url: String.t(),
          description: String.t() | nil,
          icon: {binary(), String.t()} | nil
        }
end
