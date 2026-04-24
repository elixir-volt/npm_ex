defmodule NPM.Resolution.ConditionalTest do
  use ExUnit.Case, async: true

  @exports %{
    "." => %{
      "import" => "./dist/esm/index.mjs",
      "require" => "./dist/cjs/index.js",
      "types" => "./dist/types/index.d.ts",
      "default" => "./dist/cjs/index.js"
    },
    "./utils" => %{
      "import" => "./dist/esm/utils.mjs",
      "require" => "./dist/cjs/utils.js"
    }
  }

  describe "resolve" do
    test "string path returned as-is" do
      assert "./index.js" = NPM.Resolution.Conditional.resolve("./index.js", ["import"])
    end

    test "resolves import condition" do
      entry = @exports["."]
      assert "./dist/esm/index.mjs" = NPM.Resolution.Conditional.resolve(entry, ["import"])
    end

    test "resolves require condition" do
      entry = @exports["."]
      assert "./dist/cjs/index.js" = NPM.Resolution.Conditional.resolve(entry, ["require"])
    end

    test "falls back to default" do
      entry = @exports["."]
      assert "./dist/cjs/index.js" = NPM.Resolution.Conditional.resolve(entry, ["browser"])
    end

    test "nil for no match without default" do
      entry = %{"import" => "./esm.mjs"}
      assert nil == NPM.Resolution.Conditional.resolve(entry, ["require"])
    end

    test "nested conditions" do
      entry = %{
        "node" => %{
          "import" => "./dist/node-esm.mjs",
          "require" => "./dist/node-cjs.js"
        },
        "default" => "./dist/browser.js"
      }

      assert "./dist/node-esm.mjs" = NPM.Resolution.Conditional.resolve(entry, ["node", "import"])
    end
  end

  describe "conditions" do
    test "extracts all condition keys" do
      entry = @exports["."]
      conds = NPM.Resolution.Conditional.conditions(entry)
      assert "import" in conds
      assert "require" in conds
      assert "types" in conds
    end

    test "empty for string path" do
      assert [] = NPM.Resolution.Conditional.conditions("./index.js")
    end
  end

  describe "uses_condition?" do
    test "true for used condition" do
      entry = @exports["."]
      assert NPM.Resolution.Conditional.uses_condition?(entry, "import")
    end

    test "false for unused condition" do
      entry = @exports["."]
      refute NPM.Resolution.Conditional.uses_condition?(entry, "browser")
    end
  end

  describe "unknown_conditions" do
    test "detects custom conditions" do
      exports = %{"custom-env" => "./custom.js", "import" => "./index.mjs"}
      unknown = NPM.Resolution.Conditional.unknown_conditions(exports)
      assert "custom-env" in unknown
    end

    test "ignores path-like keys" do
      exports = %{"." => "./index.js", "./utils" => "./utils.js"}
      assert [] = NPM.Resolution.Conditional.unknown_conditions(exports)
    end

    test "empty for standard conditions" do
      entry = @exports["."]
      assert [] = NPM.Resolution.Conditional.unknown_conditions(entry)
    end
  end

  describe "known_conditions" do
    test "returns standard conditions" do
      known = NPM.Resolution.Conditional.known_conditions()
      assert "import" in known
      assert "require" in known
      assert "default" in known
    end
  end
end
