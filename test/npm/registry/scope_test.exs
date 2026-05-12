defmodule NPM.Registry.ScopeTest do
  use ExUnit.Case, async: true

  describe "ScopeRegistry.scoped?" do
    test "scoped package" do
      assert NPM.Registry.Scope.scoped?("@babel/core")
    end

    test "unscoped package" do
      refute NPM.Registry.Scope.scoped?("lodash")
    end
  end

  describe "ScopeRegistry.scope" do
    test "extracts scope" do
      assert "@babel" = NPM.Registry.Scope.scope("@babel/core")
    end

    test "returns nil for unscoped" do
      assert nil == NPM.Registry.Scope.scope("lodash")
    end

    test "handles double-nested scope" do
      assert "@my-org" = NPM.Registry.Scope.scope("@my-org/my-package")
    end
  end

  describe "ScopeRegistry.registry_for" do
    test "unscoped returns default" do
      url = NPM.Registry.Scope.registry_for("lodash")
      assert is_binary(url)
      assert String.contains?(url, "registry")
    end

    test "scoped without config returns default" do
      url = NPM.Registry.Scope.registry_for("@nonexistent-scope-xyz/pkg")
      assert url == NPM.Registry.registry_url()
    end
  end

  describe "ScopeRegistry.all_scopes" do
    test "returns map" do
      result = NPM.Registry.Scope.all_scopes()
      assert is_map(result)
    end
  end

  describe "ScopeRegistry: per-scope registry routing" do
    test "default registry for unscoped packages" do
      assert NPM.Registry.Scope.registry_for("lodash") == "https://registry.npmjs.org"
    end

    test "scoped? detects scoped packages" do
      assert NPM.Registry.Scope.scoped?("@myco/utils")
      refute NPM.Registry.Scope.scoped?("lodash")
    end

    test "scope extracts scope from scoped package" do
      assert "@myco" = NPM.Registry.Scope.scope("@myco/utils")
    end

    test "scope returns nil for unscoped" do
      assert nil == NPM.Registry.Scope.scope("lodash")
    end
  end

  describe "ScopeRegistry: registry_for returns default" do
    test "unscoped package uses default registry" do
      url = NPM.Registry.Scope.registry_for("lodash")
      assert url == "https://registry.npmjs.org"
    end
  end

  describe "ScopeRegistry: all_scopes" do
    test "returns empty map with no config" do
      scopes = NPM.Registry.Scope.all_scopes()
      assert is_map(scopes)
    end
  end

  describe "ScopeRegistry: scope extraction" do
    test "scoped? detects scoped packages" do
      assert NPM.Registry.Scope.scoped?("@types/node")
      assert NPM.Registry.Scope.scoped?("@babel/core")
      refute NPM.Registry.Scope.scoped?("lodash")
    end

    test "scope extracts scope from name" do
      assert "@types" = NPM.Registry.Scope.scope("@types/node")
      assert "@babel" = NPM.Registry.Scope.scope("@babel/core")
    end
  end
end
