defmodule AnnotAt.Atproto.OAuth.PKCE do
  @moduledoc """
  PKCE (RFC 7636) helpers for atproto OAuth.
  """

  @verifier_min_bytes 32

  @doc """
  Generates a PKCE code verifier (base64url-encoded random bytes).

  Length is 43-128 characters RFC 7636 / atproto OAuth.
  """
  @spec generate_verifier() :: String.t()
  def generate_verifier do
    @verifier_min_bytes
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
  end

  @doc """
  Derives S256 code challenge from code verifier.
  """
  @spec challenge(String.t()) :: String.t()
  def challenge(verifier) when is_binary(verifier) do
    result = :crypto.hash(:sha256, verifier)

    Base.url_encode64(result, padding: false)
  end
end
