defmodule AnnotAt.URLTest do
  use ExUnit.Case, async: true

  alias AnnotAt.URL

  describe "canonical/1" do
    test "defaults scheme, downcases host, strips trailing slash" do
      assert "https://example.com" == URL.canonical("example.com")
      assert "https://example.com" == URL.canonical("https://EXAMPLE.com/")

      assert "https://example.com/blog" == URL.canonical("https://example.com/blog")
    end
  end
end
