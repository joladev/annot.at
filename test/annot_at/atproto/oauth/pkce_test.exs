defmodule AnnotAt.Atproto.OAuth.PkceTest do
  use ExUnit.Case, async: true

  alias AnnotAt.Atproto.OAuth.PKCE

  # RFC 7636 appendix B
  @verifier "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
  @challenge "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM"

  test "challenge/1 S256 matches RFC 7636 appendix B" do
    assert PKCE.challenge(@verifier) == @challenge
  end

  test "generate_verifier/0 returns base64url string of valid length" do
    verifier = PKCE.generate_verifier()

    assert String.match?(verifier, ~r/^[A-Za-z0-9_-]+$/)
    assert byte_size(verifier) >= 43
    assert byte_size(verifier) <= 128
  end

  test "challenge/1 is deterministic for the same verifier" do
    assert PKCE.challenge(@verifier) == PKCE.challenge(@verifier)
  end
end
