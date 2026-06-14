defmodule AnnotAt.Atproto.IdentityTest do
  use ExUnit.Case, async: true
  use Mimic

  alias AnnotAt.Atproto.DNS
  alias AnnotAt.Atproto.HTTP
  alias AnnotAt.Atproto.Identity

  @did "did:plc:ewvi7nxzyoun6zhxrhs64oiz"
  @handle "atproto.com"
  @pds "https://enoki.us-east.host.bsky.network"

  @document "../../support/fixtures/atproto/did_document.json"
            |> Path.expand(__DIR__)
            |> File.read!()
            |> Jason.decode!()

  test "resolves via DNS and verifies bidirectionally" do
    expect(DNS, :lookup_txt, fn "_atproto.atproto.com" -> ["did=" <> @did] end)
    expect(HTTP, :get_json, fn "https://plc.directory/" <> _ -> {:ok, @document} end)
    reject(&HTTP.get_text/1)

    assert {:ok, identity} = Identity.resolve_handle(@handle)
    assert identity.did == @did
    assert identity.handle == @handle
    assert identity.pds_endpoint == @pds
  end

  test "normalizes input before resolving" do
    expect(DNS, :lookup_txt, fn "_atproto.atproto.com" -> ["did=" <> @did] end)
    expect(HTTP, :get_json, fn _ -> {:ok, @document} end)

    assert {:ok, identity} = Identity.resolve_handle("  @ATPROTO.com  ")
    assert identity.handle == @handle
  end

  test "falls back to the HTTPS well-known method when DNS has no record" do
    expect(DNS, :lookup_txt, fn _ -> [] end)

    expect(HTTP, :get_text, fn "https://atproto.com/.well-known/atproto-did" ->
      {:ok, @did <> "\n"}
    end)

    expect(HTTP, :get_json, fn _ -> {:ok, @document} end)

    assert {:ok, identity} = Identity.resolve_handle(@handle)
    assert identity.did == @did
  end

  test "hard-fails on conflicting DNS records without trying HTTPS" do
    expect(DNS, :lookup_txt, fn _ ->
      ["did=did:plc:aaaaaaaaaaaaaaaaaaaaaaaa", "did=did:plc:bbbbbbbbbbbbbbbbbbbbbbbb"]
    end)

    reject(&HTTP.get_text/1)
    assert {:error, :ambiguous_dns} == Identity.resolve_handle(@handle)
  end

  test "rejects a DID document that claims a different handle" do
    expect(DNS, :lookup_txt, fn _ -> ["did=" <> @did] end)
    expect(HTTP, :get_json, fn _ -> {:ok, @document} end)

    assert {:error, :handle_mismatch} == Identity.resolve_handle("evil.example.com")
  end

  test "rejects a syntatically invalid handle before any lookup" do
    reject(&DNS.lookup_txt/1)
    assert {:error, :invalid_handle} == Identity.resolve_handle("not a handle")
  end

  test "resolves a did:web identity" do
    web_did = "did:web:pds.example.com"

    doc = %{
      "id" => web_did,
      "alsoKnownAs" => ["at://example.com"],
      "service" => [
        %{
          "id" => "#atproto_pds",
          "type" => "AtprotoPersonalDataServer",
          "serviceEndpoint" => "https://pds.example.com"
        }
      ]
    }

    expect(DNS, :lookup_txt, fn _ -> ["did=" <> web_did] end)

    expect(HTTP, :get_json, fn "https://pds.example.com/.well-known/did.json" ->
      {:ok, doc}
    end)

    assert {:ok, identity} = Identity.resolve_handle("example.com")
    assert identity.did == web_did
    assert identity.pds_endpoint == "https://pds.example.com"
  end

  test "rejects an invalid DID from handle resolution before fetching" do
    expect(DNS, :lookup_txt, fn _ -> ["did=did:web:.evil.example.com"] end)
    reject(&HTTP.get_json/1)

    assert Identity.resolve_handle("evil.example.com") == {:error, :invalid_did}
  end
end
