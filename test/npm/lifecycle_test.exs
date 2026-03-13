defmodule NPM.LifecycleTest do
  use ExUnit.Case, async: true

  describe "Lifecycle.detect" do
    @tag :tmp_dir
    test "detects install hooks", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")

      File.write!(path, ~s({
        "scripts": {
          "preinstall": "echo pre",
          "install": "node-gyp rebuild",
          "postinstall": "echo done",
          "test": "jest"
        }
      }))

      hooks = NPM.Lifecycle.detect(path)
      assert length(hooks) == 3
      assert {"preinstall", "echo pre"} in hooks
      assert {"install", "node-gyp rebuild"} in hooks
      assert {"postinstall", "echo done"} in hooks
    end

    @tag :tmp_dir
    test "returns empty for no scripts", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")
      File.write!(path, ~s({"name": "no-scripts"}))

      assert NPM.Lifecycle.detect(path) == []
    end

    @tag :tmp_dir
    test "returns empty for missing file", %{tmp_dir: dir} do
      assert NPM.Lifecycle.detect(Path.join(dir, "missing.json")) == []
    end

    @tag :tmp_dir
    test "ignores non-install hooks", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")

      File.write!(path, ~s({
        "scripts": {"test": "jest", "build": "tsc", "lint": "eslint ."}
      }))

      assert NPM.Lifecycle.detect(path) == []
    end
  end

  describe "Lifecycle.detect_all" do
    @tag :tmp_dir
    test "finds packages with install scripts", %{tmp_dir: dir} do
      nm_dir = Path.join(dir, "node_modules")

      pkg_a = Path.join(nm_dir, "native-pkg")
      File.mkdir_p!(pkg_a)

      File.write!(
        Path.join(pkg_a, "package.json"),
        ~s({"scripts": {"postinstall": "node-gyp rebuild"}})
      )

      pkg_b = Path.join(nm_dir, "normal-pkg")
      File.mkdir_p!(pkg_b)
      File.write!(Path.join(pkg_b, "package.json"), ~s({"scripts": {"test": "jest"}}))

      result = NPM.Lifecycle.detect_all(nm_dir)
      assert Map.has_key?(result, "native-pkg")
      refute Map.has_key?(result, "normal-pkg")
      assert {"postinstall", "node-gyp rebuild"} in result["native-pkg"]
    end

    @tag :tmp_dir
    test "handles empty node_modules", %{tmp_dir: dir} do
      nm_dir = Path.join(dir, "node_modules")
      File.mkdir_p!(nm_dir)

      assert NPM.Lifecycle.detect_all(nm_dir) == %{}
    end
  end

  describe "Lifecycle.detect_all with scoped packages" do
    @tag :tmp_dir
    test "finds scripts in scoped packages", %{tmp_dir: dir} do
      nm_dir = Path.join(dir, "node_modules")
      pkg = Path.join([nm_dir, "@scope", "native"])
      File.mkdir_p!(pkg)

      File.write!(
        Path.join(pkg, "package.json"),
        ~s({"scripts": {"postinstall": "node setup.js"}})
      )

      result = NPM.Lifecycle.detect_all(nm_dir)
      assert Map.has_key?(result, "@scope/native")
    end
  end

  describe "Lifecycle.detect with prepare hook" do
    @tag :tmp_dir
    test "detects prepare script", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")
      File.write!(path, ~s({"scripts": {"prepare": "husky install"}}))

      hooks = NPM.Lifecycle.detect(path)
      assert {"prepare", "husky install"} in hooks
    end
  end

  describe "Lifecycle.hook_names" do
    test "returns install-related hook names" do
      names = NPM.Lifecycle.hook_names()
      assert "preinstall" in names
      assert "install" in names
      assert "postinstall" in names
      assert "prepare" in names
    end
  end

  describe "Lifecycle: script name detection" do
    @tag :tmp_dir
    test "ignores non-lifecycle scripts", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")

      File.write!(path, ~s({
        "scripts": {
          "test": "jest",
          "build": "tsc",
          "start": "node index.js"
        }
      }))

      hooks = NPM.Lifecycle.detect(path)
      assert hooks == []
    end

    @tag :tmp_dir
    test "detects multiple lifecycle hooks", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")

      File.write!(path, ~s({
        "scripts": {
          "preinstall": "echo pre",
          "postinstall": "echo post",
          "prepare": "echo prep"
        }
      }))

      hooks = NPM.Lifecycle.detect(path)
      names = Enum.map(hooks, &elem(&1, 0))
      assert "preinstall" in names
      assert "postinstall" in names
      assert "prepare" in names
    end
  end

  describe "Lifecycle: real-world install script detection" do
    @tag :tmp_dir
    test "detects esbuild-style postinstall", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")

      File.write!(path, ~s({
        "name": "esbuild",
        "scripts": {"postinstall": "node install.js"}
      }))

      hooks = NPM.Lifecycle.detect(path)
      assert length(hooks) == 1
      assert {"postinstall", "node install.js"} in hooks
    end

    @tag :tmp_dir
    test "detects node-gyp rebuild pattern", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")

      File.write!(path, ~s({
        "scripts": {
          "install": "node-gyp rebuild",
          "test": "tape test/*.js"
        }
      }))

      hooks = NPM.Lifecycle.detect(path)
      assert length(hooks) == 1
      assert {"install", "node-gyp rebuild"} in hooks
    end

    @tag :tmp_dir
    test "detects husky prepare script", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")
      File.write!(path, ~s({"scripts": {"prepare": "husky install"}}))

      hooks = NPM.Lifecycle.detect(path)
      assert {"prepare", "husky install"} in hooks
    end
  end

  describe "Lifecycle: hook_names" do
    test "returns known install hooks" do
      names = NPM.Lifecycle.hook_names()
      assert is_list(names)
      assert Enum.any?(names)
    end
  end

  describe "Lifecycle: detect scripts in package.json" do
    @tag :tmp_dir
    test "detects postinstall script", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")
      File.write!(path, ~s({"scripts":{"postinstall":"node build.js"}}))
      hooks = NPM.Lifecycle.detect(path)
      assert Enum.any?(hooks, fn {name, _} -> name == "postinstall" end)
    end

    @tag :tmp_dir
    test "returns empty for no lifecycle scripts", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")
      File.write!(path, ~s({"scripts":{"test":"jest"}}))
      hooks = NPM.Lifecycle.detect(path)
      assert hooks == []
    end

    @tag :tmp_dir
    test "detects preinstall script", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")
      File.write!(path, ~s({"scripts":{"preinstall":"echo hi"}}))
      hooks = NPM.Lifecycle.detect(path)
      assert Enum.any?(hooks, fn {name, _} -> name == "preinstall" end)
    end
  end

  describe "Lifecycle: detect_all in node_modules" do
    @tag :tmp_dir
    test "finds lifecycle scripts across packages", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      pkg_a = Path.join(nm, "pkg-a")
      pkg_b = Path.join(nm, "pkg-b")
      File.mkdir_p!(pkg_a)
      File.mkdir_p!(pkg_b)

      File.write!(Path.join(pkg_a, "package.json"), ~s({"scripts":{"postinstall":"echo a"}}))
      File.write!(Path.join(pkg_b, "package.json"), ~s({"scripts":{"test":"jest"}}))

      results = NPM.Lifecycle.detect_all(nm)
      assert is_list(results) or is_map(results)
    end
  end
end
