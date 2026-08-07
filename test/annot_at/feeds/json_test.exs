defmodule AnnotAt.Feeds.JSONTest do
  use ExUnit.Case, async: true

  alias AnnotAt.Feeds.Entry
  alias AnnotAt.Feeds.Feed
  alias AnnotAt.Feeds.JSON

  @fixture "../../support/fixtures/feeds/json_sample.json"
           |> Path.expand(__DIR__)
           |> File.read!()

  describe "parse/1" do
    test "parses sample" do
      assert {:ok, %Feed{} = feed} = JSON.parse(@fixture)

      assert feed.title == "example.com"
      assert feed.url == "https://example.com/"
      assert feed.description == "Thoughts about things."

      assert [%Entry{} = first, %Entry{} = second] = feed.entries

      assert first.title == "Blog post"
      assert first.url == "https://example.com/blog-post/"
      assert first.id == "https://example.com/blog-post/"
      assert first.summary == nil
      assert first.content == "Lorem ipsum dolor sit amet."
      assert first.published_at == ~U[2026-08-04 00:00:00Z]
      assert ["category-1", "category-2"] = first.categories
      assert first.updated_at == nil
      assert first.image == "https://example.com/images/image.png"

      assert second.title == "More content"
      assert second.url == "https://example.com/more-content/"
      assert second.id == "https://example.com/more-content/"
      assert second.summary == "summary"
      assert second.content == "<p>preferred</p>"
      assert second.published_at == ~U[2026-07-31 00:00:00Z]
      assert [] = second.categories
      assert second.updated_at == ~U[2026-07-31 00:00:00Z]
      assert second.image == nil
    end
  end
end
