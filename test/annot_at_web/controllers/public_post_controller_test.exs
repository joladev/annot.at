defmodule AnnotAtWeb.PublicPostControllerTest do
  use AnnotAtWeb.ConnCase, async: true
  use Mimic

  alias AnnotAt.Atproto.DIDDocument
  alias AnnotAt.Atproto.StandardSite

  @did "did:plc:ewvi7nxzyoun6zhxrhs64oiz"
  @rkey "3mlhhbujc22gw"

  test "GET /p/:did/rkey renders the document", %{conn: conn} do
    did_doc = %DIDDocument{did: @did, handle: "jola.dev", pds_endpoint: "https://pds.example"}

    doc = %{
      "title" => "Running local models on M4",
      "publishedAt" => "2026-03-23T12:00:00Z",
      "site" => "at://#{@did}/site.standard.publication/pub1",
      "tags" => ["ai"],
      "content" => %{
        "$type" => "org.wordpress.html",
        "html" => "<p>Hello<strong>world</strong>.</p>"
      },
      "textContent" => "Hello world."
    }

    pub = %{"name" => "jola.dev blog", "icon" => nil}

    expect(StandardSite, :get_public_document, fn @did, @rkey -> {:ok, doc, did_doc} end)
    expect(StandardSite, :get_public_publication, fn "at://" <> _ -> {:ok, pub, did_doc} end)

    html =
      conn
      |> get(~p"/p/#{@did}/#{@rkey}")
      |> html_response(200)

    assert html =~ "Running local models on M4"
    assert html =~ "<strong>world</strong>"
    assert html =~ "jola.dev blog"
  end

  test "GET /p/:did/:rkey 404s when the record can't be loaded", %{conn: conn} do
    expect(StandardSite, :get_public_document, fn
      @did, @rkey -> {:error, {:http_status, 404}}
    end)

    conn = get(conn, ~p"/p/#{@did}/#{@rkey}")
    assert response(conn, 404)
  end
end
