defmodule NPM.Registry.MirrorTest do
  use ExUnit.Case, async: true

  alias NPM.Registry.Mirror

  describe "RegistryMirror.known_mirrors" do
    test "returns known mirrors" do
      mirrors = Mirror.known_mirrors()
      assert Map.has_key?(mirrors, "china")
      assert Map.has_key?(mirrors, "yarn")
      assert Map.has_key?(mirrors, "npmjs")
    end
  end

  describe "RegistryMirror.get_mirror" do
    test "gets a known mirror" do
      assert "https://registry.npmmirror.com" = Mirror.get_mirror("china")
    end

    test "returns nil for unknown mirror" do
      assert nil == Mirror.get_mirror("nonexistent")
    end
  end

  describe "RegistryMirror.known_mirror?" do
    test "detects known mirror URL" do
      assert Mirror.known_mirror?("https://registry.npmjs.org")
    end

    test "rejects unknown URL" do
      refute Mirror.known_mirror?("https://custom.example.com")
    end
  end

  describe "RegistryMirror.rewrite_tarball_url" do
    test "rewrites tarball URL to mirror" do
      original = "https://registry.npmjs.org/lodash/-/lodash-4.17.21.tgz"
      mirror = "https://registry.npmmirror.com"

      result = Mirror.rewrite_tarball_url(original, mirror)
      assert String.starts_with?(result, "https://registry.npmmirror.com")
      assert String.contains?(result, "lodash")
    end
  end

  describe "RegistryMirror.mirror_url" do
    test "returns a URL" do
      url = Mirror.mirror_url()
      assert is_binary(url)
      assert String.starts_with?(url, "http")
    end
  end

  describe "RegistryMirror: URL rewriting" do
    test "known_mirrors returns map of mirror names to URLs" do
      mirrors = Mirror.known_mirrors()
      assert is_map(mirrors)
      assert Map.has_key?(mirrors, "npmjs")
      assert mirrors["npmjs"] == "https://registry.npmjs.org"
    end

    test "rewrite_tarball_url replaces registry host" do
      mirror = "https://registry.npmmirror.com"

      rewritten =
        Mirror.rewrite_tarball_url(
          "https://registry.npmjs.org/lodash/-/lodash-4.17.21.tgz",
          mirror
        )

      assert String.starts_with?(rewritten, mirror)
      assert String.contains?(rewritten, "lodash")
    end

    test "known_mirror? checks if URL is a known mirror" do
      assert Mirror.known_mirror?("https://registry.npmmirror.com")
    end
  end

  describe "RegistryMirror: mirror_url" do
    test "mirror_url returns configured or default" do
      url = Mirror.mirror_url()
      assert is_binary(url)
      assert String.starts_with?(url, "https://")
    end
  end

  describe "RegistryMirror: get_mirror" do
    test "get_mirror by name returns URL" do
      url = Mirror.get_mirror("china")
      assert url == "https://registry.npmmirror.com"
    end

    test "get_mirror returns nil for unknown" do
      assert nil == Mirror.get_mirror("nonexistent")
    end
  end
end
