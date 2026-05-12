defmodule NPM.Resolution.ExportsExtraTest do
  use ExUnit.Case, async: true

  alias NPM.Resolution.Exports

  @conditional_exports %{
    "." => %{
      "import" => "./dist/index.mjs",
      "require" => "./dist/index.cjs",
      "default" => "./dist/index.js"
    },
    "./utils" => %{"import" => "./dist/utils.mjs", "default" => "./dist/utils.js"},
    "./package.json" => "./package.json"
  }

  @wildcard_exports %{
    "./*" => %{"import" => "./dist/*.mjs"},
    "." => "./dist/index.js"
  }

  describe "parse" do
    test "string shorthand" do
      data = %{"exports" => "./index.js"}
      assert %{"." => "./index.js"} = Exports.parse(data)
    end

    test "subpath exports" do
      data = %{"exports" => %{"." => "./index.js", "./utils" => "./lib/utils.js"}}
      parsed = Exports.parse(data)
      assert parsed["."] == "./index.js"
      assert parsed["./utils"] == "./lib/utils.js"
    end

    test "conditional without subpaths wraps in dot" do
      data = %{"exports" => %{"import" => "./esm.js", "require" => "./cjs.js"}}
      parsed = Exports.parse(data)
      assert parsed["."]["import"] == "./esm.js"
    end

    test "nil for no exports field" do
      assert nil == Exports.parse(%{"name" => "pkg"})
    end
  end

  describe "resolve" do
    test "resolves with import condition" do
      assert {:ok, "./dist/index.mjs"} =
               Exports.resolve(@conditional_exports, ".", ["import"])
    end

    test "resolves with require condition" do
      assert {:ok, "./dist/index.cjs"} =
               Exports.resolve(@conditional_exports, ".", ["require"])
    end

    test "falls back to default" do
      assert {:ok, "./dist/index.js"} =
               Exports.resolve(@conditional_exports, ".", ["browser", "default"])
    end

    test "resolves subpath" do
      assert {:ok, "./dist/utils.mjs"} =
               Exports.resolve(@conditional_exports, "./utils", ["import"])
    end

    test "string target for subpath" do
      assert {:ok, "./package.json"} =
               Exports.resolve(@conditional_exports, "./package.json")
    end

    test "error for missing subpath" do
      assert :error =
               Exports.resolve(@conditional_exports, "./missing", ["import"])
    end

    test "returns error when no conditions match" do
      assert :error =
               Exports.resolve(@conditional_exports, ".", ["browser", "deno"])
    end

    test "import takes priority over require" do
      assert {:ok, "./dist/index.mjs"} =
               Exports.resolve(@conditional_exports, ".", ["import", "require"])
    end

    test "first matching condition wins" do
      assert {:ok, "./dist/index.cjs"} =
               Exports.resolve(@conditional_exports, ".", ["require", "import"])
    end

    test "nested subpath with conditions" do
      exports = %{
        "./feature" => %{"import" => "./esm/feature.js", "default" => "./cjs/feature.js"}
      }

      assert {:ok, "./esm/feature.js"} =
               Exports.resolve(exports, "./feature", ["import"])
    end

    test "resolves arrays and nested condition maps" do
      exports = %{
        "." => [
          %{
            "types" => "./types/index.d.ts",
            "import" => %{"types" => "./types/index.d.mts", "default" => "./dist/index.mjs"},
            "default" => %{"types" => "./types/index.d.cts", "default" => "./dist/index.cjs"}
          },
          "./fallback.js"
        ]
      }

      assert {:ok, "./dist/index.mjs"} =
               Exports.resolve(exports, ".", ["import", "default"])

      assert {:ok, "./dist/index.cjs"} =
               Exports.resolve(exports, ".", ["require", "default"])
    end

    test "resolves wildcard targets" do
      assert {:ok, "./dist/button.mjs"} =
               Exports.resolve(@wildcard_exports, "./button", ["import"])
    end
  end

  describe "subpaths" do
    test "lists all subpaths sorted" do
      paths = Exports.subpaths(@conditional_exports)
      assert "." in paths
      assert "./utils" in paths
      assert "./package.json" in paths
    end

    test "empty for nil" do
      assert [] = Exports.subpaths(nil)
    end
  end

  describe "module_type" do
    test "ESM for type module" do
      assert :esm = Exports.module_type(%{"type" => "module"})
    end

    test "CJS by default" do
      assert :cjs = Exports.module_type(%{})
    end

    test "CJS for type commonjs" do
      assert :cjs = Exports.module_type(%{"type" => "commonjs"})
    end
  end

  describe "exported?" do
    test "true for direct subpath" do
      assert Exports.exported?("./utils", @conditional_exports)
    end

    test "false for non-exported path" do
      refute Exports.exported?("./internal", @conditional_exports)
    end

    test "false for nil export map" do
      refute Exports.exported?(".", nil)
    end

    test "wildcard pattern matches" do
      assert Exports.exported?("./anything", @wildcard_exports)
    end
  end

  describe "conditions" do
    test "extracts unique conditions" do
      conds = Exports.conditions(@conditional_exports)
      assert "import" in conds
      assert "require" in conds
      assert "default" in conds
    end

    test "nil returns empty" do
      assert [] = Exports.conditions(nil)
    end

    test "string values contribute default" do
      conds = Exports.conditions(%{"." => "./index.js"})
      assert "default" in conds
    end
  end

  describe "validate" do
    @tag :tmp_dir
    test "ok when files exist", %{tmp_dir: dir} do
      File.mkdir_p!(Path.join(dir, "dist"))
      File.write!(Path.join(dir, "dist/index.js"), "")

      exports = %{"." => "./dist/index.js"}
      assert {:ok, ["./dist/index.js"]} = Exports.validate(exports, dir)
    end

    @tag :tmp_dir
    test "error when file missing", %{tmp_dir: dir} do
      exports = %{"." => "./missing.js"}
      assert {:error, errors} = Exports.validate(exports, dir)
      assert Enum.any?(errors, &String.contains?(&1, "not found"))
    end

    test "ok for nil" do
      assert {:ok, []} = Exports.validate(nil, ".")
    end

    @tag :tmp_dir
    test "validates conditional export paths", %{tmp_dir: dir} do
      File.mkdir_p!(Path.join(dir, "dist"))
      File.write!(Path.join(dir, "dist/index.mjs"), "")

      exports = %{"." => %{"import" => "./dist/index.mjs", "require" => "./dist/index.cjs"}}
      assert {:error, errors} = Exports.validate(exports, dir)
      assert length(errors) == 1
    end
  end

  describe "parse edge cases" do
    test "nested subpath with conditions" do
      data = %{
        "exports" => %{
          "." => %{"import" => "./esm/index.js", "require" => "./cjs/index.js"},
          "./utils" => %{"import" => "./esm/utils.js"}
        }
      }

      parsed = Exports.parse(data)
      assert is_map(parsed["."])
      assert is_map(parsed["./utils"])
    end

    test "single entry without dot prefix wraps as condition" do
      data = %{"exports" => %{"import" => "./index.mjs"}}
      parsed = Exports.parse(data)
      assert parsed["."]["import"] == "./index.mjs"
    end
  end

  describe "exported? edge cases" do
    test "dot subpath in map" do
      assert Exports.exported?(".", @conditional_exports)
    end

    test "wildcard does not match dot" do
      refute Exports.exported?(".", @wildcard_exports |> Map.delete("."))
    end
  end

  describe "conditions edge cases" do
    test "mixed string and map values" do
      exports = %{
        "." => %{"import" => "./esm.js", "require" => "./cjs.js"},
        "./pkg" => "./pkg.js"
      }

      conds = Exports.conditions(exports)
      assert "import" in conds
      assert "default" in conds
    end
  end
end
