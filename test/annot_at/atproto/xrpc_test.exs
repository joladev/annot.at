defmodule AnnotAt.Atproto.XRPCTest do
  use ExUnit.Case, async: true
  use Mimic

  alias AnnotAt.Atproto.HTTP
  alias AnnotAt.Atproto.OAuth.Session
  alias AnnotAt.Atproto.XRPC

  @did "did:plc:ewvi7nxzyoun6zhxrhs64oiz"
  @pds "https://shaggymane.us-west.host.bsky.network"

  setup do
    jwk =
      "../../support/fixtures/atproto/es256_jwk.json"
      |> Path.expand(__DIR__)
      |> File.read!()
      |> Jason.decode!()
      |> JOSE.JWK.from()

    session = %Session{
      did: "did:plc:abc",
      access_token: "access-1",
      refresh_token: "refresh-1",
      dpop_key: jwk,
      scope: "atproto",
      issuer: "https://bsky.social",
      pds_endpoint: @pds,
      expires_at: ~U[2026-01-01 00:00:00Z]
    }

    %{session: session}
  end

  test "query/3 sends a DPoP-authenticated GET with ath and returns the body", %{session: session} do
    expect(HTTP, :request, fn "GET", url, headers, nil ->
      assert "#{@pds}/xrpc/app.bsky.actor.getProfile?actor=did%3Aplc%3Aabc" == url
      assert {"authorization", "DPoP access-1"} in headers

      {"dpop", proof} = List.keyfind(headers, "dpop", 0)
      %JOSE.JWT{fields: claims} = JOSE.JWT.peek_payload(proof)
      assert claims["ath"]

      {:ok, %{status: 200, body: ~s({"displayName":"Jola"}), headers: %{}}}
    end)

    assert {:ok, %{"displayName" => "Jola"}} =
             XRPC.query(session, "app.bsky.actor.getProfile", actor: "did:plc:abc")
  end

  test "query/3 retries with the PDS nonce", %{session: session} do
    expect(HTTP, :request, fn "GET", _url, _headers, nil ->
      {:ok,
       %{
         status: 401,
         body: ~s({}),
         headers: %{
           "www-authenticate" => ["DPoP error=\"use_dpop_nonce\""],
           "dpop-nonce" => ["nonce-1"]
         }
       }}
    end)

    expect(HTTP, :request, fn "GET", _url, headers, nil ->
      {"dpop", proof} = List.keyfind(headers, "dpop", 0)
      %JOSE.JWT{fields: claims} = JOSE.JWT.peek_payload(proof)
      assert "nonce-1" == claims["nonce"]

      {:ok, %{status: 200, body: ~s({"ok":true}), headers: %{}}}
    end)

    assert {:ok, %{"ok" => true}} = XRPC.query(session, "app.bsky.actor.getProfile")
  end

  test "query/3 surfaces an XRPC error", %{session: session} do
    expect(HTTP, :request, fn "GET", _url, _headers, nil ->
      {:ok, %{status: 400, body: ~s({"error":"InvalidRequest"}), headers: %{}}}
    end)

    assert {:error, {:xrpc_error, 400, %{"error" => "InvalidRequest"}}} =
             XRPC.query(session, "app.bsky.actor.getProfile")
  end

  test "query/3 returns :missing_dpop_nonce when the 401 has no nonce header", %{session: session} do
    expect(HTTP, :request, fn "GET", _url, _headers, nil ->
      {:ok,
       %{
         status: 401,
         body: ~s({}),
         headers: %{"www-authenticate" => ["DPoP error=\"use_dpop_nonce\""]}
       }}
    end)

    assert {:error, :missing_dpop_nonce} = XRPC.query(session, "app.bsky.actor.getProfile")
  end

  test "procedure/3 sends an authenticated POST with a JSON body", %{session: session} do
    body = %{"repo" => @did, "collection" => "app.bsky.feed.post", "record" => %{"text" => "hi"}}

    expect(HTTP, :request, fn "POST", url, headers, {:json, ^body} ->
      assert "#{@pds}/xrpc/com.atproto.repo.createRecord" == url
      assert {"authorization", "DPoP access-1"} in headers

      {"dpop", proof} = List.keyfind(headers, "dpop", 0)
      %JOSE.JWT{fields: claims} = JOSE.JWT.peek_payload(proof)
      assert "POST" == claims["htm"]
      assert claims["ath"]

      {:ok, %{status: 200, body: ~s({"uri":"at://x"}), headers: %{}}}
    end)

    assert {:ok, %{"uri" => "at://x"}} =
             XRPC.procedure(session, "com.atproto.repo.createRecord", body)
  end

  test "upload_blob/3 POSTs raw bytes with a content type and returns the blob", %{
    session: session
  } do
    bytes = <<137, 80, 78, 71>>

    expect(HTTP, :request, fn "POST", url, headers, {:raw, ^bytes, "image/png"} ->
      assert "#{@pds}/xrpc/com.atproto.repo.uploadBlob" == url
      assert {"authorization", "DPoP access-1"} in headers

      {"dpop", proof} = List.keyfind(headers, "dpop", 0)
      %JOSE.JWT{fields: claims} = JOSE.JWT.peek_payload(proof)
      assert "POST" == claims["htm"]
      assert claims["ath"]

      {:ok, %{status: 200, body: ~s({"blob":{"$type":"blob"}}), headers: %{}}}
    end)

    assert {:ok, %{"blob" => %{"$type" => "blob"}}} =
             XRPC.upload_blob(session, bytes, "image/png")
  end
end
