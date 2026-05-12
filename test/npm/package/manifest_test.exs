defmodule NPM.Package.ManifestTest do
  use ExUnit.Case, async: true

  describe "Exports + Manifest integration" do
    test "manifest exports round-trip" do
      json = ~s({"exports": {".": {"import": "./esm.js"}, "./utils": "./utils.js"}})
      manifest = NPM.Package.Manifest.from_json(json)
      exports = manifest.exports

      assert {:ok, "./esm.js"} = NPM.Resolution.Exports.resolve(exports, ".", ["import"])
      assert {:ok, "./utils.js"} = NPM.Resolution.Exports.resolve(exports, "./utils")
    end
  end

  describe "Manifest.from_json" do
    test "parses full package.json" do
      json = ~s({
        "name": "my-app",
        "version": "1.0.0",
        "license": "MIT",
        "type": "module",
        "dependencies": {"react": "^18.0"},
        "devDependencies": {"typescript": "^5.0"},
        "scripts": {"test": "jest"},
        "engines": {"node": ">=18"},
        "exports": "./index.js"
      })

      manifest = NPM.Package.Manifest.from_json(json)
      assert manifest.name == "my-app"
      assert manifest.version == "1.0.0"
      assert manifest.license == "MIT"
      assert manifest.module_type == :esm
      assert manifest.dependencies == %{"react" => "^18.0"}
      assert manifest.dev_dependencies == %{"typescript" => "^5.0"}
      assert manifest.exports == %{"." => "./index.js"}
    end

    test "handles minimal package.json" do
      manifest = NPM.Package.Manifest.from_json(~s({"name": "minimal"}))
      assert manifest.name == "minimal"
      assert manifest.version == nil
      assert manifest.dependencies == %{}
      assert manifest.module_type == :cjs
    end
  end

  describe "Manifest.dep_count" do
    test "counts all dep types" do
      manifest = NPM.Package.Manifest.from_json(~s({
        "dependencies": {"a": "1", "b": "2"},
        "devDependencies": {"c": "3"},
        "optionalDependencies": {"d": "4"}
      }))

      assert NPM.Package.Manifest.dep_count(manifest) == 4
    end
  end

  describe "Manifest.has_scripts?" do
    test "true when scripts exist" do
      manifest = NPM.Package.Manifest.from_json(~s({"scripts": {"test": "jest"}}))
      assert NPM.Package.Manifest.has_scripts?(manifest)
    end

    test "false when no scripts" do
      manifest = NPM.Package.Manifest.from_json(~s({"name": "no-scripts"}))
      refute NPM.Package.Manifest.has_scripts?(manifest)
    end
  end

  describe "Manifest.all_dep_names" do
    test "merges all dep names sorted and unique" do
      manifest = NPM.Package.Manifest.from_json(~s({
        "dependencies": {"b": "1"},
        "devDependencies": {"a": "1", "b": "2"},
        "optionalDependencies": {"c": "1"}
      }))

      assert NPM.Package.Manifest.all_dep_names(manifest) == ["a", "b", "c"]
    end
  end

  describe "Manifest.module_type integration" do
    test "esm exports with module type" do
      manifest = NPM.Package.Manifest.from_json(~s({
        "type": "module",
        "exports": {"import": "./esm.js", "require": "./cjs.js"}
      }))

      assert manifest.module_type == :esm
      assert manifest.exports == %{"." => %{"import" => "./esm.js", "require" => "./cjs.js"}}
    end
  end

  describe "Manifest.from_file" do
    @tag :tmp_dir
    test "reads from filesystem", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")
      File.write!(path, ~s({"name": "from-file", "version": "2.0.0"}))

      assert {:ok, manifest} = NPM.Package.Manifest.from_file(path)
      assert manifest.name == "from-file"
    end

    @tag :tmp_dir
    test "returns error for missing file", %{tmp_dir: dir} do
      assert {:error, :enoent} = NPM.Package.Manifest.from_file(Path.join(dir, "nope.json"))
    end
  end

  describe "Manifest: structured package.json access" do
    @tag :tmp_dir
    test "from_file reads package.json", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")

      File.write!(path, ~s({
        "name": "my-app",
        "version": "1.0.0",
        "dependencies": {"react": "^18.0", "lodash": "^4.0"},
        "devDependencies": {"jest": "^29.0"},
        "scripts": {"test": "jest", "build": "tsc"}
      }))

      {:ok, manifest} = NPM.Package.Manifest.from_file(path)
      assert manifest.name == "my-app"
      assert manifest.version == "1.0.0"
      assert NPM.Package.Manifest.dep_count(manifest) == 3
      assert NPM.Package.Manifest.has_scripts?(manifest)
      names = NPM.Package.Manifest.all_dep_names(manifest)
      assert "react" in names
      assert "jest" in names
    end

    test "from_json parses raw JSON string" do
      json = ~s({"name": "test", "version": "0.1.0", "dependencies": {"a": "^1.0"}})
      manifest = NPM.Package.Manifest.from_json(json)
      assert manifest.name == "test"
      assert NPM.Package.Manifest.dep_count(manifest) == 1
    end
  end

  describe "Manifest: from_json with all fields" do
    test "parses complete package.json" do
      json = ~s({
        "name": "full",
        "version": "1.0.0",
        "license": "MIT",
        "type": "module",
        "files": ["dist/"],
        "exports": {".": "./dist/index.js"},
        "engines": {"node": ">=18"},
        "dependencies": {"a": "^1"},
        "devDependencies": {"b": "^2"},
        "optionalDependencies": {"c": "^3"},
        "scripts": {"test": "vitest", "build": "tsc"}
      })

      m = NPM.Package.Manifest.from_json(json)
      assert m.name == "full"
      assert m.version == "1.0.0"
      assert m.license == "MIT"
      assert m.module_type == :esm
      assert m.files == ["dist/"]
      assert m.engines["node"] == ">=18"
      assert NPM.Package.Manifest.dep_count(m) == 3
      assert NPM.Package.Manifest.has_scripts?(m)
      names = NPM.Package.Manifest.all_dep_names(m)
      assert Enum.sort(names) == ["a", "b", "c"]
    end
  end

  describe "Manifest: all_dep_names deduplication" do
    test "no duplicates when same dep in multiple sections" do
      m = NPM.Package.Manifest.from_json(~s({
        "name":"t",
        "dependencies":{"a":"^1"},
        "devDependencies":{"a":"^2"}
      }))

      names = NPM.Package.Manifest.all_dep_names(m)
      assert Enum.count(names, &(&1 == "a")) <= 2
    end
  end

  describe "Manifest: module_type defaults" do
    test "defaults to CJS without type field" do
      m = NPM.Package.Manifest.from_json(~s({"name":"pkg"}))
      assert m.module_type == :cjs
    end

    test "type: commonjs is CJS" do
      m = NPM.Package.Manifest.from_json(~s({"name":"pkg","type":"commonjs"}))
      assert m.module_type == :cjs
    end
  end

  describe "Manifest: scripts detection" do
    test "has_scripts? true for package with scripts" do
      m = NPM.Package.Manifest.from_json(~s({"name":"t","scripts":{"test":"jest"}}))
      assert NPM.Package.Manifest.has_scripts?(m)
    end

    test "has_scripts? false for package without scripts" do
      m = NPM.Package.Manifest.from_json(~s({"name":"t"}))
      refute NPM.Package.Manifest.has_scripts?(m)
    end
  end

  describe "Manifest: dep_count variations" do
    test "counts only production deps" do
      m = NPM.Package.Manifest.from_json(~s({"name":"t","dependencies":{"a":"^1","b":"^2"}}))
      assert NPM.Package.Manifest.dep_count(m) == 2
    end

    test "counts all dep types" do
      m =
        NPM.Package.Manifest.from_json(~s({
          "name":"t",
          "dependencies":{"a":"^1"},
          "devDependencies":{"b":"^2"},
          "optionalDependencies":{"c":"^3"}
        }))

      assert NPM.Package.Manifest.dep_count(m) == 3
    end
  end

  describe "Manifest: license and files fields" do
    test "from_json reads license" do
      m = NPM.Package.Manifest.from_json(~s({"name": "pkg", "license": "MIT"}))
      assert m.license == "MIT"
    end

    test "from_json reads files array" do
      m = NPM.Package.Manifest.from_json(~s({"name": "pkg", "files": ["lib/", "index.js"]}))
      assert m.files == ["lib/", "index.js"]
    end

    test "from_json reads exports map" do
      m = NPM.Package.Manifest.from_json(~s({"name": "pkg", "exports": {".": "./index.js"}}))
      assert m.exports == %{"." => "./index.js"}
    end

    test "from_json reads engines" do
      m = NPM.Package.Manifest.from_json(~s({"name": "pkg", "engines": {"node": ">=18"}}))
      assert m.engines["node"] == ">=18"
    end
  end

  describe "Manifest: from_json edge cases" do
    test "missing fields default gracefully" do
      m = NPM.Package.Manifest.from_json(~s({"name": "minimal"}))
      assert m.name == "minimal"
      assert m.version == nil
      assert m.dependencies == %{}
      assert m.scripts == %{}
    end

    test "has_scripts? returns false for empty scripts" do
      m = NPM.Package.Manifest.from_json(~s({"name": "no-scripts"}))
      refute NPM.Package.Manifest.has_scripts?(m)
    end

    test "all_dep_names includes all dependency types" do
      m =
        NPM.Package.Manifest.from_json(~s({
          "name": "multi",
          "dependencies": {"a": "^1.0"},
          "devDependencies": {"b": "^2.0"},
          "optionalDependencies": {"c": "^3.0"}
        }))

      names = NPM.Package.Manifest.all_dep_names(m)
      assert "a" in names
      assert "b" in names
      assert "c" in names
    end

    test "module_type detects ESM from type field" do
      m = NPM.Package.Manifest.from_json(~s({"name": "esm-pkg", "type": "module"}))
      assert m.module_type == :esm
    end
  end

  describe "Manifest: from_json with engines" do
    test "engines are accessible" do
      m = NPM.Package.Manifest.from_json(~s({"name":"t","engines":{"node":">=18","npm":">=9"}}))
      assert m.engines["node"] == ">=18"
      assert m.engines["npm"] == ">=9"
    end
  end
end
