defmodule AnnotAt.Atproto.Handle do
  @moduledoc """
  Handle syntax validation and normalization per the atproto handle spec.
  """

  @max_length 253

  # Segments of 1-63 alphanumeric/hyphen chars (no edge hyphens), at least
  # two segments, TLD must not start with a digit.
  @syntax ~r/^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$/

  @doc """
  Normalizes user input: trims whitespace, strips leading `@`, downcase.
  """
  @spec normalize(String.t()) :: String.t()
  def normalize(input) when is_binary(input) do
    input
    |> String.trim()
    |> String.trim_leading("@")
    |> String.downcase()
  end

  @doc """
  Checks handle syntax. Does not check resolvability or reserved names.
  """
  @spec valid?(String.t()) :: boolean()
  def valid?(handle) when is_binary(handle) do
    byte_size(handle) <= @max_length and Regex.match?(@syntax, handle)
  end
end
