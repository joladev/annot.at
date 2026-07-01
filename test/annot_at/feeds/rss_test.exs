defmodule AnnotAt.Feeds.RSSTest do
  use ExUnit.Case, async: true

  alias AnnotAt.Feeds.Entry
  alias AnnotAt.Feeds.Feed
  alias AnnotAt.Feeds.RSS

  @fixture "../../support/fixtures/feeds/rss_sample.xml"
           |> Path.expand(__DIR__)
           |> File.read!()

  test "parses channel-level feed metadata" do
    assert {:ok, %Feed{} = feed} = RSS.parse(@fixture)
    assert "Sample Blog" == feed.title
    assert "https://example.com" == feed.url
    assert "Thoughts about things." == feed.description
  end

  test "parses entries with all fields" do
    assert {:ok, %{entries: [first, _second]}} = RSS.parse(@fixture)

    assert %Entry{} = first
    assert "First Post" == first.title
    assert "https://example.com/posts/first" == first.url
    assert "abc" == first.id
    assert "A short summary of the first post." == first.summary
    assert "<p>The full <strong>content</strong> of the first post.</p>" == first.content
    assert %DateTime{} = first.published_at
    assert ~U[2024-10-02 13:00:00Z] == first.published_at
    assert ["category-1", "category-2"] = first.categories
  end

  test "falls back to URL as ID when guid is missing" do
    assert {:ok, %{entries: [_first, second]}} = RSS.parse(@fixture)
    assert second.id == second.url
  end

  test "leaves published_at nil when pubDate is missing" do
    assert {:ok, %{entries: [_first, second]}} = RSS.parse(@fixture)
    refute second.published_at
  end

  test "leaves content nil when missing" do
    assert {:ok, %{entries: [_first, second]}} = RSS.parse(@fixture)
    refute second.content
  end

  test "returns an error on malformed" do
    assert {:error, :invalid_feed} = RSS.parse("<rss><channel><title>oops")
  end

  test "accepts a valid but empty blog" do
    body = """
    <?xml version="1.0" encoding="UTF-8"?>
    <rss version="2.0">
      <channel>
        <title>Brand New Blog</title>
        <link>https://example.com</link>
        <description>Nothing here yet.</description>
      </channel>
    </rss>
    """

    assert {:ok, %Feed{title: "Brand New Blog", entries: []}} = RSS.parse(body)
  end

  test "rejects a feed with no channel title as invalid" do
    body = """
    <?xml version="1.0" encoding="UTF-8"?>
    <rss version="2.0">
      <channel>
        <link>https://example.com</link>
        <description>No title here.</description>
      </channel>
    </rss>
    """

    assert {:error, :invalid_feed} = RSS.parse(body)
  end
end
