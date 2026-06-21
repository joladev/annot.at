defmodule AnnotAt.Atproto.TIDTest do
  use ExUnit.Case, async: true

  alias AnnotAt.Atproto.TID

  @tid_regex ~r/^[234567abcdefghij][234567abcdefghijklmnopqrstuvwxyz]{12}$/

  test "encode/1 of zero is the spec's zero-value TID" do
    assert "2222222222222" == TID.new(0)
  end

  test "now/0 produces a syntactically valid TID" do
    tid = TID.now()
    assert String.length(tid) == 13
    assert tid =~ @tid_regex
  end
end
