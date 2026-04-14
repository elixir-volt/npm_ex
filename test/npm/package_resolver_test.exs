defmodule NPM.PackageResolverTest do
  use ExUnit.Case, async: true

  alias NPM.PackageResolver

  # ---------------------------------------------------------------------------
  # split_specifier/1
  # ---------------------------------------------------------------------------

  describe "split_specifier/1" do
    test "bare package" do
      assert {"lodash", nil} = PackageResolver.split_specifier("lodash")
    end

    test "bare package with subpath" do
      assert {"lodash", "./fp"} = PackageResolver.split_specifier("lodash/fp")
    end

    test "deep subpath" do
      assert {"lodash", "./fp/core"} = PackageResolver.split_specifier("lodash/fp/core")
    end

    test "scoped package" do
      assert {"@babel/core", nil} = PackageResolver.split_specifier("@babel/core")
    end

    test "scoped package with subpath" do
      assert {"@babel/core", "./lib/parse"} =
               PackageResolver.split_specifier("@babel/core/lib/parse")
    end

    test "scoped package deep subpath" do
      assert {"@vue/compiler-sfc", "./dist/index"} =
               PackageResolver.split_specifier("@vue/compiler-sfc/dist/index")
    end
  end

  # ---------------------------------------------------------------------------
  # relative?/1, bare?/1, node_builtin?/1
  # ---------------------------------------------------------------------------

  describe "relative?/1" do
    test "./path" do
      assert PackageResolver.relative?("./utils")
    end

    test "../path" do
      assert PackageResolver.relative?("../utils")
    end

    test "absolute path" do
      assert PackageResolver.relative?("/usr/lib/node")
    end

    test "bare specifier is not relative" do
      refute PackageResolver.relative?("lodash")
    end

    test "scoped specifier is not relative" do
      refute PackageResolver.relative?("@babel/core")
    end
  end

  describe "bare?/1" do
    test "plain package" do
      assert PackageResolver.bare?("lodash")
    end

    test "scoped package" do
      assert PackageResolver.bare?("@babel/core")
    end

    test "relative is not bare" do
      refute PackageResolver.bare?("./utils")
    end

    test "builtin is not bare" do
      refute PackageResolver.bare?("fs")
    end

    test "node: prefixed builtin is not bare" do
      refute PackageResolver.bare?("node:path")
    end
  end

  describe "node_builtin?/1" do
    test "common builtins" do
      assert PackageResolver.node_builtin?("fs")
      assert PackageResolver.node_builtin?("path")
      assert PackageResolver.node_builtin?("http")
      assert PackageResolver.node_builtin?("crypto")
      assert PackageResolver.node_builtin?("stream")
      assert PackageResolver.node_builtin?("url")
      assert PackageResolver.node_builtin?("util")
      assert PackageResolver.node_builtin?("events")
      assert PackageResolver.node_builtin?("buffer")
      assert PackageResolver.node_builtin?("os")
    end

    test "node: prefixed" do
      assert PackageResolver.node_builtin?("node:fs")
      assert PackageResolver.node_builtin?("node:path")
      assert PackageResolver.node_builtin?("node:test")
    end

    test "non-builtins" do
      refute PackageResolver.node_builtin?("lodash")
      refute PackageResolver.node_builtin?("express")
      refute PackageResolver.node_builtin?("@babel/core")
    end
  end

  # ---------------------------------------------------------------------------
  # find_node_modules/1
  # ---------------------------------------------------------------------------

  describe "find_node_modules/1" do
    @tag :tmp_dir
    test "finds node_modules in same directory", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      File.mkdir_p!(nm)

      assert PackageResolver.find_node_modules(dir) == nm
    end

    @tag :tmp_dir
    test "walks up to find node_modules", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      File.mkdir_p!(nm)

      nested = Path.join([dir, "src", "components"])
      File.mkdir_p!(nested)

      assert PackageResolver.find_node_modules(nested) == nm
    end

    @tag :tmp_dir
    test "returns nil when not found", %{tmp_dir: dir} do
      assert PackageResolver.find_node_modules(dir) == nil
    end
  end

  # ---------------------------------------------------------------------------
  # try_resolve/2
  # ---------------------------------------------------------------------------

  describe "try_resolve/2" do
    @tag :tmp_dir
    test "exact file match", %{tmp_dir: dir} do
      path = Path.join(dir, "utils.js")
      File.write!(path, "")

      assert {:ok, ^path} = PackageResolver.try_resolve(path)
    end

    @tag :tmp_dir
    test "probes .js extension", %{tmp_dir: dir} do
      path = Path.join(dir, "utils.js")
      File.write!(path, "")

      assert {:ok, ^path} = PackageResolver.try_resolve(Path.join(dir, "utils"))
    end

    @tag :tmp_dir
    test "probes .mjs extension", %{tmp_dir: dir} do
      path = Path.join(dir, "utils.mjs")
      File.write!(path, "")

      assert {:ok, ^path} = PackageResolver.try_resolve(Path.join(dir, "utils"))
    end

    @tag :tmp_dir
    test "custom extensions", %{tmp_dir: dir} do
      path = Path.join(dir, "utils.ts")
      File.write!(path, "")

      assert {:ok, ^path} =
               PackageResolver.try_resolve(Path.join(dir, "utils"), extensions: [".ts", ".js"])
    end

    @tag :tmp_dir
    test "resolves directory index", %{tmp_dir: dir} do
      sub = Path.join(dir, "utils")
      File.mkdir_p!(sub)
      index = Path.join(sub, "index.js")
      File.write!(index, "")

      assert {:ok, ^index} = PackageResolver.try_resolve(sub)
    end

    @tag :tmp_dir
    test "returns :error when nothing matches", %{tmp_dir: dir} do
      assert :error = PackageResolver.try_resolve(Path.join(dir, "nonexistent"))
    end

    @tag :tmp_dir
    test "prefers exact file over extension probe", %{tmp_dir: dir} do
      exact = Path.join(dir, "utils")
      File.write!(exact, "")
      File.write!(Path.join(dir, "utils.js"), "")

      assert {:ok, ^exact} = PackageResolver.try_resolve(exact)
    end

    @tag :tmp_dir
    test "extension order matters", %{tmp_dir: dir} do
      js = Path.join(dir, "mod.js")
      mjs = Path.join(dir, "mod.mjs")
      File.write!(js, "")
      File.write!(mjs, "")

      assert {:ok, ^js} = PackageResolver.try_resolve(Path.join(dir, "mod"))

      assert {:ok, ^mjs} =
               PackageResolver.try_resolve(Path.join(dir, "mod"), extensions: [".mjs", ".js"])
    end

    @tag :tmp_dir
    test "probes .json extension", %{tmp_dir: dir} do
      path = Path.join(dir, "data.json")
      File.write!(path, "{}")

      assert {:ok, ^path} = PackageResolver.try_resolve(Path.join(dir, "data"))
    end
  end

  # ---------------------------------------------------------------------------
  # resolve_entry/2
  # ---------------------------------------------------------------------------

  describe "resolve_entry/2" do
    @tag :tmp_dir
    test "resolves via exports field", %{tmp_dir: dir} do
      entry = Path.join(dir, "dist/index.mjs")
      File.mkdir_p!(Path.dirname(entry))
      File.write!(entry, "")

      write_pkg_json(dir, %{
        "name" => "test-pkg",
        "exports" => %{"." => %{"import" => "./dist/index.mjs", "default" => "./dist/index.js"}}
      })

      assert {:ok, ^entry} = PackageResolver.resolve_entry(dir)
    end

    @tag :tmp_dir
    test "resolves subpath via exports", %{tmp_dir: dir} do
      utils = Path.join(dir, "dist/utils.mjs")
      File.mkdir_p!(Path.dirname(utils))
      File.write!(utils, "")

      write_pkg_json(dir, %{
        "name" => "test-pkg",
        "exports" => %{
          "." => "./dist/index.mjs",
          "./utils" => %{"import" => "./dist/utils.mjs"}
        }
      })

      assert {:ok, ^utils} = PackageResolver.resolve_entry(dir, subpath: "./utils")
    end

    @tag :tmp_dir
    test "falls back to main field", %{tmp_dir: dir} do
      main = Path.join(dir, "lib/index.js")
      File.mkdir_p!(Path.dirname(main))
      File.write!(main, "")

      write_pkg_json(dir, %{"name" => "test-pkg", "main" => "./lib/index.js"})

      assert {:ok, ^main} = PackageResolver.resolve_entry(dir)
    end

    @tag :tmp_dir
    test "falls back to module field", %{tmp_dir: dir} do
      mod = Path.join(dir, "esm/index.mjs")
      File.mkdir_p!(Path.dirname(mod))
      File.write!(mod, "")

      write_pkg_json(dir, %{"name" => "test-pkg", "module" => "./esm/index.mjs"})

      assert {:ok, ^mod} = PackageResolver.resolve_entry(dir)
    end

    @tag :tmp_dir
    test "browser field when condition present", %{tmp_dir: dir} do
      browser = Path.join(dir, "browser.js")
      main = Path.join(dir, "main.js")
      File.write!(browser, "")
      File.write!(main, "")

      write_pkg_json(dir, %{
        "name" => "test-pkg",
        "main" => "./main.js",
        "browser" => "./browser.js"
      })

      assert {:ok, ^browser} =
               PackageResolver.resolve_entry(dir, conditions: ["browser", "import", "default"])
    end

    @tag :tmp_dir
    test "browser field ignored without condition", %{tmp_dir: dir} do
      main = Path.join(dir, "main.js")
      File.write!(main, "")
      File.write!(Path.join(dir, "browser.js"), "")

      write_pkg_json(dir, %{
        "name" => "test-pkg",
        "main" => "./main.js",
        "browser" => "./browser.js"
      })

      assert {:ok, ^main} =
               PackageResolver.resolve_entry(dir, conditions: ["import", "default"])
    end

    @tag :tmp_dir
    test "falls back to index.js", %{tmp_dir: dir} do
      index = Path.join(dir, "index.js")
      File.write!(index, "")

      write_pkg_json(dir, %{"name" => "test-pkg"})

      assert {:ok, ^index} = PackageResolver.resolve_entry(dir)
    end

    @tag :tmp_dir
    test "falls back to index.js without package.json", %{tmp_dir: dir} do
      index = Path.join(dir, "index.js")
      File.write!(index, "")

      assert {:ok, ^index} = PackageResolver.resolve_entry(dir)
    end

    @tag :tmp_dir
    test "main with extension probing", %{tmp_dir: dir} do
      main = Path.join(dir, "lib/main.js")
      File.mkdir_p!(Path.dirname(main))
      File.write!(main, "")

      write_pkg_json(dir, %{"name" => "test-pkg", "main" => "./lib/main"})

      assert {:ok, ^main} = PackageResolver.resolve_entry(dir)
    end

    @tag :tmp_dir
    test "returns :error when nothing resolves", %{tmp_dir: dir} do
      write_pkg_json(dir, %{"name" => "test-pkg", "main" => "./nonexistent.js"})

      assert :error = PackageResolver.resolve_entry(dir)
    end

    @tag :tmp_dir
    test "exports takes priority over main", %{tmp_dir: dir} do
      exports_entry = Path.join(dir, "dist/esm.mjs")
      main_entry = Path.join(dir, "lib/index.js")
      File.mkdir_p!(Path.dirname(exports_entry))
      File.mkdir_p!(Path.dirname(main_entry))
      File.write!(exports_entry, "")
      File.write!(main_entry, "")

      write_pkg_json(dir, %{
        "name" => "test-pkg",
        "exports" => %{"." => %{"import" => "./dist/esm.mjs"}},
        "main" => "./lib/index.js"
      })

      assert {:ok, ^exports_entry} = PackageResolver.resolve_entry(dir)
    end
  end

  # ---------------------------------------------------------------------------
  # resolve/3 (full resolution)
  # ---------------------------------------------------------------------------

  describe "resolve/3" do
    test "built-in returns {:builtin, name}" do
      assert {:builtin, "fs"} = PackageResolver.resolve("fs", "/tmp")
      assert {:builtin, "node:path"} = PackageResolver.resolve("node:path", "/tmp")
    end

    @tag :tmp_dir
    test "relative specifier", %{tmp_dir: dir} do
      target = Path.join(dir, "utils.js")
      File.write!(target, "")

      assert {:ok, ^target} = PackageResolver.resolve("./utils", dir)
    end

    @tag :tmp_dir
    test "relative specifier with extension probing", %{tmp_dir: dir} do
      target = Path.join(dir, "utils.ts")
      File.write!(target, "")

      assert {:ok, ^target} =
               PackageResolver.resolve("./utils", dir, extensions: [".ts", ".js"])
    end

    @tag :tmp_dir
    test "bare specifier resolves from node_modules", %{tmp_dir: dir} do
      pkg_dir = Path.join([dir, "node_modules", "lodash"])
      File.mkdir_p!(pkg_dir)
      index = Path.join(pkg_dir, "index.js")
      File.write!(index, "")
      write_pkg_json(pkg_dir, %{"name" => "lodash", "main" => "./index.js"})

      assert {:ok, ^index} = PackageResolver.resolve("lodash", dir)
    end

    @tag :tmp_dir
    test "bare specifier with subpath", %{tmp_dir: dir} do
      pkg_dir = Path.join([dir, "node_modules", "lodash"])
      File.mkdir_p!(Path.join(pkg_dir, "dist"))
      fp = Path.join(pkg_dir, "dist/fp.js")
      File.write!(fp, "")

      write_pkg_json(pkg_dir, %{
        "name" => "lodash",
        "exports" => %{
          "." => "./index.js",
          "./dist/fp" => "./dist/fp.js"
        }
      })

      assert {:ok, ^fp} = PackageResolver.resolve("lodash/dist/fp", dir)
    end

    @tag :tmp_dir
    test "scoped package", %{tmp_dir: dir} do
      pkg_dir = Path.join([dir, "node_modules", "@vue", "reactivity"])
      File.mkdir_p!(pkg_dir)
      index = Path.join(pkg_dir, "index.mjs")
      File.write!(index, "")
      write_pkg_json(pkg_dir, %{"name" => "@vue/reactivity", "module" => "./index.mjs"})

      assert {:ok, ^index} = PackageResolver.resolve("@vue/reactivity", dir)
    end

    @tag :tmp_dir
    test "returns :error for missing package", %{tmp_dir: dir} do
      File.mkdir_p!(Path.join(dir, "node_modules"))

      assert :error = PackageResolver.resolve("nonexistent", dir)
    end

    @tag :tmp_dir
    test "walks up directories to find node_modules", %{tmp_dir: dir} do
      pkg_dir = Path.join([dir, "node_modules", "chalk"])
      File.mkdir_p!(pkg_dir)
      index = Path.join(pkg_dir, "index.js")
      File.write!(index, "")
      write_pkg_json(pkg_dir, %{"name" => "chalk", "main" => "./index.js"})

      nested = Path.join([dir, "src", "components"])
      File.mkdir_p!(nested)

      assert {:ok, ^index} = PackageResolver.resolve("chalk", nested)
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  # ---------------------------------------------------------------------------
  # relative_import_path/3
  # ---------------------------------------------------------------------------

  describe "relative_import_path/3" do
    test "sibling file gets ./ prefix" do
      assert PackageResolver.relative_import_path(
               "/app/src/index.js",
               "/app/src/app.js",
               "/app"
             ) == "./app.js"
    end

    test "file in subdirectory" do
      assert PackageResolver.relative_import_path(
               "/app/src/index.js",
               "/app/src/utils/format.js",
               "/app"
             ) == "./utils/format.js"
    end

    test "file in parent directory" do
      assert PackageResolver.relative_import_path(
               "/app/src/pages/home.js",
               "/app/src/utils/format.js",
               "/app"
             ) == "../utils/format.js"
    end

    test "deeply nested upward traversal" do
      assert PackageResolver.relative_import_path(
               "/app/src/a/b/c/deep.js",
               "/app/src/lib/helper.js",
               "/app"
             ) == "../../../lib/helper.js"
    end

    test "same directory different extensions" do
      assert PackageResolver.relative_import_path(
               "/app/components/button.tsx",
               "/app/components/button.module.css",
               "/app"
             ) == "./button.module.css"
    end
  end

  defp write_pkg_json(dir, data) do
    File.write!(Path.join(dir, "package.json"), :json.encode(data))
  end
end
