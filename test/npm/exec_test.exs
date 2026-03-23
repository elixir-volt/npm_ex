defmodule NPM.ExecTest do
  use ExUnit.Case, async: true

  describe "which" do
    @tag :tmp_dir
    test "finds binary in .bin directory", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      bin_dir = Path.join(nm, ".bin")
      File.mkdir_p!(bin_dir)
      File.write!(Path.join(bin_dir, "tsc"), "#!/bin/sh")

      assert {:ok, path} = NPM.Exec.which("tsc", nm)
      assert String.ends_with?(path, ".bin/tsc")
    end

    @tag :tmp_dir
    test "finds binary from package bin field", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      pkg = Path.join(nm, "typescript")
      File.mkdir_p!(pkg)
      File.write!(Path.join(pkg, "package.json"), ~s({"name":"typescript","bin":"./bin/tsc"}))

      assert {:ok, _} = NPM.Exec.which("typescript", nm)
    end

    @tag :tmp_dir
    test "returns error for missing command", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      File.mkdir_p!(nm)

      assert {:error, :not_found} = NPM.Exec.which("nonexistent", nm)
    end
  end

  describe "available" do
    @tag :tmp_dir
    test "lists binaries from .bin", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      bin_dir = Path.join(nm, ".bin")
      File.mkdir_p!(bin_dir)
      File.write!(Path.join(bin_dir, "eslint"), "")
      File.write!(Path.join(bin_dir, "tsc"), "")

      bins = NPM.Exec.available(nm)
      assert "eslint" in bins
      assert "tsc" in bins
    end

    @tag :tmp_dir
    test "empty when no .bin and no packages", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      File.mkdir_p!(nm)

      assert [] = NPM.Exec.available(nm)
    end

    test "empty for nonexistent dir" do
      assert [] = NPM.Exec.available("/tmp/nonexistent_#{System.unique_integer([:positive])}")
    end
  end

  describe "available?" do
    @tag :tmp_dir
    test "true when command exists", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      bin_dir = Path.join(nm, ".bin")
      File.mkdir_p!(bin_dir)
      File.write!(Path.join(bin_dir, "jest"), "")

      assert NPM.Exec.available?("jest", nm)
    end

    @tag :tmp_dir
    test "false when command missing", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      File.mkdir_p!(nm)

      refute NPM.Exec.available?("missing", nm)
    end
  end

  describe "package_for" do
    @tag :tmp_dir
    test "finds package by bin map", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      pkg = Path.join(nm, "eslint")
      File.mkdir_p!(pkg)

      File.write!(
        Path.join(pkg, "package.json"),
        ~s({"name":"eslint","bin":{"eslint":"./bin/eslint.js"}})
      )

      assert {:ok, "eslint"} = NPM.Exec.package_for("eslint", nm)
    end

    @tag :tmp_dir
    test "not found for missing command", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      File.mkdir_p!(nm)

      assert {:error, :not_found} = NPM.Exec.package_for("missing", nm)
    end
  end

  describe "env" do
    test "prepends .bin to PATH" do
      env = NPM.Exec.env("node_modules")
      assert {"PATH", path} = Enum.find(env, fn {key, _} -> key == "PATH" end)
      assert String.contains?(path, ".bin")
    end

    test "includes node_modules in NODE_PATH" do
      env = NPM.Exec.env("node_modules")
      assert {"NODE_PATH", path} = Enum.find(env, fn {key, _} -> key == "NODE_PATH" end)
      assert String.contains?(path, Path.expand("node_modules"))
    end

    test "custom node_modules dir" do
      env = NPM.Exec.env("/custom/nm")
      assert {"PATH", path} = Enum.find(env, fn {key, _} -> key == "PATH" end)
      assert String.starts_with?(path, "/custom/nm/.bin:")
    end
  end
end
