defmodule AnnotAt.Atproto do
  @moduledoc """
  atproto is the protocol that underpins all of the functionality
  in this service.

  https://atproto.com/
  """

  @inspect_site "https://pdsls.dev/"

  @doc """
  Let users inspect their records.
  """
  def inspect_url(aturi) do
    @inspect_site <> aturi
  end
end
