defmodule NPM.BinTest do
  use ExUnit.Case, async: true

  describe "extract" do
    test "string shorthand with name" do
      data = %{"name" => "typescript", "bin" => "./bin/tsc"}
      assert %{"typescript" => "./bin/tsc"} = NPM.Bin.extract(data)
    end

    test "map format" do
      data = %{"bin" => %{"tsc" => "./bin/tsc", "tsserver" => "./bin/tsserver"}}
      bins = NPM.Bin.extract(data)
      assert bins["tsc"] == "./bin/tsc"
      assert bins["tsserver"] == "./bin/tsserver"
    end

    test "empty when no bin" do
      assert %{} = NPM.Bin.extract(%{"name" => "lodash"})
    end

    test "directories.bin fallback" do
      data = %{"directories" => %{"bin" => "./bin"}}
      assert NPM.Bin.extract(data) == %{"__dir__" => "./bin"}
    end
  end

  describe "commands" do
    test "lists command names" do
      data = %{"bin" => %{"eslint" => "./bin/eslint.js", "eslint-config" => "./bin/config.js"}}
      cmds = NPM.Bin.commands(data)
      assert "eslint" in cmds
      assert "eslint-config" in cmds
    end

    test "empty for no bin" do
      assert [] = NPM.Bin.commands(%{})
    end
  end

  describe "has_bin?" do
    test "true with bin field" do
      assert NPM.Bin.has_bin?(%{"bin" => %{"cmd" => "./script.js"}})
    end

    test "false without bin" do
      refute NPM.Bin.has_bin?(%{"name" => "pkg"})
    end
  end

  describe "resolve" do
    test "finds script for command" do
      data = %{"bin" => %{"jest" => "./bin/jest.js"}}
      assert "./bin/jest.js" = NPM.Bin.resolve("jest", data)
    end

    test "nil for unknown command" do
      data = %{"bin" => %{"jest" => "./bin/jest.js"}}
      assert nil == NPM.Bin.resolve("mocha", data)
    end
  end

  describe "count" do
    test "counts binaries" do
      data = %{"bin" => %{"a" => "./a", "b" => "./b"}}
      assert 2 = NPM.Bin.count(data)
    end

    test "zero for no bin" do
      assert 0 = NPM.Bin.count(%{})
    end
  end

  describe "all_bins" do
    @tag :tmp_dir
    test "collects bins from node_modules", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      pkg = Path.join(nm, "eslint")
      File.mkdir_p!(pkg)

      File.write!(
        Path.join(pkg, "package.json"),
        ~s({"name":"eslint","bin":{"eslint":"./bin/eslint.js"}})
      )

      bins = NPM.Bin.all_bins(nm)
      assert Map.has_key?(bins, "eslint")
    end

    test "empty for nonexistent dir" do
      assert %{} = NPM.Bin.all_bins("/tmp/nonexistent_#{System.unique_integer([:positive])}")
    end
  end
end
