defmodule AnnotAt.Atproto.OAuth.DPoP do
  @moduledoc """
  DPoP (RFC 9449) proof JWTs for atproto OAuth.
  """

  alias AnnotAt.Atproto.OAuth.PKCE

  @curve "P-256"
  @algorithm "ES256"
  @jwt_type "dpop+jwt"

  @doc """
  Generates a new ES256 (P-256) key pair as a JOSE JWK.
  """
  @spec generate_key() :: JOSE.JWK.t()
  def generate_key do
    JOSE.JWK.generate_key({:ec, @curve})
  end

  @doc """
  Signs a DPoP proof JWT for an HTTP request.
  ## Arguments
  - `jwk` — private JOSE JWK for this OAuth session
  - `method` — HTTP method (e.g. `"POST"`)
  - `url` — request URL; query string is stripped for `htu` per atproto
  ## Options
  - `:nonce` — server DPoP nonce (omit when unknown)
  - `:access_token` — adds `ath` (S256 hash) for PDS/resource requests
  - `:jti` — override `jti` (tests)
  - `:iat` — override `iat` (tests)
  Note: atproto currently says **do not** include `iss` on PDS-bound proofs.
  """
  @spec proof(JOSE.JWK.t(), String.t(), String.t(), keyword()) :: String.t()
  def proof(jwk, method, url, opts \\ []) do
    jti = Keyword.get(opts, :jti, random_b64(20))
    iat = Keyword.get(opts, :iat, System.os_time(:second))
    nonce = Keyword.get(opts, :nonce)
    access_token = Keyword.get(opts, :access_token)

    {_, public_jwk} = JOSE.JWK.to_public_map(jwk)

    jws = %{
      "alg" => @algorithm,
      "typ" => @jwt_type,
      "jwk" => public_jwk
    }

    claims =
      %{
        "jti" => jti,
        "htm" => String.upcase(method),
        "htu" => htu(url),
        "iat" => iat
      }
      |> maybe_put("nonce", nonce)
      |> maybe_put("ath", access_token && access_token_hash(access_token))

    jwk
    |> JOSE.JWT.sign(jws, claims)
    |> JOSE.JWS.compact()
    |> elem(1)
  end

  @doc """
  S256 hash of an access token for the `ath` claim (same as PKCE S256)
  """
  @spec access_token_hash(String.t()) :: String.t()
  def access_token_hash(access_token) when is_binary(access_token) do
    PKCE.challenge(access_token)
  end

  @doc """
  Serializes a JWK to a JSON string for storage and whatnot.
  """
  @spec dump(JOSE.JWK.t()) :: String.t()
  def dump(jwk) do
    {_, map} = JOSE.JWK.to_map(jwk)
    Jason.encode!(map)
  end

  @doc """
  Deserializes a JWK from a JSON string.
  """
  @spec load(String.t()) :: JOSE.JWK.t()
  def load(json) do
    json
    |> Jason.decode!()
    |> JOSE.JWK.from()
  end

  defp htu(url) do
    url
    |> URI.parse()
    |> Map.put(:query, nil)
    |> URI.to_string()
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp random_b64(bytes) do
    bytes
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
  end
end
