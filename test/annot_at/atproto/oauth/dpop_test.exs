defmodule AnnotAt.Atproto.OAuth.DPoPTest do
  use ExUnit.Case, async: true

  alias AnnotAt.Atproto.OAuth.DPoP

  @fixture Path.expand("../../../support/fixtures/atproto/es256_jwk.json", __DIR__)

  setup do
    jwk =
      @fixture
      |> File.read!()
      |> Jason.decode!()
      |> JOSE.JWK.from()

    %{jwk: jwk}
  end

  test "generate_key/0 returns an EC key" do
    jwk = DPoP.generate_key()
    {_, map} = JOSE.JWK.to_map(jwk)
    assert map["kty"] == "EC"
    assert map["crv"] == "P-256"
  end

  test "proof/4 builds a dpop+jwt with required claims", %{jwk: jwk} do
    token =
      DPoP.proof(jwk, "POST", "https://bsky.social/oauth/par?foo=bar",
        jti: "test-jti",
        iat: 1_700_000_000
      )

    %JOSE.JWT{fields: claims} = JOSE.JWT.peek_payload(token)

    assert claims["jti"] == "test-jti"
    assert claims["htm"] == "POST"
    assert claims["htu"] == "https://bsky.social/oauth/par"
    assert claims["iat"] == 1_700_000_000
    refute Map.has_key?(claims, "nonce")
    refute Map.has_key?(claims, "ath")
  end

  test "proof/4 includes nonce when provided", %{jwk: jwk} do
    token =
      DPoP.proof(jwk, "POST", "https://bsky.social/oauth/token", nonce: "n-1", jti: "j", iat: 0)

    %JOSE.JWT{fields: claims} = JOSE.JWT.peek_payload(token)
    assert claims["nonce"] == "n-1"
  end

  test "proof/4 includes ath when access_token provided", %{jwk: jwk} do
    token =
      DPoP.proof(jwk, "GET", "https://pds.example/xrpc/app.bsky.actor.getProfile",
        access_token: "my-token",
        jti: "j",
        iat: 0
      )

    %JOSE.JWT{fields: claims} = JOSE.JWT.peek_payload(token)
    assert claims["ath"] == DPoP.access_token_hash("my-token")
  end
end
