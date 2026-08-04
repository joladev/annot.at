defmodule AnnotAt.Atproto.StandardSite.DocumentTest do
  use ExUnit.Case, async: true

  alias AnnotAt.Atproto.StandardSite.Document

  @did "did:plc:ewvi7nxzyoun6zhxrhs64oiz"
  @uri "at://#{@did}/site.standard.document/3mope7jyypk22"

  test "from_record/2 parses a record" do
    doc =
      Document.from_record(@uri, %{
        "site" => "at://#{@did}/site.standard.publication/abc123",
        "title" => "Hello",
        "publishedAt" => "2026-01-01T10:00:00Z",
        "content" => %{"$type" => "org.wordpress.html", "html" => "<p>hi</p>"}
      })

    assert "3mope7jyypk22" == doc.rkey
    assert ~U[2026-01-01 10:00:00Z] == doc.published_at
    assert {:html, "<p>hi</p>"} = doc.content
  end
end
