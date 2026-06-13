defmodule AnnotAt.Atproto.OAuth.ServerMetadataTest do
  use ExUnit.Case, async: true

  alias AnnotAt.Atproto.OAuth.ServerMetadata

  @fixture Path.expand("../../../support/fixtures/atproto/server_metadata.json", __DIR__)

  @required_fields [
    "issuer",
    "authorization_endpoint",
    "token_endpoint",
    "pushed_authorization_request_endpoint",
    "response_types_supported",
    "grant_types_supported",
    "code_challenge_methods_supported",
    "token_endpoint_auth_methods_supported",
    "token_endpoint_auth_signing_alg_values_supported",
    "scopes_supported",
    "dpop_signing_alg_values_supported",
    "require_pushed_authorization_requests",
    "authorization_response_iss_parameter_supported",
    "client_id_metadata_document_supported"
  ]

  setup do
    metadata =
      @fixture
      |> File.read!()
      |> Jason.decode!()

    %{metadata: metadata}
  end

  test "parse/1 accepts the bsky.social document", %{metadata: metadata} do
    assert {:ok, parsed} = ServerMetadata.parse(metadata)

    assert parsed.issuer == "https://bsky.social"
    assert parsed.authorization_endpoint == "https://bsky.social/oauth/authorize"
    assert parsed.token_endpoint == "https://bsky.social/oauth/token"
    assert parsed.par_endpoint == "https://bsky.social/oauth/par"
    assert parsed.revocation_endpoint == "https://bsky.social/oauth/revoke"
    assert "atproto" in parsed.scopes_supported
  end

  test "parse/1 reports any missing required field", %{metadata: metadata} do
    for field <- @required_fields do
      assert ServerMetadata.parse(Map.delete(metadata, field)) == {:error, {:missing, field}}
    end
  end

  test "parse/1 rejects an issuer that is not a bare https origin", %{metadata: metadata} do
    for issuer <- [
          "https://bsky.social/",
          "https://bsky.social/oauth",
          "https://bsky.social?x=1",
          "http://bsky.social"
        ] do
      assert ServerMetadata.parse(%{metadata | "issuer" => issuer}) ==
               {:error, {:invalid, "issuer"}}
    end
  end

  test "parse/1 rejects servers missing required capabilities", %{metadata: metadata} do
    cases = [
      {"code_challenge_methods_supported", ["plain"]},
      {"dpop_signing_alg_values_supported", ["RS256"]},
      {"require_pushed_authorization_requests", false}
    ]

    for {field, value} <- cases do
      assert ServerMetadata.parse(%{metadata | field => value}) == {:error, {:invalid, field}}
    end
  end
end
