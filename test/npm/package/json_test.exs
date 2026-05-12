defmodule NPM.Package.JSONTest do
  use ExUnit.Case, async: true

  alias NPM.Package.JSON

  describe "PackageJSON.read" do
    @tag :tmp_dir
    test "returns empty deps for missing file", %{tmp_dir: dir} do
      assert {:ok, %{}} = JSON.read(Path.join(dir, "package.json"))
    end

    @tag :tmp_dir
    test "reads dependencies from existing file", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")
      File.write!(path, ~s({"dependencies": {"lodash": "^4.17.0"}}))

      assert {:ok, %{"lodash" => "^4.17.0"}} = JSON.read(path)
    end

    @tag :tmp_dir
    test "returns empty map when no dependencies key", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")
      File.write!(path, ~s({"name": "my-app", "version": "1.0.0"}))

      assert {:ok, %{}} = JSON.read(path)
    end
  end

  describe "PackageJSON.add_dep" do
    @tag :tmp_dir
    test "creates file and reads back", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")

      assert :ok = JSON.add_dep("lodash", "^4.17.0", path)
      assert {:ok, %{"lodash" => "^4.17.0"}} = JSON.read(path)
    end

    @tag :tmp_dir
    test "preserves existing deps", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")

      JSON.add_dep("lodash", "^4.17.0", path)
      JSON.add_dep("express", "^5.0.0", path)

      assert {:ok, deps} = JSON.read(path)
      assert deps["lodash"] == "^4.17.0"
      assert deps["express"] == "^5.0.0"
    end

    @tag :tmp_dir
    test "updates existing dep version", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")

      JSON.add_dep("lodash", "^4.17.0", path)
      JSON.add_dep("lodash", "^4.18.0", path)

      assert {:ok, %{"lodash" => "^4.18.0"}} = JSON.read(path)
    end

    @tag :tmp_dir
    test "preserves non-dependency fields", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")
      File.write!(path, ~s({"name": "my-app", "version": "1.0.0"}))

      JSON.add_dep("lodash", "^4.17.0", path)

      content = File.read!(path) |> :json.decode()
      assert content["name"] == "my-app"
      assert content["version"] == "1.0.0"
      assert content["dependencies"]["lodash"] == "^4.17.0"
    end

    @tag :tmp_dir
    test "handles scoped package names", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")

      JSON.add_dep("@types/node", "^20.0.0", path)

      assert {:ok, %{"@types/node" => "^20.0.0"}} = JSON.read(path)
    end
  end

  describe "PackageJSON.remove_dep" do
    @tag :tmp_dir
    test "removes existing dep", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")

      JSON.add_dep("lodash", "^4.17.0", path)
      JSON.add_dep("express", "^5.0.0", path)

      assert :ok = JSON.remove_dep("lodash", path)
      assert {:ok, deps} = JSON.read(path)
      refute Map.has_key?(deps, "lodash")
      assert deps["express"] == "^5.0.0"
    end

    @tag :tmp_dir
    test "returns error for missing dep", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")
      JSON.add_dep("lodash", "^4.17.0", path)

      assert {:error, {:not_found, "express"}} = JSON.remove_dep("express", path)
    end

    @tag :tmp_dir
    test "removes scoped package", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")

      JSON.add_dep("@types/node", "^20.0.0", path)
      assert :ok = JSON.remove_dep("@types/node", path)

      assert {:ok, %{}} = JSON.read(path)
    end

    @tag :tmp_dir
    test "preserves non-dependency fields", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")
      File.write!(path, ~s({"name": "app", "dependencies": {"lodash": "^4.0"}}))

      JSON.remove_dep("lodash", path)

      content = File.read!(path) |> :json.decode()
      assert content["name"] == "app"
      assert content["dependencies"] == %{}
    end
  end

  describe "PackageJSON.read_scripts" do
    @tag :tmp_dir
    test "returns empty map for missing file", %{tmp_dir: dir} do
      assert {:ok, %{}} = JSON.read_scripts(Path.join(dir, "package.json"))
    end

    @tag :tmp_dir
    test "reads scripts from package.json", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")

      File.write!(path, ~s({
        "scripts": {"build": "tsc", "test": "jest", "lint": "eslint ."}
      }))

      assert {:ok, scripts} = JSON.read_scripts(path)
      assert scripts == %{"build" => "tsc", "test" => "jest", "lint" => "eslint ."}
    end

    @tag :tmp_dir
    test "returns empty map when no scripts key", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")
      File.write!(path, ~s({"name": "my-app"}))

      assert {:ok, %{}} = JSON.read_scripts(path)
    end
  end

  describe "PackageJSON.read_workspaces" do
    @tag :tmp_dir
    test "returns empty list for missing file", %{tmp_dir: dir} do
      assert {:ok, []} = JSON.read_workspaces(Path.join(dir, "package.json"))
    end

    @tag :tmp_dir
    test "reads array-style workspaces", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")
      File.write!(path, ~s({"workspaces": ["packages/*", "apps/*"]}))

      assert {:ok, ["packages/*", "apps/*"]} = JSON.read_workspaces(path)
    end

    @tag :tmp_dir
    test "reads object-style workspaces", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")
      File.write!(path, ~s({"workspaces": {"packages": ["packages/*"]}}))

      assert {:ok, ["packages/*"]} = JSON.read_workspaces(path)
    end

    @tag :tmp_dir
    test "returns empty list when no workspaces", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")
      File.write!(path, ~s({"name": "my-app"}))

      assert {:ok, []} = JSON.read_workspaces(path)
    end
  end

  describe "PackageJSON.expand_workspaces" do
    @tag :tmp_dir
    test "expands glob patterns to directories with package.json", %{tmp_dir: dir} do
      pkg_a = Path.join([dir, "packages", "a"])
      pkg_b = Path.join([dir, "packages", "b"])
      File.mkdir_p!(pkg_a)
      File.mkdir_p!(pkg_b)
      File.write!(Path.join(pkg_a, "package.json"), ~s({"name":"a"}))
      File.write!(Path.join(pkg_b, "package.json"), ~s({"name":"b"}))

      # directory without package.json should be excluded
      File.mkdir_p!(Path.join([dir, "packages", "c"]))

      result = JSON.expand_workspaces(["packages/*"], dir)
      assert length(result) == 2
    end

    @tag :tmp_dir
    test "returns empty list for no matches", %{tmp_dir: dir} do
      result = JSON.expand_workspaces(["nonexistent/*"], dir)
      assert result == []
    end
  end

  describe "PackageJSON.file_dep?" do
    test "recognizes file: prefix" do
      assert JSON.file_dep?("file:../my-lib")
      assert JSON.file_dep?("file:./local-pkg")
    end

    test "rejects non-file deps" do
      refute JSON.file_dep?("^4.0.0")
      refute JSON.file_dep?("latest")
      refute JSON.file_dep?("~1.2.3")
    end
  end

  describe "PackageJSON.resolve_file_dep" do
    test "resolves relative path" do
      result = JSON.resolve_file_dep("file:../my-lib", "/home/user/project")
      assert result == "/home/user/my-lib"
    end

    test "resolves current dir path" do
      result = JSON.resolve_file_dep("file:./packages/core", "/home/user/project")
      assert result == "/home/user/project/packages/core"
    end
  end

  describe "PackageJSON.git_dep?" do
    test "recognizes git+https URLs" do
      assert JSON.git_dep?("git+https://github.com/user/repo.git")
    end

    test "recognizes git+ssh URLs" do
      assert JSON.git_dep?("git+ssh://git@github.com/user/repo.git")
    end

    test "recognizes github: shorthand" do
      assert JSON.git_dep?("github:user/repo")
    end

    test "recognizes git:// URLs" do
      assert JSON.git_dep?("git://github.com/user/repo.git")
    end

    test "recognizes .git suffix" do
      assert JSON.git_dep?("https://github.com/user/repo.git")
    end

    test "rejects regular ranges" do
      refute JSON.git_dep?("^4.0.0")
      refute JSON.git_dep?("latest")
      refute JSON.git_dep?("~1.0")
    end
  end

  describe "PackageJSON.url_dep?" do
    test "recognizes http tgz URLs" do
      assert JSON.url_dep?("http://example.com/pkg-1.0.0.tgz")
    end

    test "recognizes https tar.gz URLs" do
      assert JSON.url_dep?("https://example.com/pkg.tar.gz")
    end

    test "rejects non-tarball URLs" do
      refute JSON.url_dep?("https://example.com/page")
    end

    test "rejects regular ranges" do
      refute JSON.url_dep?("^4.0.0")
      refute JSON.url_dep?("latest")
    end
  end

  describe "PackageJSON.read_overrides" do
    @tag :tmp_dir
    test "returns empty map for missing file", %{tmp_dir: dir} do
      assert {:ok, %{}} = JSON.read_overrides(Path.join(dir, "package.json"))
    end

    @tag :tmp_dir
    test "reads overrides from package.json", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")

      File.write!(path, ~s({
        "overrides": {"lodash": "4.17.21", "semver": "7.6.0"}
      }))

      assert {:ok, overrides} = JSON.read_overrides(path)
      assert overrides == %{"lodash" => "4.17.21", "semver" => "7.6.0"}
    end

    @tag :tmp_dir
    test "returns empty map when no overrides", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")
      File.write!(path, ~s({"dependencies": {"lodash": "^4.0"}}))

      assert {:ok, %{}} = JSON.read_overrides(path)
    end
  end

  describe "PackageJSON optional dependencies" do
    @tag :tmp_dir
    test "adds to optionalDependencies", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")

      JSON.add_dep("fsevents", "^2.3.0", path, optional: true)

      {:ok, %{optional_dependencies: opt_deps}} = JSON.read_all(path)
      assert opt_deps == %{"fsevents" => "^2.3.0"}
    end

    @tag :tmp_dir
    test "read_all includes optionalDependencies", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")

      File.write!(path, ~s({
        "dependencies": {"a": "^1.0"},
        "devDependencies": {"b": "^2.0"},
        "optionalDependencies": {"c": "^3.0"}
      }))

      {:ok, result} = JSON.read_all(path)
      assert result.dependencies == %{"a" => "^1.0"}
      assert result.dev_dependencies == %{"b" => "^2.0"}
      assert result.optional_dependencies == %{"c" => "^3.0"}
    end

    @tag :tmp_dir
    test "removes from optionalDependencies", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")

      File.write!(path, ~s({
        "dependencies": {"a": "^1.0"},
        "optionalDependencies": {"fsevents": "^2.3.0"}
      }))

      assert :ok = JSON.remove_dep("fsevents", path)

      {:ok, %{optional_dependencies: opt_deps}} = JSON.read_all(path)
      assert opt_deps == %{}
    end
  end

  describe "PackageJSON.read_all" do
    @tag :tmp_dir
    test "returns empty groups for missing file", %{tmp_dir: dir} do
      assert {:ok, %{dependencies: %{}, dev_dependencies: %{}}} =
               JSON.read_all(Path.join(dir, "package.json"))
    end

    @tag :tmp_dir
    test "reads both dependencies and devDependencies", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")

      File.write!(path, ~s({
        "dependencies": {"lodash": "^4.17.0"},
        "devDependencies": {"eslint": "^9.0.0"}
      }))

      assert {:ok, %{dependencies: deps, dev_dependencies: dev_deps}} =
               JSON.read_all(path)

      assert deps == %{"lodash" => "^4.17.0"}
      assert dev_deps == %{"eslint" => "^9.0.0"}
    end

    @tag :tmp_dir
    test "returns empty maps when neither key exists", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")
      File.write!(path, ~s({"name": "my-app"}))

      assert {:ok, %{dependencies: %{}, dev_dependencies: %{}}} =
               JSON.read_all(path)
    end

    @tag :tmp_dir
    test "handles only devDependencies present", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")
      File.write!(path, ~s({"devDependencies": {"jest": "^29.0.0"}}))

      assert {:ok, %{dependencies: %{}, dev_dependencies: %{"jest" => "^29.0.0"}}} =
               JSON.read_all(path)
    end
  end

  describe "PackageJSON.add_dep with dev" do
    @tag :tmp_dir
    test "adds to devDependencies when dev: true", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")

      assert :ok = JSON.add_dep("eslint", "^9.0.0", path, dev: true)

      {:ok, %{dependencies: deps, dev_dependencies: dev_deps}} =
        JSON.read_all(path)

      assert deps == %{}
      assert dev_deps == %{"eslint" => "^9.0.0"}
    end

    @tag :tmp_dir
    test "adds to dependencies by default", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")

      assert :ok = JSON.add_dep("lodash", "^4.17.0", path)

      {:ok, %{dependencies: deps, dev_dependencies: dev_deps}} =
        JSON.read_all(path)

      assert deps == %{"lodash" => "^4.17.0"}
      assert dev_deps == %{}
    end

    @tag :tmp_dir
    test "preserves both groups independently", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")

      JSON.add_dep("lodash", "^4.17.0", path)
      JSON.add_dep("eslint", "^9.0.0", path, dev: true)

      {:ok, %{dependencies: deps, dev_dependencies: dev_deps}} =
        JSON.read_all(path)

      assert deps == %{"lodash" => "^4.17.0"}
      assert dev_deps == %{"eslint" => "^9.0.0"}
    end
  end

  describe "PackageJSON.remove_dep with devDependencies" do
    @tag :tmp_dir
    test "removes from devDependencies", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")

      File.write!(path, ~s({
        "dependencies": {"lodash": "^4.0"},
        "devDependencies": {"eslint": "^9.0"}
      }))

      assert :ok = JSON.remove_dep("eslint", path)

      {:ok, %{dependencies: deps, dev_dependencies: dev_deps}} =
        JSON.read_all(path)

      assert deps == %{"lodash" => "^4.0"}
      assert dev_deps == %{}
    end

    @tag :tmp_dir
    test "prefers dependencies over devDependencies for same name", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")

      File.write!(path, ~s({
        "dependencies": {"pkg": "^1.0"},
        "devDependencies": {"pkg": "^2.0"}
      }))

      assert :ok = JSON.remove_dep("pkg", path)

      {:ok, %{dependencies: deps, dev_dependencies: dev_deps}} =
        JSON.read_all(path)

      assert deps == %{}
      assert dev_deps == %{"pkg" => "^2.0"}
    end
  end

  describe "PackageJSON full round-trip" do
    @tag :tmp_dir
    test "add deps to both groups, remove from each, verify", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")

      JSON.add_dep("lodash", "^4.0", path)
      JSON.add_dep("express", "^5.0", path)
      JSON.add_dep("eslint", "^9.0", path, dev: true)
      JSON.add_dep("jest", "^29.0", path, dev: true)

      {:ok, %{dependencies: deps, dev_dependencies: dev_deps}} =
        JSON.read_all(path)

      assert map_size(deps) == 2
      assert map_size(dev_deps) == 2

      JSON.remove_dep("express", path)

      {:ok, %{dependencies: deps2, dev_dependencies: dev_deps2}} =
        JSON.read_all(path)

      assert map_size(deps2) == 1
      assert deps2["lodash"] == "^4.0"
      assert map_size(dev_deps2) == 2
    end

    @tag :tmp_dir
    test "scripts and deps coexist", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")

      File.write!(path, ~s({
        "name": "test-app",
        "scripts": {"build": "tsc"},
        "dependencies": {"lodash": "^4.0"},
        "devDependencies": {"jest": "^29.0"}
      }))

      assert {:ok, scripts} = JSON.read_scripts(path)
      assert scripts == %{"build" => "tsc"}

      assert {:ok, deps} = JSON.read(path)
      assert deps == %{"lodash" => "^4.0"}

      assert {:ok, %{dev_dependencies: dev_deps}} = JSON.read_all(path)
      assert dev_deps == %{"jest" => "^29.0"}
    end
  end

  describe "PackageJSON field preservation" do
    @tag :tmp_dir
    test "preserves name, version, private when adding deps", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")

      File.write!(path, ~s({
        "name": "my-project",
        "version": "2.0.0",
        "private": true,
        "license": "MIT"
      }))

      JSON.add_dep("lodash", "^4.0", path)

      content = File.read!(path) |> :json.decode()
      assert content["name"] == "my-project"
      assert content["version"] == "2.0.0"
      assert content["private"] == true
      assert content["license"] == "MIT"
      assert content["dependencies"]["lodash"] == "^4.0"
    end

    @tag :tmp_dir
    test "preserves scripts when adding dev deps", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")

      File.write!(path, ~s({
        "scripts": {"build": "tsc", "test": "jest"},
        "dependencies": {"react": "^18.0"}
      }))

      JSON.add_dep("jest", "^29.0", path, dev: true)

      content = File.read!(path) |> :json.decode()
      assert content["scripts"]["build"] == "tsc"
      assert content["scripts"]["test"] == "jest"
      assert content["dependencies"]["react"] == "^18.0"
      assert content["devDependencies"]["jest"] == "^29.0"
    end
  end

  describe "PackageJSON.add_dep field interaction" do
    @tag :tmp_dir
    test "adding dev dep doesn't affect dependencies", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")

      JSON.add_dep("react", "^18.0", path)
      JSON.add_dep("jest", "^29.0", path, dev: true)
      JSON.add_dep("fsevents", "^2.3", path, optional: true)

      {:ok, result} = JSON.read_all(path)
      assert result.dependencies == %{"react" => "^18.0"}
      assert result.dev_dependencies == %{"jest" => "^29.0"}
      assert result.optional_dependencies == %{"fsevents" => "^2.3"}
    end
  end

  describe "PackageJSON error handling" do
    @tag :tmp_dir
    test "read returns decode errors for invalid JSON", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")
      File.write!(path, "not json{{{")

      assert {:error, %Jason.DecodeError{}} = JSON.read(path)
    end
  end

  describe "PackageJSON workspaces with nested patterns" do
    @tag :tmp_dir
    test "expands multiple patterns", %{tmp_dir: dir} do
      apps_a = Path.join([dir, "apps", "web"])
      apps_b = Path.join([dir, "apps", "api"])
      pkgs_a = Path.join([dir, "packages", "core"])

      File.mkdir_p!(apps_a)
      File.mkdir_p!(apps_b)
      File.mkdir_p!(pkgs_a)

      File.write!(Path.join(apps_a, "package.json"), ~s({"name":"web"}))
      File.write!(Path.join(apps_b, "package.json"), ~s({"name":"api"}))
      File.write!(Path.join(pkgs_a, "package.json"), ~s({"name":"core"}))

      result = JSON.expand_workspaces(["apps/*", "packages/*"], dir)
      assert length(result) == 3
    end
  end

  describe "PackageJSON comprehensive read" do
    @tag :tmp_dir
    test "read returns only dependencies, not devDeps", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")

      File.write!(path, ~s({
        "dependencies": {"a": "^1.0"},
        "devDependencies": {"b": "^2.0"},
        "optionalDependencies": {"c": "^3.0"}
      }))

      {:ok, deps} = JSON.read(path)
      assert deps == %{"a" => "^1.0"}
      refute Map.has_key?(deps, "b")
      refute Map.has_key?(deps, "c")
    end
  end

  describe "PackageJSON.file_dep edge cases" do
    test "file:. is a file dep" do
      assert JSON.file_dep?("file:.")
    end

    test "file: with absolute path" do
      assert JSON.file_dep?("file:/absolute/path")
    end
  end

  describe "PackageJSON.read_bundle_deps" do
    @tag :tmp_dir
    test "reads bundleDependencies array", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")
      File.write!(path, ~s({"bundleDependencies": ["lodash", "express"]}))

      assert {:ok, ["lodash", "express"]} = JSON.read_bundle_deps(path)
    end

    @tag :tmp_dir
    test "reads bundledDependencies (alternative spelling)", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")
      File.write!(path, ~s({"bundledDependencies": ["chalk"]}))

      assert {:ok, ["chalk"]} = JSON.read_bundle_deps(path)
    end

    @tag :tmp_dir
    test "handles true (bundle all deps)", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")

      File.write!(path, ~s({"bundleDependencies": true, "dependencies": {"a": "1", "b": "2"}}))

      assert {:ok, names} = JSON.read_bundle_deps(path)
      assert "a" in names
      assert "b" in names
    end

    @tag :tmp_dir
    test "returns empty for missing field", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")
      File.write!(path, ~s({"name": "test"}))

      assert {:ok, []} = JSON.read_bundle_deps(path)
    end

    @tag :tmp_dir
    test "returns empty for missing file", %{tmp_dir: dir} do
      assert {:ok, []} = JSON.read_bundle_deps(Path.join(dir, "nope.json"))
    end
  end

  describe "PackageJSON.read_resolutions" do
    @tag :tmp_dir
    test "reads Yarn-style resolutions", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")
      File.write!(path, ~s({"resolutions": {"lodash": "4.17.21", "**/@types/node": "20.0.0"}}))

      assert {:ok, resolutions} = JSON.read_resolutions(path)
      assert resolutions["lodash"] == "4.17.21"
      assert resolutions["**/@types/node"] == "20.0.0"
    end

    @tag :tmp_dir
    test "returns empty for missing resolutions", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")
      File.write!(path, ~s({"name": "app"}))

      assert {:ok, %{}} = JSON.read_resolutions(path)
    end

    @tag :tmp_dir
    test "returns empty for missing file", %{tmp_dir: dir} do
      assert {:ok, %{}} = JSON.read_resolutions(Path.join(dir, "missing.json"))
    end
  end

  describe "PackageJSON: remove_dep behavior" do
    @tag :tmp_dir
    test "removing non-existent dep returns error", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")
      File.write!(path, ~s({"dependencies": {"react": "^18.0"}}))

      result = JSON.remove_dep("nonexistent", path)
      assert {:error, {:not_found, "nonexistent"}} = result
    end
  end

  describe "PackageJSON: workspace glob expansion" do
    @tag :tmp_dir
    test "expand_workspaces skips dirs without package.json", %{tmp_dir: dir} do
      File.mkdir_p!(Path.join(dir, "packages/valid"))
      File.write!(Path.join([dir, "packages", "valid", "package.json"]), ~s({"name":"valid"}))
      File.mkdir_p!(Path.join(dir, "packages/invalid"))
      # No package.json in invalid

      result = JSON.expand_workspaces(["packages/*"], dir)
      valid_names = Enum.map(result, &Path.basename/1)
      assert "valid" in valid_names
      refute "invalid" in valid_names
    end
  end

  describe "PackageJSON: add_dep preserves JSON formatting" do
    @tag :tmp_dir
    test "add_dep creates valid JSON", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")
      File.write!(path, ~s({"name":"test","version":"1.0.0"}))

      :ok = JSON.add_dep("lodash", "^4.0.0", path)
      content = File.read!(path)
      # Should be parseable JSON
      data = :json.decode(content)
      assert is_map(data)
    end
  end

  describe "PackageJSON: read_all structure" do
    @tag :tmp_dir
    test "read_all returns all dep types", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")

      File.write!(path, ~s({
        "name": "full-pkg",
        "dependencies": {"a": "^1.0"},
        "devDependencies": {"b": "^2.0"},
        "optionalDependencies": {"c": "^3.0"}
      }))

      {:ok, result} = JSON.read_all(path)
      assert is_map(result.dependencies)
      assert is_map(result.dev_dependencies)
      assert is_map(result.optional_dependencies)
      assert result.dependencies["a"] == "^1.0"
      assert result.dev_dependencies["b"] == "^2.0"
      assert result.optional_dependencies["c"] == "^3.0"
    end

    @tag :tmp_dir
    test "read_all defaults empty maps for missing sections", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")
      File.write!(path, ~s({"name": "minimal"}))

      {:ok, result} = JSON.read_all(path)
      assert result.dependencies == %{}
      assert result.dev_dependencies == %{}
      assert result.optional_dependencies == %{}
    end
  end

  describe "PackageJSON: overrides reading" do
    @tag :tmp_dir
    test "reads overrides field", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")

      File.write!(path, ~s({
        "dependencies": {"express": "^4.0"},
        "overrides": {"ms": "2.1.3", "debug": "^4.0"}
      }))

      {:ok, overrides} = JSON.read_overrides(path)
      assert overrides["ms"] == "2.1.3"
      assert overrides["debug"] == "^4.0"
    end

    @tag :tmp_dir
    test "returns empty map when no overrides", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")
      File.write!(path, ~s({"dependencies": {"lodash": "^4.0"}}))

      {:ok, overrides} = JSON.read_overrides(path)
      assert overrides == %{}
    end
  end

  describe "PackageJSON: peerDependencies reading" do
    @tag :tmp_dir
    test "read_all includes peer dependencies", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")

      File.write!(path, ~s({
        "name": "my-plugin",
        "dependencies": {"lodash": "^4.0"},
        "peerDependencies": {"react": "^18.0"}
      }))

      {:ok, result} = JSON.read_all(path)
      assert result.dependencies["lodash"] == "^4.0"
    end
  end

  describe "PackageJSON: workspaces patterns" do
    @tag :tmp_dir
    test "reads array workspaces", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")
      File.write!(path, ~s({"workspaces": ["packages/*", "apps/*"]}))

      assert {:ok, patterns} = JSON.read_workspaces(path)
      assert "packages/*" in patterns
      assert "apps/*" in patterns
    end

    @tag :tmp_dir
    test "reads object workspaces (yarn format)", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")
      File.write!(path, ~s({"workspaces": {"packages": ["packages/*"]}}))

      assert {:ok, patterns} = JSON.read_workspaces(path)
      assert "packages/*" in patterns
    end

    @tag :tmp_dir
    test "expand_workspaces finds real workspace dirs", %{tmp_dir: dir} do
      # Create workspace structure
      ws1 = Path.join(dir, "packages/pkg-a")
      ws2 = Path.join(dir, "packages/pkg-b")
      File.mkdir_p!(ws1)
      File.mkdir_p!(ws2)
      File.write!(Path.join(ws1, "package.json"), ~s({"name": "@ws/a"}))
      File.write!(Path.join(ws2, "package.json"), ~s({"name": "@ws/b"}))

      # Non-workspace dir (no package.json)
      File.mkdir_p!(Path.join(dir, "packages/not-a-pkg"))

      result = JSON.expand_workspaces(["packages/*"], dir)
      assert length(result) == 2
    end
  end

  describe "PackageJSON: npm-compatible add/remove behavior" do
    @tag :tmp_dir
    test "add_dep creates dependencies section if missing", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")
      File.write!(path, ~s({"name": "test"}))

      :ok = JSON.add_dep("lodash", "^4.0.0", path)
      data = path |> File.read!() |> :json.decode()
      assert data["dependencies"]["lodash"] == "^4.0.0"
    end

    @tag :tmp_dir
    test "add_dep preserves existing deps", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")
      File.write!(path, ~s({"dependencies": {"react": "^18.0"}}))

      :ok = JSON.add_dep("lodash", "^4.0.0", path)
      data = path |> File.read!() |> :json.decode()
      assert data["dependencies"]["react"] == "^18.0"
      assert data["dependencies"]["lodash"] == "^4.0.0"
    end

    @tag :tmp_dir
    test "remove_dep removes from correct section", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")
      File.write!(path, ~s({"dependencies": {"lodash": "^4.0", "react": "^18.0"}}))

      :ok = JSON.remove_dep("lodash", path)
      data = path |> File.read!() |> :json.decode()
      refute Map.has_key?(data["dependencies"], "lodash")
      assert data["dependencies"]["react"] == "^18.0"
    end

    @tag :tmp_dir
    test "add_dep with --dev adds to devDependencies", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")
      File.write!(path, ~s({"name": "test"}))

      :ok = JSON.add_dep("jest", "^29.0", path, dev: true)
      data = path |> File.read!() |> :json.decode()
      assert data["devDependencies"]["jest"] == "^29.0"
      assert is_nil(data["dependencies"])
    end

    @tag :tmp_dir
    test "add_dep with --save-optional adds to optionalDependencies", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")
      File.write!(path, ~s({"name": "test"}))

      :ok = JSON.add_dep("fsevents", "^2.0", path, optional: true)
      data = path |> File.read!() |> :json.decode()
      assert data["optionalDependencies"]["fsevents"] == "^2.0"
    end
  end

  describe "PackageJSON: file_dep? classification" do
    test "file: prefix is a file dep" do
      assert JSON.file_dep?("file:../lib")
      assert JSON.file_dep?("file:./local-pkg")
    end

    test "non file: is not a file dep" do
      refute JSON.file_dep?("^1.0.0")
      refute JSON.file_dep?("~1.0.0")
      refute JSON.file_dep?("*")
    end
  end

  describe "PackageJSON: git_dep? classification" do
    test "git+https URL is git dep" do
      assert JSON.git_dep?("git+https://github.com/user/repo.git")
    end

    test "git:// URL is git dep" do
      assert JSON.git_dep?("git://github.com/user/repo.git")
    end

    test "github: shorthand is git dep" do
      assert JSON.git_dep?("github:user/repo")
    end

    test "URL containing .git is git dep" do
      assert JSON.git_dep?("https://github.com/user/repo.git")
    end

    test "semver range is not git dep" do
      refute JSON.git_dep?("^1.0.0")
      refute JSON.git_dep?(">=2.0.0")
    end
  end

  describe "PackageJSON: url_dep? classification" do
    test "https tgz URL is url dep" do
      assert JSON.url_dep?("https://example.com/pkg.tgz")
    end

    test "http tgz URL is url dep" do
      assert JSON.url_dep?("http://example.com/pkg.tar.gz")
    end

    test "non-tarball URL is not url dep" do
      refute JSON.url_dep?("https://example.com/page")
    end

    test "semver range is not url dep" do
      refute JSON.url_dep?("^1.0.0")
    end
  end

  describe "PackageJSON: resolve_file_dep" do
    test "resolves relative path" do
      path = JSON.resolve_file_dep("file:./lib", "/home/user/project")
      assert path == "/home/user/project/lib"
    end

    test "resolves parent path" do
      path = JSON.resolve_file_dep("file:../shared", "/home/user/project")
      assert path == "/home/user/shared"
    end
  end

  describe "PackageJSON: read_scripts" do
    @tag :tmp_dir
    test "reads scripts from package.json", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")

      File.write!(path, ~s({
        "name": "test-pkg",
        "scripts": {
          "test": "vitest",
          "build": "tsc",
          "start": "node index.js"
        }
      }))

      {:ok, scripts} = JSON.read_scripts(path)
      assert scripts["test"] == "vitest"
      assert scripts["build"] == "tsc"
      assert scripts["start"] == "node index.js"
    end

    @tag :tmp_dir
    test "returns empty map when no scripts", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")
      File.write!(path, ~s({"name": "test-pkg"}))

      {:ok, scripts} = JSON.read_scripts(path)
      assert scripts == %{}
    end
  end

  describe "PackageJSON: read_workspaces" do
    @tag :tmp_dir
    test "reads workspaces array from package.json", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")
      File.write!(path, ~s({"workspaces":["packages/*","apps/*"]}))
      {:ok, workspaces} = JSON.read_workspaces(path)
      assert workspaces == ["packages/*", "apps/*"]
    end

    @tag :tmp_dir
    test "returns empty for no workspaces", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")
      File.write!(path, ~s({"name":"no-ws"}))
      {:ok, workspaces} = JSON.read_workspaces(path)
      assert workspaces == []
    end
  end

  describe "PackageJSON: read_overrides" do
    @tag :tmp_dir
    test "reads overrides from package.json", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")
      File.write!(path, ~s({"overrides":{"ms":"2.1.3"}}))
      {:ok, overrides} = JSON.read_overrides(path)
      assert overrides["ms"] == "2.1.3"
    end

    @tag :tmp_dir
    test "returns empty map when no overrides", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")
      File.write!(path, ~s({"name":"no-overrides"}))
      {:ok, overrides} = JSON.read_overrides(path)
      assert overrides == %{}
    end
  end

  describe "PackageJSON: read_resolutions (yarn-style)" do
    @tag :tmp_dir
    test "reads resolutions from package.json", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")
      File.write!(path, ~s({"resolutions":{"lodash":"4.17.21"}}))
      {:ok, resolutions} = JSON.read_resolutions(path)
      assert resolutions["lodash"] == "4.17.21"
    end
  end

  describe "PackageJSON: read_bundle_deps" do
    @tag :tmp_dir
    test "reads bundleDependencies from package.json", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")
      File.write!(path, ~s({"bundleDependencies":["a","b"]}))
      {:ok, bundle} = JSON.read_bundle_deps(path)
      assert bundle == ["a", "b"]
    end
  end

  describe "PackageJSON: read_all returns structured data" do
    @tag :tmp_dir
    test "returns deps, dev_deps, optional_deps", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")

      File.write!(path, ~s({
        "name": "full-pkg",
        "version": "2.0.0",
        "dependencies": {"a": "^1"},
        "devDependencies": {"b": "^2"},
        "optionalDependencies": {"d": "^4"}
      }))

      {:ok, data} = JSON.read_all(path)
      assert data.dependencies["a"] == "^1"
      assert data.dev_dependencies["b"] == "^2"
      assert data.optional_dependencies["d"] == "^4"
    end
  end
end
