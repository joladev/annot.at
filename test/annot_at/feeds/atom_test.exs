defmodule AnnotAt.Feeds.AtomTest do
  use ExUnit.Case, async: true

  alias AnnotAt.Feeds.Atom
  alias AnnotAt.Feeds.Entry
  alias AnnotAt.Feeds.Feed

  @fixture "../../support/fixtures/feeds/atom_sample.xml"
           |> Path.expand(__DIR__)
           |> File.read!()

  test "parses feed-level metadata" do
    assert {:ok, %Feed{} = feed} = Atom.parse(@fixture)
    assert "Sample Blog" == feed.title
    assert "https://example.com" == feed.url
    assert "Thoughts about things." == feed.description
  end

  test "parses entries with all fields" do
    assert {:ok, %{entries: [first, _second]}} = Atom.parse(@fixture)

    assert %Entry{} = first
    assert "First Post" == first.title
    assert "https://example.com/posts/first" == first.url
    assert "abc" == first.id
    assert "A short summary of the first post." == first.summary
    assert "<p>The full <strong>content</strong>\n    of the first post.</p>" == first.content
    assert %DateTime{} = first.published_at
    assert ~U[2024-10-02 13:00:00Z] == first.published_at
    assert ["category-1", "category-2"] = first.categories
  end

  test "falls back to URL as ID when id is missing" do
    assert {:ok, %{entries: [_first, second]}} = Atom.parse(@fixture)
    assert second.id == second.url
  end

  test "prefers published over updated for published_at" do
    assert {:ok, %{entries: [first, _second]}} = Atom.parse(@fixture)
    assert ~U[2024-10-02 13:00:00Z] == first.published_at
  end

  test "leaves published_at nil when published and updated are missing" do
    assert {:ok, %{entries: [_first, second]}} = Atom.parse(@fixture)
    refute second.published_at
  end

  test "leaves content nil when missing" do
    assert {:ok, %{entries: [_first, second]}} = Atom.parse(@fixture)
    refute second.content
  end

  test "uses the alternate link, not self" do
    assert {:ok, %Feed{url: "https://example.com"}} = Atom.parse(@fixture)
  end

  test "returns an error on malformed" do
    assert {:error, :invalid_feed} = Atom.parse("<feed><title>oops")
  end

  test "accepts a valid but empty feed" do
    body = """
    <?xml version="1.0" encoding="utf-8"?>
    <feed xmlns="http://www.w3.org/2005/Atom">
      <title>Brand New Blog</title>
      <link rel="alternate" href="https://example.com"/>
      <subtitle>Nothing here yet.</subtitle>
    </feed>
    """

    assert {:ok, %Feed{title: "Brand New Blog", entries: []}} = Atom.parse(body)
  end

  test "rejects a feed with no title as invalid" do
    body = """
    <?xml version="1.0" encoding="utf-8"?>
    <feed xmlns="http://www.w3.org/2005/Atom">
      <link rel="alternate" href="https://example.com"/>
      <subtitle>No title here.</subtitle>
    </feed>
    """

    assert {:error, :invalid_feed} = Atom.parse(body)
  end
end
