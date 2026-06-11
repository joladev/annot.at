defmodule AnnotAt.Atproto.OAuth.ClientAssertion do
  @moduledoc """
  Client assertion JWTs (RFC 7523 `private_key_jwt`) for atproto OAuth.

  Confidential clients authenticate to the authorization server by signing
  a fresh assertion for every PAR and token request.
  """

  @algorithm "ES256"
  @assertion_type "urn:ietf:params:oauth:client-assertion-type:jwt-bearer"
  @lifetime_seconds 60

  @doc """
  The `client_assertion_type` request parameter value.
  """
  @spec assertion_type() :: String.t()
  def assertion_type do
    @assertion_type
  end

  @doc """
  Signs a client assertion JWT.

  ## Arguments
  - `jwk` - the client's private JOSE JWK
  - `client_id` - used as both `iss` and `sub`
  - `audience` - the authorization server's `issuer` URL

  ## Options
  - `:jti` - override `jti` (tests)
  - `:iat` - override `iat` (tests)

  `exp` is `iat` + #{@lifetime_seconds}s: atproto does not require it,
  but RFC 7523 does, and servers expect assertions younger than a minute.
  """

  @spec sign(JOSE.JWK.t(), String.t(), String.t(), keyword()) :: String.t()
  def sign(jwk, client_id, audience, opts \\ []) do
    jti = Keyword.get(opts, :jti, random_b64(20))
    iat = Keyword.get(opts, :iat, System.os_time(:second))

    jws = %{
      "alg" => @algorithm,
      "typ" => "JWT",
      "kid" => kid(jwk)
    }

    claims = %{
      "iss" => client_id,
      "sub" => client_id,
      "aud" => audience,
      "jti" => jti,
      "iat" => iat,
      "exp" => iat + @lifetime_seconds
    }

    jwk
    |> JOSE.JWT.sign(jws, claims)
    |> JOSE.JWS.compact()
    |> elem(1)
  end

  @doc """
  Key ID for the client signing key: the JWK's own `kid` if set, otherwise
  its RFC 7638 thumbprint.

  The published client metadata JWKs must use the same value so the
  authorization server can match assertion headers to a key.
  """
  @spec kid(JOSE.JWK.t()) :: String.t()
  def kid(jwk) do
    {_, map} = JOSE.JWK.to_map(jwk)
    Map.get_lazy(map, "kid", fn -> JOSE.JWK.thumbprint(jwk) end)
  end

  defp random_b64(bytes) do
    bytes
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
  end
end
