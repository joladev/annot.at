defmodule AnnotAt.Atproto.OAuth.TokenResponseTest do
  use ExUnit.Case, async: true

  alias AnnotAt.Atproto.OAuth.TokenResponse

  @fixture Path.expand("../../../support/fixtures/atproto/token_response.json", __DIR__)

  setup do
    response =
      @fixture
      |> File.read!()
      |> Jason.decode!()

    %{response: response}
  end

  test "parse/1 accepts a DPoP token response", %{response: response} do
    assert {:ok, parsed} = TokenResponse.parse(response)

    assert parsed.access_token ==
             "eyJ0eXAiOiJhdCtqd3QiLCJhbGciOiJFUzI1NiJ9.fake-payload.fake-signature"

    assert parsed.refresh_token == "ref-3C2EzDmzzkrcA9rerRmYeg5wBPCRZdnGRkRKUOvbLq"
    assert parsed.expires_in == 3599
    assert parsed.scope == "atproto"
    assert parsed.sub == "did:plc:ewvi7nxzyoun6zhxrhs64oiz"
  end

  test "parse/1 reports any missing required field", %{response: response} do
    for field <- ["access_token", "token_type", "refresh_token", "scope", "expires_in", "sub"] do
      assert TokenResponse.parse(Map.delete(response, field)) == {:error, {:missing, field}}
    end
  end

  test "parse/1 rejects non-DPoP token types", %{response: response} do
    assert TokenResponse.parse(%{response | "token_type" => "Bearer"}) ==
             {:error, {:invalid, "token_type"}}

    assert {:ok, _} = TokenResponse.parse(%{response | "token_type" => "dpop"})
  end

  test "parse/1 rejects a sub that is not a DID", %{response: response} do
    assert TokenResponse.parse(%{response | "sub" => "alice.bsky.social"}) ==
             {:error, {:invalid, "sub"}}
  end

  test "parse/1 rejects a non-integer expires_in", %{response: response} do
    assert TokenResponse.parse(%{response | "expires_in" => "3599"}) ==
             {:error, {:invalid, "expires_in"}}
  end
end
