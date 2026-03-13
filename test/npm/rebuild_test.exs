defmodule NPM.RebuildTest do
  use ExUnit.Case, async: true

  describe "scan" do
    @tag :tmp_dir
    test "finds packages with binding.gyp", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      pkg = Path.join(nm, "bcrypt")
      File.mkdir_p!(pkg)
      File.write!(Path.join(pkg, "binding.gyp"), "{}")
      File.write!(Path.join(pkg, "package.json"), ~s({"name":"bcrypt"}))

      result = NPM.Rebuild.scan(nm)
      assert Enum.any?(result, &(&1.name == "bcrypt"))
    end

    @tag :tmp_dir
    test "finds packages with install scripts", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      pkg = Path.join(nm, "esbuild")
      File.mkdir_p!(pkg)

      File.write!(
        Path.join(pkg, "package.json"),
        ~s({"name":"esbuild","scripts":{"postinstall":"node install.js"}})
      )

      result = NPM.Rebuild.scan(nm)
      assert Enum.any?(result, &(&1.name == "esbuild"))
    end

    @tag :tmp_dir
    test "ignores non-native packages", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      pkg = Path.join(nm, "lodash")
      File.mkdir_p!(pkg)
      File.write!(Path.join(pkg, "package.json"), ~s({"name":"lodash"}))

      result = NPM.Rebuild.scan(nm)
      refute Enum.any?(result, &(&1.name == "lodash"))
    end

    test "empty for nonexistent dir" do
      assert [] = NPM.Rebuild.scan("/tmp/nonexistent_#{System.unique_integer([:positive])}")
    end

    @tag :tmp_dir
    test "scans scoped packages", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      pkg = Path.join([nm, "@scope", "native"])
      File.mkdir_p!(pkg)
      File.write!(Path.join(pkg, "binding.gyp"), "{}")
      File.write!(Path.join(pkg, "package.json"), ~s({"name":"@scope/native"}))

      result = NPM.Rebuild.scan(nm)
      assert Enum.any?(result, &(&1.name == "@scope/native"))
    end
  end

  describe "native?" do
    @tag :tmp_dir
    test "true for binding.gyp", %{tmp_dir: dir} do
      File.write!(Path.join(dir, "binding.gyp"), "{}")
      assert NPM.Rebuild.native?(dir)
    end

    @tag :tmp_dir
    test "true for CMakeLists.txt", %{tmp_dir: dir} do
      File.write!(Path.join(dir, "CMakeLists.txt"), "")
      assert NPM.Rebuild.native?(dir)
    end

    @tag :tmp_dir
    test "true for install script", %{tmp_dir: dir} do
      File.write!(Path.join(dir, "package.json"), ~s({"scripts":{"install":"node-gyp rebuild"}}))
      assert NPM.Rebuild.native?(dir)
    end

    @tag :tmp_dir
    test "false for regular package", %{tmp_dir: dir} do
      File.write!(Path.join(dir, "package.json"), ~s({"name":"lodash"}))
      refute NPM.Rebuild.native?(dir)
    end
  end

  describe "needs_rebuild" do
    @tag :tmp_dir
    test "returns list of package names", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      pkg = Path.join(nm, "native-pkg")
      File.mkdir_p!(pkg)
      File.write!(Path.join(pkg, "binding.gyp"), "{}")
      File.write!(Path.join(pkg, "package.json"), ~s({"name":"native-pkg"}))

      names = NPM.Rebuild.needs_rebuild(nm)
      assert "native-pkg" in names
    end
  end

  describe "format_results" do
    test "formats package list" do
      packages = [%{name: "bcrypt", reason: "has native build files"}]
      formatted = NPM.Rebuild.format_results(packages)
      assert formatted =~ "bcrypt"
      assert formatted =~ "1"
    end

    test "empty message" do
      assert "No native addons found." = NPM.Rebuild.format_results([])
    end
  end
end
