defmodule NPM.PruneTest do
  use ExUnit.Case, async: true

  describe "find_extraneous" do
    @tag :tmp_dir
    test "finds packages not in lockfile", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      pkg_a = Path.join(nm, "pkg-a")
      pkg_b = Path.join(nm, "pkg-b")
      File.mkdir_p!(pkg_a)
      File.mkdir_p!(pkg_b)
      File.write!(Path.join(pkg_a, "package.json"), ~s({"name":"pkg-a","version":"1.0.0"}))
      File.write!(Path.join(pkg_b, "package.json"), ~s({"name":"pkg-b","version":"2.0.0"}))

      lockfile = %{"pkg-a" => %{version: "1.0.0"}}
      extraneous = NPM.Prune.find_extraneous(nm, lockfile)
      assert length(extraneous) == 1
      assert hd(extraneous).name == "pkg-b"
      assert hd(extraneous).reason == :not_in_lockfile
    end

    @tag :tmp_dir
    test "no extraneous when all in lockfile", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      File.mkdir_p!(Path.join(nm, "kept"))
      File.write!(Path.join([nm, "kept", "package.json"]), ~s({"name":"kept","version":"1.0.0"}))

      lockfile = %{"kept" => %{version: "1.0.0"}}
      assert [] = NPM.Prune.find_extraneous(nm, lockfile)
    end

    @tag :tmp_dir
    test "handles scoped packages", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      scoped = Path.join([nm, "@scope", "pkg"])
      File.mkdir_p!(scoped)
      File.write!(Path.join(scoped, "package.json"), ~s({"name":"@scope/pkg","version":"1.0.0"}))

      lockfile = %{}
      extraneous = NPM.Prune.find_extraneous(nm, lockfile)
      assert length(extraneous) == 1
      assert hd(extraneous).name == "@scope/pkg"
    end

    @tag :tmp_dir
    test "keeps scoped packages in lockfile", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      scoped = Path.join([nm, "@babel", "core"])
      File.mkdir_p!(scoped)
      File.write!(Path.join(scoped, "package.json"), ~s({"name":"@babel/core","version":"7.0.0"}))

      lockfile = %{"@babel/core" => %{version: "7.0.0"}}
      assert [] = NPM.Prune.find_extraneous(nm, lockfile)
    end

    test "nonexistent directory returns empty" do
      assert [] =
               NPM.Prune.find_extraneous(
                 "/tmp/nonexistent_#{System.unique_integer([:positive])}",
                 %{}
               )
    end
  end

  describe "prune!" do
    @tag :tmp_dir
    test "removes extraneous packages", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      keep = Path.join(nm, "keep")
      remove = Path.join(nm, "remove")
      File.mkdir_p!(keep)
      File.mkdir_p!(remove)
      File.write!(Path.join(keep, "package.json"), ~s({"name":"keep","version":"1.0.0"}))
      File.write!(Path.join(remove, "package.json"), ~s({"name":"remove","version":"1.0.0"}))
      File.write!(Path.join(remove, "index.js"), "module.exports = {}")

      lockfile = %{"keep" => %{version: "1.0.0"}}
      removed = NPM.Prune.prune!(nm, lockfile)

      assert length(removed) == 1
      assert hd(removed).name == "remove"
      refute File.exists?(remove)
      assert File.exists?(keep)
    end
  end

  describe "dry_run" do
    @tag :tmp_dir
    test "returns what would be removed", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      File.mkdir_p!(Path.join(nm, "extra1"))
      File.mkdir_p!(Path.join(nm, "extra2"))

      File.write!(
        Path.join([nm, "extra1", "package.json"]),
        ~s({"name":"extra1","version":"1.0.0"})
      )

      File.write!(
        Path.join([nm, "extra2", "package.json"]),
        ~s({"name":"extra2","version":"2.0.0"})
      )

      result = NPM.Prune.dry_run(nm, %{})
      assert result.count == 2
      assert length(result.to_remove) == 2

      # Verify nothing was actually removed
      assert File.exists?(Path.join(nm, "extra1"))
      assert File.exists?(Path.join(nm, "extra2"))
    end
  end

  describe "extraneous_size" do
    @tag :tmp_dir
    test "calculates total size", %{tmp_dir: dir} do
      pkg_dir = Path.join(dir, "my-pkg")
      File.mkdir_p!(pkg_dir)
      File.write!(Path.join(pkg_dir, "index.js"), String.duplicate("x", 1000))

      entries = [%{name: "my-pkg", version: "1.0.0", path: pkg_dir, reason: :not_in_lockfile}]
      size = NPM.Prune.extraneous_size(entries)
      assert size >= 1000
    end

    test "empty entries return 0" do
      assert 0 = NPM.Prune.extraneous_size([])
    end
  end
end
