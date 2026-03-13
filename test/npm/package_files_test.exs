defmodule NPM.PackageFilesTest do
  use ExUnit.Case, async: true

  describe "whitelist" do
    test "extracts files array" do
      assert ["dist/", "lib/"] = NPM.PackageFiles.whitelist(%{"files" => ["dist/", "lib/"]})
    end

    test "nil when no files field" do
      assert nil == NPM.PackageFiles.whitelist(%{})
    end
  end

  describe "always_included?" do
    test "package.json" do
      assert NPM.PackageFiles.always_included?("package.json")
    end

    test "README.md" do
      assert NPM.PackageFiles.always_included?("README.md")
    end

    test "LICENSE variations" do
      assert NPM.PackageFiles.always_included?("LICENSE")
      assert NPM.PackageFiles.always_included?("LICENSE.txt")
      assert NPM.PackageFiles.always_included?("LICENCE")
    end

    test "CHANGELOG" do
      assert NPM.PackageFiles.always_included?("CHANGELOG.md")
    end

    test "regular files not included" do
      refute NPM.PackageFiles.always_included?("index.js")
    end
  end

  describe "always_excluded?" do
    test ".git" do
      assert NPM.PackageFiles.always_excluded?(".git")
    end

    test "node_modules" do
      assert NPM.PackageFiles.always_excluded?("node_modules")
    end

    test ".DS_Store" do
      assert NPM.PackageFiles.always_excluded?(".DS_Store")
    end

    test "regular files not excluded" do
      refute NPM.PackageFiles.always_excluded?("index.js")
    end
  end

  describe "main_entry" do
    test "returns main field" do
      assert "./dist/index.js" = NPM.PackageFiles.main_entry(%{"main" => "./dist/index.js"})
    end

    test "falls back to module" do
      assert "./esm/index.mjs" = NPM.PackageFiles.main_entry(%{"module" => "./esm/index.mjs"})
    end

    test "defaults to index.js" do
      assert "index.js" = NPM.PackageFiles.main_entry(%{})
    end
  end

  describe "entry_points" do
    test "collects all entries" do
      data = %{
        "main" => "./dist/cjs/index.js",
        "module" => "./dist/esm/index.mjs",
        "types" => "./dist/types/index.d.ts"
      }

      entries = NPM.PackageFiles.entry_points(data)
      assert length(entries) == 3
    end

    test "includes exports" do
      data = %{
        "main" => "./dist/index.js",
        "exports" => %{"." => "./dist/index.js", "./utils" => "./dist/utils.js"}
      }

      entries = NPM.PackageFiles.entry_points(data)
      assert "./dist/utils.js" in entries
    end

    test "empty for bare package" do
      assert [] = NPM.PackageFiles.entry_points(%{})
    end
  end

  describe "has_whitelist?" do
    test "true with files" do
      assert NPM.PackageFiles.has_whitelist?(%{"files" => ["dist/"]})
    end

    test "false without files" do
      refute NPM.PackageFiles.has_whitelist?(%{})
    end
  end

  describe "default_includes" do
    test "includes expected patterns" do
      includes = NPM.PackageFiles.default_includes()
      assert "package.json" in includes
      assert "README.md" in includes
      assert "LICENSE" in includes
    end
  end
end
