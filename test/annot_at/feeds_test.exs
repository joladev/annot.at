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
    test "finds and resolves a relative feed url" do
      html = """
      <html>
        <head>
          <link rel="alternate" type="application/rss+xml" href="/feed.xml">
        </head>
      </html>
      """

      assert {:ok, "https://blog.example.com/feed.xml"} =
               Feeds.discover(
                 html,
                 "https://blog.example.com"
               )
    end

    test "returns :error when there's no feed link" do
      html = """
      <html>
        <head>
        </head>
      </html>
      """

      assert :error = Feeds.discover(html, "https://blog.example.com")
    end
  end
end
