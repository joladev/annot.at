defmodule AnnotAt.Atproto.DIDDocumentTest do
  use ExUnit.Case, async: true

  alias AnnotAt.Atproto.DIDDocument

  @fixture Path.expand("../../support/fixtures/atproto/did_document.json", __DIR__)
  @did "did:plc:ewvi7nxzyoun6zhxrhs64oiz"

  setup do
    document =
      @fixture
      |> File.read!()
      |> Jason.decode!()

    %{document: document}
  end

  test "parse/2 extracts handle and PDS from the atproto.com document", %{document: document} do
    assert {:ok, parsed} = DIDDocument.parse(document, @did)

    assert parsed.did == @did
    assert parsed.handle == "atproto.com"
    assert parsed.pds_endpoint == "https://enoki.us-east.host.bsky.network"
  end

  test "parse/2 rejects a document whose id does not match the resolved DID", %{
    document: document
  } do
    assert DIDDocument.parse(document, "did:plc:someoneelse") == {:error, :did_mismatch}
  end

  test "parse/2 returns :invalid_handle when no alsoKnownAs entry is a valid at:// handle", %{
    document: document
  } do
    document = Map.put(document, "alsoKnownAs", ["https://atproto.com", "at://-bad-.handle"])
    assert DIDDocument.parse(document, @did) == {:error, :invalid_handle}
  end

  test "parse/2 picks the first syntactically valid handle", %{document: document} do
    document = Map.put(document, "alsoKnownAs", ["at://nothttp", "at://second.example.com"])
    assert {:ok, parsed} = DIDDocument.parse(document, @did)
    assert parsed.handle == "second.example.com"
  end

  test "parse/2 returns :no_pds when no service entry is an atproto PDS", %{document: document} do
    document = Map.put(document, "service", [%{"id" => "#other", "type" => "Something"}])
    assert DIDDocument.parse(document, @did) == {:error, :no_pds}
  end

  test "parse/2 rejects a PDS endpoint that has a path", %{document: document} do
    service = [
      %{
        "id" => "#atproto_pds",
        "type" => "AtprotoPersonalDataServer",
        "serviceEndpoint" => "https://pds.example.com/path"
      }
    ]

    document = Map.put(document, "service", service)
    assert DIDDocument.parse(document, @did) == {:error, :invalid_pds_endpoint}
  end
end
