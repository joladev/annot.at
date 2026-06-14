defmodule AnnotAt.Atproto.HandleTest do
  use ExUnit.Case, async: true

  alias AnnotAt.Atproto.Handle

  describe "valid?/1" do
    test "accepts well-formed handles" do
      for handle <- [
            "bnewold.bsky.social",
            "8.cn",
            "a.co",
            "xn--notarealidn.com",
            "john.test",
            "atproto.com",
            "low-end.example.com"
          ] do
        assert Handle.valid?(handle), "expected #{handle} to be valid"
      end
    end

    test "rejects malformed handles" do
      for handle <- [
            "jo@hn.test",
            "john..test",
            "xn--bcher-.tld",
            "john.0",
            "cn.8",
            "org",
            "💩.test",
            "-john.test",
            "john-.test"
          ] do
        refute Handle.valid?(handle), "expected #{handle} to be invalid"
      end
    end

    test "rejects handles longer than 253 characters" do
      long = String.duplicate("a.", 130) <> "com"
      assert byte_size(long) > 253
      refute Handle.valid?(long)
    end
  end

  describe "normalize/1" do
    test "trims whitespace, strips a leading @, and downcases" do
      assert Handle.normalize("  @bnewold.BSKY.Social  ") == "bnewold.bsky.social"
    end

    test "leaves an already-clean handle unchanged" do
      assert Handle.normalize("atproto.com") == "atproto.com"
    end
  end
end
