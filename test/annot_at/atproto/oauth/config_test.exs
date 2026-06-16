defmodule AnnotAt.Atproto.OAuth.ConfigTest do
  use ExUnit.Case, async: true

  alias AnnotAt.Atproto.OAuth.Config

  test "derives client_id and redirect_uri from the base URL" do
    assert "http://localhost:4002/oauth-client-metadata.json" == Config.client_id()
    assert "http://localhost:4002/auth/callback" == Config.redirect_uri()
  end

  test "scope/0 returns the configured scope" do
    assert Config.scope() =~ "atproto"
  end

  test "signing_key/0 parses the configured JWK" do
    jwk = Config.signing_key()
    {_, map} = JOSE.JWK.to_map(jwk)

    assert "EC" == map["kty"]
    assert "P-256" == map["crv"]
    assert map["d"]
  end
end
