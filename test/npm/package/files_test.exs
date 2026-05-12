defmodule NPM.Package.FilesTest do
  use ExUnit.Case, async: true

  alias NPM.Package.Files

  describe "whitelist" do
    test "extracts files array" do
      assert ["dist/", "lib/"] = Files.whitelist(%{"files" => ["dist/", "lib/"]})
    end

    test "nil when no files field" do
      assert nil == Files.whitelist(%{})
    end
  end

  describe "always_included?" do
    test "package.json" do
      assert Files.always_included?("package.json")
    end

    test "README.md" do
      assert Files.always_included?("README.md")
    end

    test "LICENSE variations" do
      assert Files.always_included?("LICENSE")
      assert Files.always_included?("LICENSE.txt")
      assert Files.always_included?("LICENCE")
    end

    test "CHANGELOG" do
      assert Files.always_included?("CHANGELOG.md")
    end

    test "regular files not included" do
      refute Files.always_included?("index.js")
    end
  end

  describe "always_excluded?" do
    test ".git" do
      assert Files.always_excluded?(".git")
    end

    test "node_modules" do
      assert Files.always_excluded?("node_modules")
    end

    test ".DS_Store" do
      assert Files.always_excluded?(".DS_Store")
    end

    test "regular files not excluded" do
      refute Files.always_excluded?("index.js")
    end
  end

  describe "main_entry" do
    test "returns main field" do
      assert "./dist/index.js" = Files.main_entry(%{"main" => "./dist/index.js"})
    end

    test "falls back to module" do
      assert "./esm/index.mjs" = Files.main_entry(%{"module" => "./esm/index.mjs"})
    end

    test "defaults to index.js" do
      assert "index.js" = Files.main_entry(%{})
    end
  end

  describe "entry_points" do
    test "collects all entries" do
      data = %{
        "main" => "./dist/cjs/index.js",
        "module" => "./dist/esm/index.mjs",
        "types" => "./dist/types/index.d.ts"
      }

      entries = Files.entry_points(data)
      assert length(entries) == 3
    end

    test "includes exports" do
      data = %{
        "main" => "./dist/index.js",
        "exports" => %{"." => "./dist/index.js", "./utils" => "./dist/utils.js"}
      }

      entries = Files.entry_points(data)
      assert "./dist/utils.js" in entries
    end

    test "empty for bare package" do
      assert [] = Files.entry_points(%{})
    end
  end

  describe "has_whitelist?" do
    test "true with files" do
      assert Files.has_whitelist?(%{"files" => ["dist/"]})
    end

    test "false without files" do
      refute Files.has_whitelist?(%{})
    end
  end

  describe "default_includes" do
    test "includes expected patterns" do
      includes = Files.default_includes()
      assert "package.json" in includes
      assert "README.md" in includes
      assert "LICENSE" in includes
    end
  end
end
