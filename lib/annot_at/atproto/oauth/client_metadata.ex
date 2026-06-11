defmodule AnnotAt.Atproto.OAuth.ClientMetadata do
  @moduledoc """
  Client metadata document for atproto OAuth.

  Served at the `client_id` URL. Authorization servers fetch it to discover
  redirect URIs, scopes, and the client's public signing key.
  """

  alias AnnotAt.Atproto.OAuth.ClientAssertion

  @doc """
  Builds the client metadata document as a JSON-serializable map.

  ## Options
  - `:client_id` (required) - full URL of the metadata document itself
  - `:redirect_uris` (required) - list of callback URLs
  - `:scope` (required) - space-separated scopes, must include `atproto`
  - `:jwk` (required) - client signing key, only the public part is published
  - `:client_name` (optional)
  - `:client_uri` (optional) - must share the `client_id` hostname
  """
  @spec build(keyword()) :: map()
  def build(opts) do
    scope = Keyword.fetch!(opts, :scope)

    if "atproto" not in String.split(scope, " ") do
      raise ArgumentError, "scope must include atproto, got #{inspect(scope)}"
    end

    client_id = Keyword.fetch!(opts, :client_id)
    redirect_uris = Keyword.fetch!(opts, :redirect_uris)
    client_name = Keyword.get(opts, :client_name)
    client_uri = Keyword.get(opts, :client_uri)
    jwk = Keyword.fetch!(opts, :jwk)

    %{
      "client_id" => client_id,
      "application_type" => "web",
      "grant_types" => ["authorization_code", "refresh_token"],
      "response_types" => ["code"],
      "redirect_uris" => redirect_uris,
      "scope" => scope,
      "dpop_bound_access_tokens" => true,
      "token_endpoint_auth_method" => "private_key_jwt",
      "token_endpoint_auth_signing_alg" => "ES256",
      "jwks" => %{"keys" => [public_jwk(jwk)]}
    }
    |> maybe_put("client_name", client_name)
    |> maybe_put("client_uri", client_uri)
  end

  defp public_jwk(jwk) do
    {_, public} = JOSE.JWK.to_public_map(jwk)
    Map.put(public, "kid", ClientAssertion.kid(jwk))
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
