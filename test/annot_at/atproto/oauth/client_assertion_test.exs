defmodule AnnotAt.Atproto.OAuth.ClientAssertionTest do
  use ExUnit.Case, async: true

  alias AnnotAt.Atproto.OAuth.ClientAssertion

  @fixture Path.expand("../../../support/fixtures/atproto/es256_jwk.json", __DIR__)

  # RFC 7638 SHA-256 thumbprint of the fixture key, computed externally
  @fixture_thumbprint "i7xgge3EZQmET-d57_G53RfYSp6nmGAqIxVRdWARNDc"

  setup do
    jwk =
      @fixture
      |> File.read!()
      |> Jason.decode!()
      |> JOSE.JWK.from()

    %{jwk: jwk}
  end

  test "sign/4 builds a JWT with RFC 7523 claims", %{jwk: jwk} do
    token =
      ClientAssertion.sign(
        jwk,
        "https://annot.at/oauth-client-metadata.json",
        "https://bsky.social",
        jti: "test-jti",
        iat: 1_700_000_000
      )

    %JOSE.JWT{fields: claims} = JOSE.JWT.peek_payload(token)

    assert claims["iss"] == "https://annot.at/oauth-client-metadata.json"
    assert claims["sub"] == "https://annot.at/oauth-client-metadata.json"
    assert claims["aud"] == "https://bsky.social"
    assert claims["jti"] == "test-jti"
    assert claims["iat"] == 1_700_000_000
    assert claims["exp"] == 1_700_000_060
  end

  test "sign/4 sets alg, typ and kid in the protected header", %{jwk: jwk} do
    token = ClientAssertion.sign(jwk, "client-id", "https://bsky.social", jti: "j", iat: 0)

    [header_b64, _, _] = String.split(token, ".")

    header =
      header_b64
      |> Base.url_decode64!(padding: false)
      |> Jason.decode!()

    assert header == %{"alg" => "ES256", "typ" => "JWT", "kid" => @fixture_thumbprint}
  end

  test "sign/4 signature verifies with the public key", %{jwk: jwk} do
    token = ClientAssertion.sign(jwk, "client-id", "https://bsky.social", jti: "j", iat: 0)

    public = JOSE.JWK.to_public(jwk)
    assert {true, _, _} = JOSE.JWT.verify_strict(public, ["ES256"], token)
  end

  test "kid/1 prefers an explicit kid over the thumbprint", %{jwk: jwk} do
    assert ClientAssertion.kid(jwk) == @fixture_thumbprint

    {_, map} = JOSE.JWK.to_map(jwk)
    with_kid = JOSE.JWK.from(Map.put(map, "kid", "my-key-1"))

    assert ClientAssertion.kid(with_kid) == "my-key-1"
  end
end
