defmodule NPM.Registry.ScopeTest do
  use ExUnit.Case, async: true

  alias NPM.Registry.Scope

  describe "ScopeRegistry.scoped?" do
    test "scoped package" do
      assert Scope.scoped?("@babel/core")
    end

    test "unscoped package" do
      refute Scope.scoped?("lodash")
    end
  end

  describe "ScopeRegistry.scope" do
    test "extracts scope" do
      assert "@babel" = Scope.scope("@babel/core")
    end

    test "returns nil for unscoped" do
      assert nil == Scope.scope("lodash")
    end

    test "handles double-nested scope" do
      assert "@my-org" = Scope.scope("@my-org/my-package")
    end
  end

  describe "ScopeRegistry.registry_for" do
    test "unscoped returns default" do
      url = Scope.registry_for("lodash")
      assert is_binary(url)
      assert String.contains?(url, "registry")
    end

    test "scoped without config returns default" do
      url = Scope.registry_for("@nonexistent-scope-xyz/pkg")
      assert url == NPM.Registry.registry_url()
    end
  end

  describe "ScopeRegistry.all_scopes" do
    test "returns map" do
      result = Scope.all_scopes()
      assert is_map(result)
    end
  end

  describe "ScopeRegistry: per-scope registry routing" do
    test "default registry for unscoped packages" do
      assert Scope.registry_for("lodash") == "https://registry.npmjs.org"
    end

    test "scoped? detects scoped packages" do
      assert Scope.scoped?("@myco/utils")
      refute Scope.scoped?("lodash")
    end

    test "scope extracts scope from scoped package" do
      assert "@myco" = Scope.scope("@myco/utils")
    end

    test "scope returns nil for unscoped" do
      assert nil == Scope.scope("lodash")
    end
  end

  describe "ScopeRegistry: registry_for returns default" do
    test "unscoped package uses default registry" do
      url = Scope.registry_for("lodash")
      assert url == "https://registry.npmjs.org"
    end
  end

  describe "ScopeRegistry: all_scopes" do
    test "returns empty map with no config" do
      scopes = Scope.all_scopes()
      assert is_map(scopes)
    end
  end

  describe "ScopeRegistry: scope extraction" do
    test "scoped? detects scoped packages" do
      assert Scope.scoped?("@types/node")
      assert Scope.scoped?("@babel/core")
      refute Scope.scoped?("lodash")
    end

    test "scope extracts scope from name" do
      assert "@types" = Scope.scope("@types/node")
      assert "@babel" = Scope.scope("@babel/core")
    end
  end
end
