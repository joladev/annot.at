defmodule AnnotAt.Atproto.DID do
  @moduledoc """
  DID syntax validation per the atproto DID spec.

  Validates syntax only. `did:web` is additionally required to be
  hostname-only (no path or port), per atproto.
  """

  @max_length 2048

  # General atproto DID grammar. The identifier may not end in ":" or "%".
  @syntax ~r/^did:[a-z]+:[a-zA-Z0-9._:%-]*[a-zA-Z0-9._-]$/

  # A bare hostname: dot-separated labels of 1-63 alphanumeric/hyphen chars
  # with no edge hyphens. Rejects path segments (extra colons), ports, and
  # leading/trailing dots, keeping did:web hostname-only.
  @web_host ~r/^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)*[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$/

  @doc """
  Validates atproto DID syntax. For `did:web`, also requires the
  method-specific identifier to be a bare hostname.
  """
  @spec valid?(String.t()) :: boolean()
  def valid?(did) when is_binary(did) do
    byte_size(did) <= @max_length and Regex.match?(@syntax, did) and method_valid?(did)
  end

  defp method_valid?("did:web:" <> host), do: Regex.match?(@web_host, host)
  defp method_valid?(_did), do: true
end
