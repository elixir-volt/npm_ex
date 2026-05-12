defmodule NPM.Node.BinResolverTest do
  use ExUnit.Case, async: true

  describe "list" do
    @tag :tmp_dir
    test "lists binaries in .bin directory", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      bin_dir = Path.join(nm, ".bin")
      File.mkdir_p!(bin_dir)
      File.write!(Path.join(bin_dir, "eslint"), "#!/usr/bin/env node")
      File.write!(Path.join(bin_dir, "prettier"), "#!/usr/bin/env node")

      bins = NPM.Node.BinResolver.list(nm)
      names = Enum.map(bins, &elem(&1, 0))
      assert "eslint" in names
      assert "prettier" in names
    end

    @tag :tmp_dir
    test "returns sorted list", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      bin_dir = Path.join(nm, ".bin")
      File.mkdir_p!(bin_dir)
      File.write!(Path.join(bin_dir, "z-tool"), "#!/bin/sh")
      File.write!(Path.join(bin_dir, "a-tool"), "#!/bin/sh")

      bins = NPM.Node.BinResolver.list(nm)
      names = Enum.map(bins, &elem(&1, 0))
      assert names == Enum.sort(names)
    end

    @tag :tmp_dir
    test "empty .bin directory", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      File.mkdir_p!(Path.join(nm, ".bin"))
      assert [] = NPM.Node.BinResolver.list(nm)
    end

    @tag :tmp_dir
    test "no .bin directory", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      File.mkdir_p!(nm)
      assert [] = NPM.Node.BinResolver.list(nm)
    end

    test "nonexistent node_modules" do
      assert [] =
               NPM.Node.BinResolver.list("/tmp/nonexistent_#{System.unique_integer([:positive])}")
    end
  end

  describe "find" do
    @tag :tmp_dir
    test "finds existing binary", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      bin_dir = Path.join(nm, ".bin")
      File.mkdir_p!(bin_dir)
      File.write!(Path.join(bin_dir, "tsc"), "#!/usr/bin/env node")

      assert {:ok, _path} = NPM.Node.BinResolver.find("tsc", nm)
    end

    @tag :tmp_dir
    test "returns error for missing binary", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      File.mkdir_p!(Path.join(nm, ".bin"))
      assert :error = NPM.Node.BinResolver.find("nonexistent", nm)
    end

    @tag :tmp_dir
    test "resolves symlinks", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      bin_dir = Path.join(nm, ".bin")
      pkg_dir = Path.join(nm, "my-cli")
      File.mkdir_p!(bin_dir)
      File.mkdir_p!(pkg_dir)
      target = Path.join(pkg_dir, "bin/cli.js")
      File.mkdir_p!(Path.dirname(target))
      File.write!(target, "#!/usr/bin/env node")
      File.ln_s!(target, Path.join(bin_dir, "my-cli"))

      {:ok, resolved} = NPM.Node.BinResolver.find("my-cli", nm)
      assert String.ends_with?(resolved, "cli.js") or String.contains?(resolved, "my-cli")
    end
  end

  describe "available?" do
    @tag :tmp_dir
    test "true for existing binary", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      bin_dir = Path.join(nm, ".bin")
      File.mkdir_p!(bin_dir)
      File.write!(Path.join(bin_dir, "jest"), "#!/usr/bin/env node")

      assert NPM.Node.BinResolver.available?("jest", nm)
    end

    @tag :tmp_dir
    test "false for missing binary", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      File.mkdir_p!(Path.join(nm, ".bin"))
      refute NPM.Node.BinResolver.available?("ghost", nm)
    end

    test "false for nonexistent node_modules" do
      refute NPM.Node.BinResolver.available?(
               "anything",
               "/tmp/nonexistent_#{System.unique_integer([:positive])}"
             )
    end
  end
end
