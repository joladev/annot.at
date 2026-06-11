defmodule AnnotAt.Atproto.OAuth.ClientMetadataTest do
  use ExUnit.Case, async: true

  alias AnnotAt.Atproto.OAuth.ClientAssertion
  alias AnnotAt.Atproto.OAuth.ClientMetadata

  @fixture Path.expand("../../../support/fixtures/atproto/es256_jwk.json", __DIR__)

  setup do
    jwk =
      @fixture
      |> File.read!()
      |> Jason.decode!()
      |> JOSE.JWK.from()

    %{jwk: jwk}
  end

  defp build(jwk, extra \\ []) do
    ClientMetadata.build(
      extra ++
        [
          client_id: "https://annot.at/oauth-client-metadata.json",
          redirect_uris: ["https://annot.at/auth/callback"],
          scope: "atproto",
          jwk: jwk
        ]
    )
  end

  test "build/1 sets the spec-required fields", %{jwk: jwk} do
    metadata = build(jwk)

    assert metadata["client_id"] == "https://annot.at/oauth-client-metadata.json"
    assert metadata["application_type"] == "web"
    assert metadata["grant_types"] == ["authorization_code", "refresh_token"]
    assert metadata["response_types"] == ["code"]
    assert metadata["redirect_uris"] == ["https://annot.at/auth/callback"]
    assert metadata["scope"] == "atproto"
    assert metadata["dpop_bound_access_tokens"] == true
    assert metadata["token_endpoint_auth_method"] == "private_key_jwt"
    assert metadata["token_endpoint_auth_signing_alg"] == "ES256"
  end

  test "build/1 publishes only the public key, with the assertion kid", %{jwk: jwk} do
    %{"jwks" => %{"keys" => [key]}} = build(jwk)

    refute Map.has_key?(key, "d")
    assert key["kty"] == "EC"
    assert key["crv"] == "P-256"
    assert key["kid"] == ClientAssertion.kid(jwk)
  end

  test "build/1 includes optional fields only when given", %{jwk: jwk} do
    metadata = build(jwk, client_name: "AnnotAt", client_uri: "https://annot.at")

    assert metadata["client_name"] == "AnnotAt"
    assert metadata["client_uri"] == "https://annot.at"

    bare = build(jwk)
    refute Map.has_key?(bare, "client_name")
    refute Map.has_key?(bare, "client_uri")
  end

  test "build/1 raises when scope is missing atproto", %{jwk: jwk} do
    assert_raise ArgumentError, fn ->
      build(jwk, scope: "repo:site.standard.*")
    end
  end
end
