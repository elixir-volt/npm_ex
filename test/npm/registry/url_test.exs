defmodule NPM.Registry.URLTest do
  use ExUnit.Case, async: true

  describe "package_url" do
    test "unscoped package" do
      assert "https://registry.npmjs.org/lodash" = NPM.Registry.URL.package_url("lodash")
    end

    test "scoped package" do
      url = NPM.Registry.URL.package_url("@babel/core")
      assert url == "https://registry.npmjs.org/@babel%2fcore"
    end

    test "custom registry" do
      url = NPM.Registry.URL.package_url("lodash", "https://custom.registry.com/")
      assert url == "https://custom.registry.com/lodash"
    end
  end

  describe "version_url" do
    test "includes version" do
      url = NPM.Registry.URL.version_url("lodash", "4.17.21")
      assert url == "https://registry.npmjs.org/lodash/4.17.21"
    end
  end

  describe "tarball_url" do
    test "unscoped tarball" do
      url = NPM.Registry.URL.tarball_url("lodash", "4.17.21")
      assert url == "https://registry.npmjs.org/lodash/-/lodash-4.17.21.tgz"
    end

    test "scoped tarball" do
      url = NPM.Registry.URL.tarball_url("@babel/core", "7.23.0")
      assert url =~ "core-7.23.0.tgz"
    end
  end

  describe "search_url" do
    test "default search" do
      url = NPM.Registry.URL.search_url("react")
      assert url =~ "/-/v1/search?text=react&size=20"
    end

    test "custom size" do
      url = NPM.Registry.URL.search_url("vue", size: 5)
      assert url =~ "size=5"
    end

    test "encodes special characters" do
      url = NPM.Registry.URL.search_url("react hooks")
      assert url =~ "react%20hooks"
    end
  end

  describe "default_registry?" do
    test "true for npmjs" do
      assert NPM.Registry.URL.default_registry?("https://registry.npmjs.org")
    end

    test "true with trailing slash" do
      assert NPM.Registry.URL.default_registry?("https://registry.npmjs.org/")
    end

    test "false for custom" do
      refute NPM.Registry.URL.default_registry?("https://my-registry.com")
    end
  end

  describe "default_registry" do
    test "returns npmjs" do
      assert "https://registry.npmjs.org" = NPM.Registry.URL.default_registry()
    end
  end
end
