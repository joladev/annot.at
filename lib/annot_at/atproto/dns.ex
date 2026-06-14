defmodule AnnotAt.Atproto.DNS do
  @moduledoc """
  DNS transport boundary for atproto handle resolution.

  Wraps Erlang's `:inet_res` so this looks more Elixiry. Stubbed
  via Mimic in tests, this module has no unit tests of its own.
  """

  @doc """
  Looks up TXT records for `name`, returning each record as a single string.

  A TXT record can arrive as multiple character-strings, they are concatenated
  per record. Returns an empty list when there are no records or the lookups
  fails, which callers treat as "no DNS answer".
  """
  @spec lookup_txt(String.t()) :: [String.t()]
  def lookup_txt(name) do
    name
    |> String.to_charlist()
    |> :inet_res.lookup(:in, :txt)
    |> Enum.map(&List.to_string/1)
  end
end
