defmodule AnnotAt.FeedsTest do
  use ExUnit.Case, async: true

  alias AnnotAt.Feeds
  alias AnnotAt.Feeds.Feed

  @fixture "../support/fixtures/feeds/rss_sample.xml"
           |> Path.expand(__DIR__)
           |> File.read!()

  describe "Feeds.parse/2" do
    test "detects and dispatches RSS" do
      assert {:ok, %Feed{title: "Sample Blog"}} = Feeds.parse(@fixture, "application/rss+xml")
    end

    test "rejects an unrecognized body" do
      assert {:error, :unrecognized_feed} = Feeds.parse("not a feed at all", nil)
    end
  end

  describe "Feeds.discover/2" do
    test "returns all declared feeds, resolved and labeled" do
      html = ~s"""
      <html><head>
        <link rel="alternate" type="application/rss+xml" title="Main"
      href="/feed.xml">
        <link rel="alternate" type="application/atom+xml"
      href="https://blog.example.com/atom">
        <link rel="alternate" type="application/feed+json" title="JSON"
      href="/feed.json">
      </head></html>
      """

      assert [main, atom, json] = Feeds.discover(html, "https://blog.example.com")

      assert %Feeds.Source{url: "https://blog.example.com/feed.xml", title: "Main", format: :rss} =
               main

      assert %Feeds.Source{url: "https://blog.example.com/atom", title: nil, format: :atom} = atom
      assert %Feeds.Source{format: :json, title: "JSON"} = json
    end

    test "ignores non-feed alternates and dedupes by url" do
      html = ~s"""
      <html><head>
        <link rel="alternate" hreflang="fr" type="text/html" href="/fr">
        <link rel="alternate" type="application/rss+xml" href="/feed.xml">
        <link rel="alternate" type="application/rss+xml" href="/feed.xml">
      </head></html>
      """

      assert [%Feeds.Source{url: "https://example.com/feed.xml"}] =
               Feeds.discover(html, "https://example.com")
    end

    test "returns [] when no feed is declared" do
      assert [] ==
               Feeds.discover(
                 "<html><head></head></html>",
                 "https://example.com"
               )
    end

    test "skips feed links without an href" do
      html = ~s(<html><head><link rel="alternate"
type="application/rss+xml"></head></html>)
      assert [] == Feeds.discover(html, "https://example.com")
    end
  end

  describe "Feeds.metadata1/" do
    test "extracts title and description" do
      html = ~s(<html><head><title>My Blog</title><meta name="description"
   content="Thoughts."></head></html>)

      assert %{title: "My Blog", description: "Thoughts."} =
               Feeds.metadata(html)
    end

    test "falls back to og tags, nils when absent" do
      html = ~s(<html><head><meta property="og:title" content="OG
   Title"></head></html>)
      assert %{title: "OG\n   Title", description: nil} = Feeds.metadata(html)
    end
  end
end
