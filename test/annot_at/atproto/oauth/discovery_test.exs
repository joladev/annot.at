defmodule AnnotAt.Atproto.OAuth.DiscoveryTest do
  use ExUnit.Case, async: true
  use Mimic

  alias AnnotAt.Atproto.HTTP
  alias AnnotAt.Atproto.OAuth.Discovery
  alias AnnotAt.Atproto.OAuth.ServerMetadata

  @pds "https://enoki.us-east.host.bsky.network"
  @issuer "https://bsky.social"

  @protected_resource "../../../support/fixtures/atproto/protected_resource.json"
                      |> Path.expand(__DIR__)
                      |> File.read!()
                      |> Jason.decode!()

  @server_metadata "../../../support/fixtures/atproto/server_metadata.json"
                   |> Path.expand(__DIR__)
                   |> File.read!()
                   |> Jason.decode!()

  test "discovers and validates the authorization server" do
    pr_url = @pds <> "/.well-known/oauth-protected-resource"
    as_url = @issuer <> "/.well-known/oauth-authorization-server"

    expect(HTTP, :get_json, fn ^pr_url -> {:ok, @protected_resource} end)
    expect(HTTP, :get_json, fn ^as_url -> {:ok, @server_metadata} end)

    assert {:ok, %ServerMetadata{} = server} = Discovery.discover(@pds)
    assert server.issuer == @issuer
    assert server.par_endpoint == @issuer <> "/oauth/par"
    assert server.token_endpoint == @issuer <> "/oauth/token"
  end

  test "rejects a protected resource whose resource does not match the PDS" do
    resource = %{"resource" => "https://attacker.example", "authorization_servers" => [@issuer]}
    expect(HTTP, :get_json, fn _ -> {:ok, resource} end)

    assert {:error, :resource_mismatch} == Discovery.discover(@pds)
  end

  test "rejects a protected resource with no authorization server" do
    resource = %{"resource" => @pds, "authorization_servers" => []}
    expect(HTTP, :get_json, fn _ -> {:ok, resource} end)

    assert {:error, :no_authorization_server} == Discovery.discover(@pds)
  end

  test "rejects when the server metadata issuer does not match the discovered URL" do
    resource = %{"resource" => @pds, "authorization_servers" => ["https://attacker.example"]}
    as_url = "https://attacker.example/.well-known/oauth-authorization-server"

    expect(HTTP, :get_json, fn _ -> {:ok, resource} end)
    expect(HTTP, :get_json, fn ^as_url -> {:ok, @server_metadata} end)

    assert {:error, :issuer_mismatch} = Discovery.discover(@pds)
  end

  test "propagates a transport error from the protected resource fetch" do
    expect(HTTP, :get_json, fn _ -> {:error, {:transport, :econnrefused}} end)

    assert {:error, {:transport, :econnrefused}} == Discovery.discover(@pds)
  end
end
