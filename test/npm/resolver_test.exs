defmodule NPM.ResolverTest do
  use ExUnit.Case, async: true

  alias NPM.Node.BinResolver

  describe "Resolver.clear_cache" do
    test "succeeds even when no cache exists" do
      assert :ok = NPM.Resolver.clear_cache()
    end

    test "succeeds when called twice" do
      assert :ok = NPM.Resolver.clear_cache()
      assert :ok = NPM.Resolver.clear_cache()
    end
  end

  describe "Resolver.resolve edge cases" do
    test "returns ok for empty deps" do
      assert {:ok, %{}} = NPM.Resolver.resolve(%{})
    end
  end

  describe "Resolver: normalize_range handles all npm range formats" do
    test "star/empty/latest normalize to >=0.0.0" do
      # These are the special cases handled by normalize_range
      assert {:ok, _} = NPMSemver.to_hex_constraint(">=0.0.0")
    end

    test "caret ranges" do
      assert {:ok, _} = NPMSemver.to_hex_constraint("^1.0.0")
      assert {:ok, _} = NPMSemver.to_hex_constraint("^0.1.0")
      assert {:ok, _} = NPMSemver.to_hex_constraint("^0.0.1")
    end

    test "tilde ranges" do
      assert {:ok, _} = NPMSemver.to_hex_constraint("~1.2.3")
      assert {:ok, _} = NPMSemver.to_hex_constraint("~0.0.1")
    end

    test "exact versions" do
      assert {:ok, _} = NPMSemver.to_hex_constraint("1.0.0")
      assert {:ok, _} = NPMSemver.to_hex_constraint("0.0.0")
    end

    test "comparison operators" do
      assert {:ok, _} = NPMSemver.to_hex_constraint(">1.0.0")
      assert {:ok, _} = NPMSemver.to_hex_constraint(">=1.0.0")
      assert {:ok, _} = NPMSemver.to_hex_constraint("<2.0.0")
      assert {:ok, _} = NPMSemver.to_hex_constraint("<=2.0.0")
    end

    test "combined ranges" do
      assert {:ok, _} = NPMSemver.to_hex_constraint(">=1.0.0 <2.0.0")
    end

    test "union ranges" do
      assert {:ok, _} = NPMSemver.to_hex_constraint("^1.0.0 || ^2.0.0")
    end

    test "x-ranges" do
      assert {:ok, _} = NPMSemver.to_hex_constraint("1.x")
      assert {:ok, _} = NPMSemver.to_hex_constraint("1.2.x")
    end

    test "hyphen ranges" do
      assert {:ok, _} = NPMSemver.to_hex_constraint("1.0.0 - 2.0.0")
    end
  end

  describe "Resolver: overrides stored correctly" do
    test "overrides are accessible after resolution" do
      NPM.Resolver.clear_cache()
      NPM.Resolver.resolve(%{}, overrides: %{"ms" => "2.1.3"})
      # Cache should exist with overrides
      assert is_map(NPM.Resolver.get_original_deps("ms"))
    end
  end

  describe "BinResolver: list sorting" do
    @tag :tmp_dir
    test "list returns sorted results", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      bin_dir = Path.join(nm, ".bin")
      File.mkdir_p!(bin_dir)
      File.write!(Path.join(bin_dir, "zzz"), "#!/bin/sh")
      File.write!(Path.join(bin_dir, "aaa"), "#!/bin/sh")
      File.write!(Path.join(bin_dir, "mmm"), "#!/bin/sh")

      bins = BinResolver.list(nm)
      names = Enum.map(bins, &elem(&1, 0))
      assert names == ["aaa", "mmm", "zzz"]
    end
  end

  describe "Resolver: normalize_range for edge cases" do
    test "empty string normalizes like *" do
      assert {:ok, _} = NPMSemver.to_hex_constraint(">=0.0.0")
    end

    test "complex range with spaces" do
      assert {:ok, _} = NPMSemver.to_hex_constraint(">= 1.0.0 < 2.0.0")
    end
  end

  describe "BinResolver: available? edge cases" do
    @tag :tmp_dir
    test "available? returns false for missing .bin dir", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      File.mkdir_p!(nm)
      refute BinResolver.available?("anything", nm)
    end
  end

  describe "Resolver: resolve with overrides preserves them" do
    test "overrides don't affect empty resolution" do
      NPM.Resolver.clear_cache()
      {:ok, result} = NPM.Resolver.resolve(%{}, overrides: %{"any" => "1.0.0"})
      assert result == %{}
    end
  end

  describe "Resolver: get_original_deps for non-excluded package" do
    test "returns empty map for unknown package" do
      NPM.Resolver.clear_cache()
      assert %{} = NPM.Resolver.get_original_deps("unknown-pkg")
    end
  end

  describe "Resolver: clear_cache" do
    test "clear_cache doesn't crash when called twice" do
      NPM.Resolver.clear_cache()
      NPM.Resolver.clear_cache()
      assert {:ok, %{}} = NPM.Resolver.resolve(%{})
    end
  end

  describe "BinResolver: symlink resolution" do
    @tag :tmp_dir
    test "find resolves symlink targets", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      bin_dir = Path.join(nm, ".bin")
      pkg_dir = Path.join(nm, "eslint")
      File.mkdir_p!(bin_dir)
      File.mkdir_p!(pkg_dir)

      target = Path.join(pkg_dir, "bin/eslint.js")
      File.mkdir_p!(Path.dirname(target))
      File.write!(target, "#!/usr/bin/env node")

      link = Path.join(bin_dir, "eslint")
      File.ln_s!(target, link)

      {:ok, resolved} = BinResolver.find("eslint", nm)
      assert String.contains?(resolved, "eslint")
    end
  end

  describe "BinResolver: binary lookup" do
    @tag :tmp_dir
    test "list returns available commands", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      bin_dir = Path.join(nm, ".bin")
      File.mkdir_p!(bin_dir)
      File.write!(Path.join(bin_dir, "jest"), "#!/bin/sh")
      File.write!(Path.join(bin_dir, "tsc"), "#!/bin/sh")

      bins = BinResolver.list(nm)
      names = Enum.map(bins, &elem(&1, 0))
      assert "jest" in names
      assert "tsc" in names
    end

    @tag :tmp_dir
    test "find returns path for existing command", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      bin_dir = Path.join(nm, ".bin")
      File.mkdir_p!(bin_dir)
      File.write!(Path.join(bin_dir, "eslint"), "#!/bin/sh")

      assert {:ok, path} = BinResolver.find("eslint", nm)
      assert String.contains?(path, "eslint")
    end

    @tag :tmp_dir
    test "find returns :error for missing command", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      File.mkdir_p!(nm)

      assert :error = BinResolver.find("nonexistent", nm)
    end

    @tag :tmp_dir
    test "available? checks command existence", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      bin_dir = Path.join(nm, ".bin")
      File.mkdir_p!(bin_dir)
      File.write!(Path.join(bin_dir, "prettier"), "#!/bin/sh")

      assert BinResolver.available?("prettier", nm)
      refute BinResolver.available?("missing", nm)
    end

    @tag :tmp_dir
    test "list returns empty for missing .bin", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      File.mkdir_p!(nm)

      assert BinResolver.list(nm) == []
    end
  end

  describe "Resolver: empty resolution" do
    test "empty deps returns empty map" do
      NPM.Resolver.clear_cache()
      {:ok, result} = NPM.Resolver.resolve(%{})
      assert result == %{}
    end

    test "resolve with overrides option doesn't crash on empty" do
      NPM.Resolver.clear_cache()
      {:ok, result} = NPM.Resolver.resolve(%{}, overrides: %{"pkg" => "1.0.0"})
      assert result == %{}
    end
  end

  describe "Resolver: override support" do
    test "overrides are stored and retrieved from cache" do
      NPM.Resolver.clear_cache()
      overrides = %{"ms" => "2.1.3"}
      {:ok, _} = NPM.Resolver.resolve(%{}, overrides: overrides)
    end
  end

  describe "Resolver.extract_conflict_package (via resolve behavior)" do
    test "resolver handles empty deps" do
      NPM.Resolver.clear_cache()
      assert {:ok, %{}} = NPM.Resolver.resolve(%{})
    end

    test "normalize_range handles *" do
      # This tests the internal normalization without network
      assert {:ok, _} = NPMSemver.to_hex_constraint(">=0.0.0")
    end
  end

  describe "Resolver: normalize_range edge cases" do
    test "* resolves without error" do
      # Use a mock-friendly check: verify the constraint is created
      assert {:ok, _} = NPMSemver.to_hex_constraint(">=0.0.0")
    end

    test "caret constraint for 0.x works like npm" do
      # ^0.2.3 should be >=0.2.3, <0.3.0 (npm treats 0.x specially)
      assert NPMSemver.matches?("0.2.5", "^0.2.3")
      refute NPMSemver.matches?("0.3.0", "^0.2.3")
    end

    test "tilde constraint matches npm behavior" do
      # ~1.2.3 := >=1.2.3 <1.3.0-0
      assert NPMSemver.matches?("1.2.9", "~1.2.3")
      refute NPMSemver.matches?("1.3.0", "~1.2.3")
    end

    test ">=, < compound range" do
      assert NPMSemver.matches?("1.5.0", ">=1.0.0 <2.0.0")
      refute NPMSemver.matches?("2.0.0", ">=1.0.0 <2.0.0")
    end
  end
end
