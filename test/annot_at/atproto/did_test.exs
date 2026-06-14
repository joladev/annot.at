defmodule AnnotAt.Atproto.DIDTest do
  use ExUnit.Case, async: true

  alias AnnotAt.Atproto.DID

  describe "valid?/1" do
    test "accepts well-formed plc and web DIDs" do
      for did <- [
            "did:plc:ewvi7nxzyoun6zhxrhs64oiz",
            "did:web:example.com",
            "did:web:pds.example.com",
            "did:web:localhost"
          ] do
        assert DID.valid?(did), "expected #{did} to be valid"
      end
    end

    test "rejects malformed DID syntax" do
      for did <- [
            "notadid",
            "did:",
            "did:plc:",
            "did:plc:abc:",
            "DID:plc:x",
            "did:PLC:x"
          ] do
        refute DID.valid?(did), "expected #{did} to be invalid"
      end
    end

    test "rejects did:web identifiers that are not bare hostnames" do
      for did <- [
            "did:web:.pds.example.com",
            "did:web:example.com.",
            "did:web:example.com:8080",
            "did:web:localhost%3A3000",
            "did:web:ex_ample.com"
          ] do
        refute DID.valid?(did), "expected #{did} to be invalid"
      end
    end

    test "rejects DIDs longer than 2048 characters" do
      long = "did:web:" <> String.duplicate("a", 2048) <> ".com"
      assert byte_size(long) > 2048
      refute DID.valid?(long)
    end
  end
end
