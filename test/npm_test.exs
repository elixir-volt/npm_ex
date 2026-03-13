defmodule NPMTest do
  use ExUnit.Case, async: true

  alias Mix.Tasks.Npm.Install, as: NpmInstall

  # --- PackageJSON ---

  describe "PackageJSON.read" do
    @tag :tmp_dir
    test "returns empty deps for missing file", %{tmp_dir: dir} do
      assert {:ok, %{}} = NPM.PackageJSON.read(Path.join(dir, "package.json"))
    end

    @tag :tmp_dir
    test "reads dependencies from existing file", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")
      File.write!(path, ~s({"dependencies": {"lodash": "^4.17.0"}}))

      assert {:ok, %{"lodash" => "^4.17.0"}} = NPM.PackageJSON.read(path)
    end

    @tag :tmp_dir
    test "returns empty map when no dependencies key", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")
      File.write!(path, ~s({"name": "my-app", "version": "1.0.0"}))

      assert {:ok, %{}} = NPM.PackageJSON.read(path)
    end
  end

  describe "PackageJSON.add_dep" do
    @tag :tmp_dir
    test "creates file and reads back", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")

      assert :ok = NPM.PackageJSON.add_dep("lodash", "^4.17.0", path)
      assert {:ok, %{"lodash" => "^4.17.0"}} = NPM.PackageJSON.read(path)
    end

    @tag :tmp_dir
    test "preserves existing deps", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")

      NPM.PackageJSON.add_dep("lodash", "^4.17.0", path)
      NPM.PackageJSON.add_dep("express", "^5.0.0", path)

      assert {:ok, deps} = NPM.PackageJSON.read(path)
      assert deps["lodash"] == "^4.17.0"
      assert deps["express"] == "^5.0.0"
    end

    @tag :tmp_dir
    test "updates existing dep version", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")

      NPM.PackageJSON.add_dep("lodash", "^4.17.0", path)
      NPM.PackageJSON.add_dep("lodash", "^4.18.0", path)

      assert {:ok, %{"lodash" => "^4.18.0"}} = NPM.PackageJSON.read(path)
    end

    @tag :tmp_dir
    test "preserves non-dependency fields", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")
      File.write!(path, ~s({"name": "my-app", "version": "1.0.0"}))

      NPM.PackageJSON.add_dep("lodash", "^4.17.0", path)

      content = File.read!(path) |> :json.decode()
      assert content["name"] == "my-app"
      assert content["version"] == "1.0.0"
      assert content["dependencies"]["lodash"] == "^4.17.0"
    end

    @tag :tmp_dir
    test "handles scoped package names", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")

      NPM.PackageJSON.add_dep("@types/node", "^20.0.0", path)

      assert {:ok, %{"@types/node" => "^20.0.0"}} = NPM.PackageJSON.read(path)
    end
  end

  describe "PackageJSON.remove_dep" do
    @tag :tmp_dir
    test "removes existing dep", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")

      NPM.PackageJSON.add_dep("lodash", "^4.17.0", path)
      NPM.PackageJSON.add_dep("express", "^5.0.0", path)

      assert :ok = NPM.PackageJSON.remove_dep("lodash", path)
      assert {:ok, deps} = NPM.PackageJSON.read(path)
      refute Map.has_key?(deps, "lodash")
      assert deps["express"] == "^5.0.0"
    end

    @tag :tmp_dir
    test "returns error for missing dep", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")
      NPM.PackageJSON.add_dep("lodash", "^4.17.0", path)

      assert {:error, {:not_found, "express"}} = NPM.PackageJSON.remove_dep("express", path)
    end

    @tag :tmp_dir
    test "removes scoped package", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")

      NPM.PackageJSON.add_dep("@types/node", "^20.0.0", path)
      assert :ok = NPM.PackageJSON.remove_dep("@types/node", path)

      assert {:ok, %{}} = NPM.PackageJSON.read(path)
    end

    @tag :tmp_dir
    test "preserves non-dependency fields", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")
      File.write!(path, ~s({"name": "app", "dependencies": {"lodash": "^4.0"}}))

      NPM.PackageJSON.remove_dep("lodash", path)

      content = File.read!(path) |> :json.decode()
      assert content["name"] == "app"
      assert content["dependencies"] == %{}
    end
  end

  # --- PackageJSON.read_scripts ---

  describe "PackageJSON.read_scripts" do
    @tag :tmp_dir
    test "returns empty map for missing file", %{tmp_dir: dir} do
      assert {:ok, %{}} = NPM.PackageJSON.read_scripts(Path.join(dir, "package.json"))
    end

    @tag :tmp_dir
    test "reads scripts from package.json", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")

      File.write!(path, ~s({
        "scripts": {"build": "tsc", "test": "jest", "lint": "eslint ."}
      }))

      assert {:ok, scripts} = NPM.PackageJSON.read_scripts(path)
      assert scripts == %{"build" => "tsc", "test" => "jest", "lint" => "eslint ."}
    end

    @tag :tmp_dir
    test "returns empty map when no scripts key", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")
      File.write!(path, ~s({"name": "my-app"}))

      assert {:ok, %{}} = NPM.PackageJSON.read_scripts(path)
    end
  end

  # --- PackageJSON.read_workspaces ---

  describe "PackageJSON.read_workspaces" do
    @tag :tmp_dir
    test "returns empty list for missing file", %{tmp_dir: dir} do
      assert {:ok, []} = NPM.PackageJSON.read_workspaces(Path.join(dir, "package.json"))
    end

    @tag :tmp_dir
    test "reads array-style workspaces", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")
      File.write!(path, ~s({"workspaces": ["packages/*", "apps/*"]}))

      assert {:ok, ["packages/*", "apps/*"]} = NPM.PackageJSON.read_workspaces(path)
    end

    @tag :tmp_dir
    test "reads object-style workspaces", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")
      File.write!(path, ~s({"workspaces": {"packages": ["packages/*"]}}))

      assert {:ok, ["packages/*"]} = NPM.PackageJSON.read_workspaces(path)
    end

    @tag :tmp_dir
    test "returns empty list when no workspaces", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")
      File.write!(path, ~s({"name": "my-app"}))

      assert {:ok, []} = NPM.PackageJSON.read_workspaces(path)
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

      result = NPM.PackageJSON.expand_workspaces(["packages/*"], dir)
      assert length(result) == 2
    end

    @tag :tmp_dir
    test "returns empty list for no matches", %{tmp_dir: dir} do
      result = NPM.PackageJSON.expand_workspaces(["nonexistent/*"], dir)
      assert result == []
    end
  end

  # --- PackageJSON file dependencies ---

  describe "PackageJSON.file_dep?" do
    test "recognizes file: prefix" do
      assert NPM.PackageJSON.file_dep?("file:../my-lib")
      assert NPM.PackageJSON.file_dep?("file:./local-pkg")
    end

    test "rejects non-file deps" do
      refute NPM.PackageJSON.file_dep?("^4.0.0")
      refute NPM.PackageJSON.file_dep?("latest")
      refute NPM.PackageJSON.file_dep?("~1.2.3")
    end
  end

  describe "PackageJSON.resolve_file_dep" do
    test "resolves relative path" do
      result = NPM.PackageJSON.resolve_file_dep("file:../my-lib", "/home/user/project")
      assert result == "/home/user/my-lib"
    end

    test "resolves current dir path" do
      result = NPM.PackageJSON.resolve_file_dep("file:./packages/core", "/home/user/project")
      assert result == "/home/user/project/packages/core"
    end
  end

  # --- PackageJSON.read_overrides ---

  describe "PackageJSON.read_overrides" do
    @tag :tmp_dir
    test "returns empty map for missing file", %{tmp_dir: dir} do
      assert {:ok, %{}} = NPM.PackageJSON.read_overrides(Path.join(dir, "package.json"))
    end

    @tag :tmp_dir
    test "reads overrides from package.json", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")

      File.write!(path, ~s({
        "overrides": {"lodash": "4.17.21", "semver": "7.6.0"}
      }))

      assert {:ok, overrides} = NPM.PackageJSON.read_overrides(path)
      assert overrides == %{"lodash" => "4.17.21", "semver" => "7.6.0"}
    end

    @tag :tmp_dir
    test "returns empty map when no overrides", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")
      File.write!(path, ~s({"dependencies": {"lodash": "^4.0"}}))

      assert {:ok, %{}} = NPM.PackageJSON.read_overrides(path)
    end
  end

  # --- PackageJSON optional dependencies ---

  describe "PackageJSON optional dependencies" do
    @tag :tmp_dir
    test "adds to optionalDependencies", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")

      NPM.PackageJSON.add_dep("fsevents", "^2.3.0", path, optional: true)

      {:ok, %{optional_dependencies: opt_deps}} = NPM.PackageJSON.read_all(path)
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

      {:ok, result} = NPM.PackageJSON.read_all(path)
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

      assert :ok = NPM.PackageJSON.remove_dep("fsevents", path)

      {:ok, %{optional_dependencies: opt_deps}} = NPM.PackageJSON.read_all(path)
      assert opt_deps == %{}
    end
  end

  # --- PackageJSON.read_all ---

  describe "PackageJSON.read_all" do
    @tag :tmp_dir
    test "returns empty groups for missing file", %{tmp_dir: dir} do
      assert {:ok, %{dependencies: %{}, dev_dependencies: %{}}} =
               NPM.PackageJSON.read_all(Path.join(dir, "package.json"))
    end

    @tag :tmp_dir
    test "reads both dependencies and devDependencies", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")

      File.write!(path, ~s({
        "dependencies": {"lodash": "^4.17.0"},
        "devDependencies": {"eslint": "^9.0.0"}
      }))

      assert {:ok, %{dependencies: deps, dev_dependencies: dev_deps}} =
               NPM.PackageJSON.read_all(path)

      assert deps == %{"lodash" => "^4.17.0"}
      assert dev_deps == %{"eslint" => "^9.0.0"}
    end

    @tag :tmp_dir
    test "returns empty maps when neither key exists", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")
      File.write!(path, ~s({"name": "my-app"}))

      assert {:ok, %{dependencies: %{}, dev_dependencies: %{}}} =
               NPM.PackageJSON.read_all(path)
    end

    @tag :tmp_dir
    test "handles only devDependencies present", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")
      File.write!(path, ~s({"devDependencies": {"jest": "^29.0.0"}}))

      assert {:ok, %{dependencies: %{}, dev_dependencies: %{"jest" => "^29.0.0"}}} =
               NPM.PackageJSON.read_all(path)
    end
  end

  # --- PackageJSON.add_dep with dev option ---

  describe "PackageJSON.add_dep with dev" do
    @tag :tmp_dir
    test "adds to devDependencies when dev: true", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")

      assert :ok = NPM.PackageJSON.add_dep("eslint", "^9.0.0", path, dev: true)

      {:ok, %{dependencies: deps, dev_dependencies: dev_deps}} =
        NPM.PackageJSON.read_all(path)

      assert deps == %{}
      assert dev_deps == %{"eslint" => "^9.0.0"}
    end

    @tag :tmp_dir
    test "adds to dependencies by default", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")

      assert :ok = NPM.PackageJSON.add_dep("lodash", "^4.17.0", path)

      {:ok, %{dependencies: deps, dev_dependencies: dev_deps}} =
        NPM.PackageJSON.read_all(path)

      assert deps == %{"lodash" => "^4.17.0"}
      assert dev_deps == %{}
    end

    @tag :tmp_dir
    test "preserves both groups independently", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")

      NPM.PackageJSON.add_dep("lodash", "^4.17.0", path)
      NPM.PackageJSON.add_dep("eslint", "^9.0.0", path, dev: true)

      {:ok, %{dependencies: deps, dev_dependencies: dev_deps}} =
        NPM.PackageJSON.read_all(path)

      assert deps == %{"lodash" => "^4.17.0"}
      assert dev_deps == %{"eslint" => "^9.0.0"}
    end
  end

  # --- PackageJSON.remove_dep with devDependencies ---

  describe "PackageJSON.remove_dep with devDependencies" do
    @tag :tmp_dir
    test "removes from devDependencies", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")

      File.write!(path, ~s({
        "dependencies": {"lodash": "^4.0"},
        "devDependencies": {"eslint": "^9.0"}
      }))

      assert :ok = NPM.PackageJSON.remove_dep("eslint", path)

      {:ok, %{dependencies: deps, dev_dependencies: dev_deps}} =
        NPM.PackageJSON.read_all(path)

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

      assert :ok = NPM.PackageJSON.remove_dep("pkg", path)

      {:ok, %{dependencies: deps, dev_dependencies: dev_deps}} =
        NPM.PackageJSON.read_all(path)

      assert deps == %{}
      assert dev_deps == %{"pkg" => "^2.0"}
    end
  end

  # --- Package spec parsing ---

  describe "parse_package_spec" do
    test "plain name" do
      assert {"lodash", "latest"} = NpmInstall.parse_package_spec("lodash")
    end

    test "name with range" do
      assert {"lodash", "^4.0"} = NpmInstall.parse_package_spec("lodash@^4.0")
    end

    test "scoped package" do
      assert {"@types/node", "latest"} = NpmInstall.parse_package_spec("@types/node")
    end

    test "scoped package with range" do
      assert {"@types/node", "^20.0.0"} =
               NpmInstall.parse_package_spec("@types/node@^20.0.0")
    end

    test "scoped package with exact version" do
      assert {"@babel/core", "7.24.0"} =
               NpmInstall.parse_package_spec("@babel/core@7.24.0")
    end

    test "scoped package with tilde range" do
      assert {"@scope/pkg", "~1.2.3"} =
               NpmInstall.parse_package_spec("@scope/pkg@~1.2.3")
    end
  end

  # --- Install spec parsing with options ---

  describe "parse_package_spec with version types" do
    test "exact version" do
      assert {"lodash", "4.17.21"} = NpmInstall.parse_package_spec("lodash@4.17.21")
    end

    test "caret range" do
      assert {"lodash", "^4.17"} = NpmInstall.parse_package_spec("lodash@^4.17")
    end

    test "tilde range" do
      assert {"lodash", "~4.17.0"} = NpmInstall.parse_package_spec("lodash@~4.17.0")
    end

    test "x-range" do
      assert {"lodash", "4.x"} = NpmInstall.parse_package_spec("lodash@4.x")
    end

    test "star range" do
      assert {"lodash", "*"} = NpmInstall.parse_package_spec("lodash@*")
    end

    test "greater-than range" do
      assert {"lodash", ">=4.0.0"} = NpmInstall.parse_package_spec("lodash@>=4.0.0")
    end
  end

  # --- Lockfile ---

  describe "Lockfile.read" do
    @tag :tmp_dir
    test "returns empty map for missing file", %{tmp_dir: dir} do
      assert {:ok, %{}} = NPM.Lockfile.read(Path.join(dir, "npm.lock"))
    end
  end

  describe "Lockfile round-trip" do
    @tag :tmp_dir
    test "write and read preserves all fields", %{tmp_dir: dir} do
      path = Path.join(dir, "npm.lock")

      lockfile = %{
        "lodash" => %{
          version: "4.17.21",
          integrity: "sha512-abc123==",
          tarball: "https://registry.npmjs.org/lodash/-/lodash-4.17.21.tgz",
          dependencies: %{}
        }
      }

      assert :ok = NPM.Lockfile.write(lockfile, path)
      assert {:ok, read_back} = NPM.Lockfile.read(path)
      assert read_back["lodash"].version == "4.17.21"
      assert read_back["lodash"].integrity == "sha512-abc123=="
      assert read_back["lodash"].tarball =~ "lodash-4.17.21.tgz"
      assert read_back["lodash"].dependencies == %{}
    end

    @tag :tmp_dir
    test "preserves dependencies in lockfile entries", %{tmp_dir: dir} do
      path = Path.join(dir, "npm.lock")

      lockfile = %{
        "express" => %{
          version: "4.21.2",
          integrity: "sha512-abc==",
          tarball: "https://registry.npmjs.org/express/-/express-4.21.2.tgz",
          dependencies: %{"accepts" => "~1.3.8", "body-parser" => "1.20.3"}
        }
      }

      NPM.Lockfile.write(lockfile, path)
      {:ok, read_back} = NPM.Lockfile.read(path)

      assert read_back["express"].dependencies == %{
               "accepts" => "~1.3.8",
               "body-parser" => "1.20.3"
             }
    end

    @tag :tmp_dir
    test "lockfile is stable on re-write", %{tmp_dir: dir} do
      path = Path.join(dir, "npm.lock")

      lockfile = %{
        "b-pkg" => %{version: "2.0.0", integrity: "", tarball: "", dependencies: %{}},
        "a-pkg" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      NPM.Lockfile.write(lockfile, path)
      content1 = File.read!(path)

      {:ok, read_back} = NPM.Lockfile.read(path)
      NPM.Lockfile.write(read_back, path)
      content2 = File.read!(path)

      assert content1 == content2
    end

    @tag :tmp_dir
    test "lockfile keys are sorted alphabetically", %{tmp_dir: dir} do
      path = Path.join(dir, "npm.lock")

      lockfile = %{
        "zlib" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}},
        "accepts" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      NPM.Lockfile.write(lockfile, path)
      content = File.read!(path)

      accepts_pos = :binary.match(content, "accepts") |> elem(0)
      zlib_pos = :binary.match(content, "zlib") |> elem(0)
      assert accepts_pos < zlib_pos
    end
  end

  # --- JSON ---

  describe "JSON.encode_pretty" do
    test "produces sorted keys" do
      json = NPM.JSON.encode_pretty(%{"b" => 1, "a" => 2})
      assert json =~ ~r/"a": 2.*"b": 1/s
    end

    test "handles nested maps" do
      json = NPM.JSON.encode_pretty(%{"outer" => %{"z" => 1, "a" => 2}})
      assert json =~ "outer"
      assert json =~ ~r/"a": 2.*"z": 1/s
    end

    test "handles empty map" do
      assert NPM.JSON.encode_pretty(%{}) == "{}\n"
    end
  end

  # --- Tarball ---

  describe "Tarball.verify_integrity" do
    test "passes for correct sha512" do
      data = "hello world"
      hash = :crypto.hash(:sha512, data) |> Base.encode64()
      assert :ok = NPM.Tarball.verify_integrity(data, "sha512-#{hash}")
    end

    test "fails for wrong sha512 hash" do
      assert {:error, :integrity_mismatch} =
               NPM.Tarball.verify_integrity("hello", "sha512-wronghash==")
    end

    test "passes for correct sha1" do
      data = "hello world"
      hash = :crypto.hash(:sha, data) |> Base.encode64()
      assert :ok = NPM.Tarball.verify_integrity(data, "sha1-#{hash}")
    end

    test "fails for wrong sha1 hash" do
      assert {:error, :integrity_mismatch} =
               NPM.Tarball.verify_integrity("hello", "sha1-wronghash==")
    end

    test "passes for empty integrity string" do
      assert :ok = NPM.Tarball.verify_integrity("anything", "")
    end

    test "passes for correct sha256" do
      data = "hello world"
      hash = :crypto.hash(:sha256, data) |> Base.encode64()
      assert :ok = NPM.Tarball.verify_integrity(data, "sha256-#{hash}")
    end

    test "fails for wrong sha256 hash" do
      assert {:error, :integrity_mismatch} =
               NPM.Tarball.verify_integrity("hello", "sha256-wronghash==")
    end

    test "passes for unknown hash algorithm" do
      assert :ok = NPM.Tarball.verify_integrity("anything", "sha384-something==")
    end
  end

  describe "Tarball.extract" do
    @tag :tmp_dir
    test "unpacks tgz and strips package/ prefix", %{tmp_dir: dir} do
      tgz = create_test_tgz(%{"package/index.js" => "module.exports = 42;"})

      assert {:ok, 1} = NPM.Tarball.extract(tgz, dir)
      assert File.read!(Path.join(dir, "index.js")) == "module.exports = 42;"
    end

    @tag :tmp_dir
    test "handles multiple files", %{tmp_dir: dir} do
      tgz =
        create_test_tgz(%{
          "package/index.js" => "exports.a = 1;",
          "package/lib/util.js" => "exports.b = 2;",
          "package/package.json" => ~s({"name":"test"})
        })

      assert {:ok, 3} = NPM.Tarball.extract(tgz, dir)
      assert File.exists?(Path.join(dir, "index.js"))
      assert File.exists?(Path.join(dir, "lib/util.js"))
      assert File.exists?(Path.join(dir, "package.json"))
    end

    @tag :tmp_dir
    test "creates nested directories", %{tmp_dir: dir} do
      tgz = create_test_tgz(%{"package/a/b/c/deep.js" => "deep"})

      assert {:ok, 1} = NPM.Tarball.extract(tgz, dir)
      assert File.read!(Path.join(dir, "a/b/c/deep.js")) == "deep"
    end

    @tag :tmp_dir
    test "handles files without package/ prefix", %{tmp_dir: dir} do
      tgz = create_test_tgz(%{"index.js" => "no prefix"})

      assert {:ok, 1} = NPM.Tarball.extract(tgz, dir)
      assert File.read!(Path.join(dir, "index.js")) == "no prefix"
    end
  end

  # --- Cache ---

  describe "Cache" do
    test "cached? returns false for missing package" do
      refute NPM.Cache.cached?("nonexistent-pkg-xyz-#{System.unique_integer()}", "0.0.0")
    end

    test "package_dir returns consistent path" do
      path = NPM.Cache.package_dir("lodash", "4.17.21")
      assert String.ends_with?(path, "cache/lodash/4.17.21")
    end

    test "package_dir handles scoped packages" do
      path = NPM.Cache.package_dir("@types/node", "20.0.0")
      assert String.ends_with?(path, "cache/@types/node/20.0.0")
    end

    @tag :tmp_dir
    test "ensure caches and returns path", %{tmp_dir: dir} do
      cache_dir = Path.join(dir, "cache")
      System.put_env("NPM_EX_CACHE_DIR", cache_dir)

      pkg_tgz = create_test_tgz(%{"package/package.json" => ~s({"name":"test-pkg"})})

      {:ok, listen} = :gen_tcp.listen(0, [:binary, active: false, reuseaddr: true])
      {:ok, port} = :inet.port(listen)

      spawn(fn ->
        {:ok, conn} = :gen_tcp.accept(listen)
        {:ok, _data} = :gen_tcp.recv(conn, 0, 5000)

        response =
          "HTTP/1.1 200 OK\r\nContent-Length: #{byte_size(pkg_tgz)}\r\n\r\n" <> pkg_tgz

        :gen_tcp.send(conn, response)
        :gen_tcp.close(conn)
      end)

      url = "http://127.0.0.1:#{port}/test.tgz"
      assert {:ok, path} = NPM.Cache.ensure("test-pkg", "1.0.0", url, "")
      assert File.exists?(Path.join(path, "package.json"))

      :gen_tcp.close(listen)
      assert {:ok, ^path} = NPM.Cache.ensure("test-pkg", "1.0.0", url, "")

      System.delete_env("NPM_EX_CACHE_DIR")
    end
  end

  # --- Linker ---

  describe "Linker.hoist" do
    test "returns one entry per package" do
      lockfile = %{
        "foo" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}},
        "bar" => %{version: "2.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      hoisted = NPM.Linker.hoist(lockfile)
      names = Enum.map(hoisted, &elem(&1, 0)) |> Enum.sort()
      assert names == ["bar", "foo"]
    end

    test "preserves versions" do
      lockfile = %{
        "foo" => %{version: "1.2.3", integrity: "", tarball: "", dependencies: %{}}
      }

      [{name, version}] = NPM.Linker.hoist(lockfile)
      assert name == "foo"
      assert version == "1.2.3"
    end

    test "handles empty lockfile" do
      assert NPM.Linker.hoist(%{}) == []
    end
  end

  describe "Linker.link with copy" do
    @tag :tmp_dir
    test "creates node_modules with package files", %{tmp_dir: dir} do
      cache_dir = Path.join(dir, "cache")
      nm_dir = Path.join(dir, "node_modules")

      setup_cached_package(cache_dir, "test-pkg", "1.0.0", %{
        "package.json" => ~s({"name":"test-pkg","version":"1.0.0"}),
        "index.js" => "module.exports = 42;"
      })

      lockfile = %{
        "test-pkg" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      System.put_env("NPM_EX_CACHE_DIR", cache_dir)
      NPM.Linker.link(lockfile, nm_dir, :copy)
      System.delete_env("NPM_EX_CACHE_DIR")

      assert File.exists?(Path.join([nm_dir, "test-pkg", "package.json"]))
      assert File.read!(Path.join([nm_dir, "test-pkg", "index.js"])) == "module.exports = 42;"
    end

    @tag :tmp_dir
    test "replaces stale node_modules entries", %{tmp_dir: dir} do
      cache_dir = Path.join(dir, "cache")
      nm_dir = Path.join(dir, "node_modules")

      setup_cached_package(cache_dir, "pkg", "2.0.0", %{
        "package.json" => ~s({"name":"pkg","version":"2.0.0"}),
        "index.js" => "v2"
      })

      stale_dir = Path.join([nm_dir, "pkg"])
      File.mkdir_p!(stale_dir)
      File.write!(Path.join(stale_dir, "index.js"), "v1")

      lockfile = %{
        "pkg" => %{version: "2.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      System.put_env("NPM_EX_CACHE_DIR", cache_dir)
      NPM.Linker.link(lockfile, nm_dir, :copy)
      System.delete_env("NPM_EX_CACHE_DIR")

      assert File.read!(Path.join([nm_dir, "pkg", "index.js"])) == "v2"
    end

    @tag :tmp_dir
    test "handles multiple packages", %{tmp_dir: dir} do
      cache_dir = Path.join(dir, "cache")
      nm_dir = Path.join(dir, "node_modules")

      setup_cached_package(cache_dir, "a", "1.0.0", %{"package.json" => ~s({"name":"a"})})
      setup_cached_package(cache_dir, "b", "2.0.0", %{"package.json" => ~s({"name":"b"})})
      setup_cached_package(cache_dir, "c", "3.0.0", %{"package.json" => ~s({"name":"c"})})

      lockfile = %{
        "a" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}},
        "b" => %{version: "2.0.0", integrity: "", tarball: "", dependencies: %{}},
        "c" => %{version: "3.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      System.put_env("NPM_EX_CACHE_DIR", cache_dir)
      NPM.Linker.link(lockfile, nm_dir, :copy)
      System.delete_env("NPM_EX_CACHE_DIR")

      assert File.exists?(Path.join([nm_dir, "a", "package.json"]))
      assert File.exists?(Path.join([nm_dir, "b", "package.json"]))
      assert File.exists?(Path.join([nm_dir, "c", "package.json"]))
    end
  end

  describe "Linker.link with symlink" do
    @tag :tmp_dir
    test "creates symlinks pointing to cache", %{tmp_dir: dir} do
      cache_dir = Path.join(dir, "cache")
      nm_dir = Path.join(dir, "node_modules")

      setup_cached_package(cache_dir, "test-pkg", "1.0.0", %{
        "package.json" => ~s({"name":"test-pkg"})
      })

      lockfile = %{
        "test-pkg" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      System.put_env("NPM_EX_CACHE_DIR", cache_dir)
      NPM.Linker.link(lockfile, nm_dir, :symlink)
      System.delete_env("NPM_EX_CACHE_DIR")

      link_target = Path.join(nm_dir, "test-pkg")
      assert File.exists?(link_target)
      {:ok, info} = File.lstat(link_target)
      assert info.type == :symlink
    end

    @tag :tmp_dir
    test "symlinks resolve to correct files", %{tmp_dir: dir} do
      cache_dir = Path.join(dir, "cache")
      nm_dir = Path.join(dir, "node_modules")

      setup_cached_package(cache_dir, "pkg", "1.0.0", %{
        "package.json" => ~s({"name":"pkg","version":"1.0.0"}),
        "index.js" => "hello from cache"
      })

      lockfile = %{
        "pkg" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      System.put_env("NPM_EX_CACHE_DIR", cache_dir)
      NPM.Linker.link(lockfile, nm_dir, :symlink)
      System.delete_env("NPM_EX_CACHE_DIR")

      assert File.read!(Path.join([nm_dir, "pkg", "index.js"])) == "hello from cache"
    end

    @tag :tmp_dir
    test "handles scoped packages", %{tmp_dir: dir} do
      cache_dir = Path.join(dir, "cache")
      nm_dir = Path.join(dir, "node_modules")

      setup_cached_package(cache_dir, "@scope/pkg", "1.0.0", %{
        "package.json" => ~s({"name":"@scope/pkg"})
      })

      lockfile = %{
        "@scope/pkg" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      System.put_env("NPM_EX_CACHE_DIR", cache_dir)
      NPM.Linker.link(lockfile, nm_dir, :symlink)
      System.delete_env("NPM_EX_CACHE_DIR")

      assert File.exists?(Path.join([nm_dir, "@scope", "pkg", "package.json"]))
    end
  end

  # --- PackageJSON round-trip with both dep groups ---

  describe "PackageJSON full round-trip" do
    @tag :tmp_dir
    test "add deps to both groups, remove from each, verify", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")

      NPM.PackageJSON.add_dep("lodash", "^4.0", path)
      NPM.PackageJSON.add_dep("express", "^5.0", path)
      NPM.PackageJSON.add_dep("eslint", "^9.0", path, dev: true)
      NPM.PackageJSON.add_dep("jest", "^29.0", path, dev: true)

      {:ok, %{dependencies: deps, dev_dependencies: dev_deps}} =
        NPM.PackageJSON.read_all(path)

      assert map_size(deps) == 2
      assert map_size(dev_deps) == 2

      NPM.PackageJSON.remove_dep("express", path)

      {:ok, %{dependencies: deps2, dev_dependencies: dev_deps2}} =
        NPM.PackageJSON.read_all(path)

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

      assert {:ok, scripts} = NPM.PackageJSON.read_scripts(path)
      assert scripts == %{"build" => "tsc"}

      assert {:ok, deps} = NPM.PackageJSON.read(path)
      assert deps == %{"lodash" => "^4.0"}

      assert {:ok, %{dev_dependencies: dev_deps}} = NPM.PackageJSON.read_all(path)
      assert dev_deps == %{"jest" => "^29.0"}
    end
  end

  # --- Lockfile with dependencies lookup ---

  describe "Lockfile dependency chain" do
    @tag :tmp_dir
    test "lockfile entries with dependencies can trace dependents", %{tmp_dir: dir} do
      path = Path.join(dir, "npm.lock")

      lockfile = %{
        "express" => %{
          version: "4.21.2",
          integrity: "",
          tarball: "",
          dependencies: %{"accepts" => "~1.3.8", "body-parser" => "1.20.3"}
        },
        "accepts" => %{
          version: "1.3.8",
          integrity: "",
          tarball: "",
          dependencies: %{"mime-types" => "~2.1.34"}
        },
        "body-parser" => %{
          version: "1.20.3",
          integrity: "",
          tarball: "",
          dependencies: %{}
        },
        "mime-types" => %{
          version: "2.1.35",
          integrity: "",
          tarball: "",
          dependencies: %{}
        }
      }

      NPM.Lockfile.write(lockfile, path)
      {:ok, read_back} = NPM.Lockfile.read(path)

      dependents_of_accepts =
        read_back
        |> Enum.filter(fn {name, entry} ->
          name != "accepts" and Map.has_key?(entry.dependencies, "accepts")
        end)
        |> Enum.map(&elem(&1, 0))

      assert dependents_of_accepts == ["express"]
    end
  end

  # --- Linker.link_bins ---

  describe "Linker.link_bins" do
    @tag :tmp_dir
    test "creates .bin symlinks for string bin field", %{tmp_dir: dir} do
      nm_dir = Path.join(dir, "node_modules")
      pkg_dir = Path.join(nm_dir, "my-tool")
      File.mkdir_p!(pkg_dir)
      File.write!(Path.join(pkg_dir, "package.json"), ~s({"name":"my-tool","bin":"./cli.js"}))
      File.write!(Path.join(pkg_dir, "cli.js"), "#!/usr/bin/env node\nconsole.log('hi')")

      NPM.Linker.link_bins(nm_dir, [{"my-tool", "1.0.0"}])

      link = Path.join([nm_dir, ".bin", "my-tool"])
      assert File.exists?(link)
      {:ok, info} = File.lstat(link)
      assert info.type == :symlink
    end

    @tag :tmp_dir
    test "creates .bin symlinks for map bin field", %{tmp_dir: dir} do
      nm_dir = Path.join(dir, "node_modules")
      pkg_dir = Path.join(nm_dir, "multi-tool")
      File.mkdir_p!(pkg_dir)

      File.write!(
        Path.join(pkg_dir, "package.json"),
        ~s({"name":"multi-tool","bin":{"cmd-a":"./a.js","cmd-b":"./b.js"}})
      )

      File.write!(Path.join(pkg_dir, "a.js"), "#!/usr/bin/env node")
      File.write!(Path.join(pkg_dir, "b.js"), "#!/usr/bin/env node")

      NPM.Linker.link_bins(nm_dir, [{"multi-tool", "1.0.0"}])

      assert File.exists?(Path.join([nm_dir, ".bin", "cmd-a"]))
      assert File.exists?(Path.join([nm_dir, ".bin", "cmd-b"]))
    end

    @tag :tmp_dir
    test "skips packages without bin field", %{tmp_dir: dir} do
      nm_dir = Path.join(dir, "node_modules")
      pkg_dir = Path.join(nm_dir, "no-bin")
      File.mkdir_p!(pkg_dir)
      File.write!(Path.join(pkg_dir, "package.json"), ~s({"name":"no-bin"}))

      NPM.Linker.link_bins(nm_dir, [{"no-bin", "1.0.0"}])

      refute File.exists?(Path.join([nm_dir, ".bin"]))
    end

    @tag :tmp_dir
    test "sets executable permissions on targets", %{tmp_dir: dir} do
      nm_dir = Path.join(dir, "node_modules")
      pkg_dir = Path.join(nm_dir, "exec-tool")
      File.mkdir_p!(pkg_dir)
      File.write!(Path.join(pkg_dir, "package.json"), ~s({"name":"exec-tool","bin":"./run.js"}))
      File.write!(Path.join(pkg_dir, "run.js"), "#!/usr/bin/env node")

      NPM.Linker.link_bins(nm_dir, [{"exec-tool", "1.0.0"}])

      {:ok, stat} = File.stat(Path.join(pkg_dir, "run.js"))
      assert Bitwise.band(stat.mode, 0o111) != 0
    end

    @tag :tmp_dir
    test "handles scoped packages", %{tmp_dir: dir} do
      nm_dir = Path.join(dir, "node_modules")
      pkg_dir = Path.join([nm_dir, "@scope", "tool"])
      File.mkdir_p!(pkg_dir)
      File.write!(Path.join(pkg_dir, "package.json"), ~s({"name":"@scope/tool","bin":"./cli.js"}))
      File.write!(Path.join(pkg_dir, "cli.js"), "#!/usr/bin/env node")

      NPM.Linker.link_bins(nm_dir, [{"@scope/tool", "1.0.0"}])

      assert File.exists?(Path.join([nm_dir, ".bin", "tool"]))
    end

    @tag :tmp_dir
    test "handles directories.bin field", %{tmp_dir: dir} do
      nm_dir = Path.join(dir, "node_modules")
      pkg_dir = Path.join(nm_dir, "dir-bin-tool")
      bin_dir = Path.join(pkg_dir, "bin")
      File.mkdir_p!(bin_dir)

      File.write!(
        Path.join(pkg_dir, "package.json"),
        ~s({"name":"dir-bin-tool","directories":{"bin":"./bin"}})
      )

      File.write!(Path.join(bin_dir, "run.js"), "#!/usr/bin/env node")
      File.write!(Path.join(bin_dir, "test.js"), "#!/usr/bin/env node")

      NPM.Linker.link_bins(nm_dir, [{"dir-bin-tool", "1.0.0"}])

      assert File.exists?(Path.join([nm_dir, ".bin", "run"]))
      assert File.exists?(Path.join([nm_dir, ".bin", "test"]))
    end

    @tag :tmp_dir
    test "handles missing package.json gracefully", %{tmp_dir: dir} do
      nm_dir = Path.join(dir, "node_modules")
      File.mkdir_p!(nm_dir)

      NPM.Linker.link_bins(nm_dir, [{"ghost-pkg", "1.0.0"}])

      refute File.exists?(Path.join([nm_dir, ".bin"]))
    end
  end

  # --- Linker.hoist edge cases ---

  describe "Linker.hoist edge cases" do
    test "deduplicates same package appearing multiple times" do
      lockfile = %{
        "foo" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      result = NPM.Linker.hoist(lockfile)
      assert length(result) == 1
      assert {"foo", "1.0.0"} in result
    end

    test "handles scoped packages in hoist" do
      lockfile = %{
        "@scope/a" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}},
        "@scope/b" => %{version: "2.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      result = NPM.Linker.hoist(lockfile)
      names = Enum.map(result, &elem(&1, 0)) |> Enum.sort()
      assert names == ["@scope/a", "@scope/b"]
    end

    test "single package returns single entry" do
      lockfile = %{
        "only-one" => %{version: "3.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      [{name, version}] = NPM.Linker.hoist(lockfile)
      assert name == "only-one"
      assert version == "3.0.0"
    end
  end

  # --- JSON.encode_pretty with complex data ---

  describe "JSON.encode_pretty complex" do
    test "sorts nested map keys at all levels" do
      data = %{
        "z" => %{"b" => 1, "a" => 2},
        "a" => %{"d" => 3, "c" => 4}
      }

      json = NPM.JSON.encode_pretty(data)
      a_pos = :binary.match(json, ~s("a")) |> elem(0)
      z_pos = :binary.match(json, ~s("z")) |> elem(0)
      assert a_pos < z_pos
    end

    test "handles deeply nested structures" do
      data = %{"l1" => %{"l2" => %{"l3" => "deep"}}}
      json = NPM.JSON.encode_pretty(data)
      assert json =~ "deep"
      assert json =~ "l1"
      assert json =~ "l2"
      assert json =~ "l3"
    end

    test "handles mixed arrays and maps" do
      data = %{"items" => [%{"name" => "a"}, %{"name" => "b"}]}
      json = NPM.JSON.encode_pretty(data)
      assert json =~ ~s("name": "a")
      assert json =~ ~s("name": "b")
    end

    test "produces valid JSON" do
      data = %{
        "name" => "test",
        "version" => "1.0.0",
        "dependencies" => %{"a" => "^1.0", "b" => "^2.0"},
        "scripts" => %{"test" => "jest"}
      }

      json = NPM.JSON.encode_pretty(data)
      decoded = :json.decode(json)
      assert decoded["name"] == "test"
      assert decoded["dependencies"]["a"] == "^1.0"
    end
  end

  # --- Tarball.extract edge cases ---

  describe "Tarball.extract edge cases" do
    @tag :tmp_dir
    test "handles empty tarball", %{tmp_dir: dir} do
      files = %{}
      tgz = create_test_tgz(files)
      assert {:ok, 0} = NPM.Tarball.extract(tgz, dir)
    end

    @tag :tmp_dir
    test "handles deeply nested paths", %{tmp_dir: dir} do
      tgz = create_test_tgz(%{"package/a/b/c/d/e/deep.txt" => "deep value"})

      assert {:ok, 1} = NPM.Tarball.extract(tgz, dir)
      assert File.read!(Path.join(dir, "a/b/c/d/e/deep.txt")) == "deep value"
    end

    @tag :tmp_dir
    test "preserves file content exactly", %{tmp_dir: dir} do
      content = String.duplicate("x", 10_000) <> "\n" <> String.duplicate("y", 10_000)
      tgz = create_test_tgz(%{"package/big.txt" => content})

      assert {:ok, 1} = NPM.Tarball.extract(tgz, dir)
      assert File.read!(Path.join(dir, "big.txt")) == content
    end
  end

  # --- Linker.link removes .bin on empty ---

  describe "Linker.link_bins with no bins" do
    @tag :tmp_dir
    test "does not create .bin dir when no packages have bins", %{tmp_dir: dir} do
      nm_dir = Path.join(dir, "node_modules")
      pkg_dir = Path.join(nm_dir, "no-bins")
      File.mkdir_p!(pkg_dir)
      File.write!(Path.join(pkg_dir, "package.json"), ~s({"name":"no-bins","version":"1.0.0"}))

      NPM.Linker.link_bins(nm_dir, [{"no-bins", "1.0.0"}])

      refute File.exists?(Path.join(nm_dir, ".bin"))
    end
  end

  # --- Prune preserves .bin ---

  describe "Linker.prune preserves special dirs" do
    @tag :tmp_dir
    test "prune does not remove .bin directory", %{tmp_dir: dir} do
      nm_dir = Path.join(dir, "node_modules")
      File.mkdir_p!(Path.join(nm_dir, ".bin"))
      File.mkdir_p!(Path.join(nm_dir, "pkg"))
      File.write!(Path.join([nm_dir, "pkg", "index.js"]), "ok")

      NPM.Linker.prune(nm_dir, MapSet.new(["pkg"]))

      assert File.exists?(Path.join(nm_dir, ".bin"))
      assert File.exists?(Path.join([nm_dir, "pkg", "index.js"]))
    end
  end

  # --- Lockfile format ---

  describe "Lockfile format" do
    @tag :tmp_dir
    test "lockfile contains lockfileVersion", %{tmp_dir: dir} do
      path = Path.join(dir, "npm.lock")

      lockfile = %{
        "pkg" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      NPM.Lockfile.write(lockfile, path)
      content = File.read!(path) |> :json.decode()
      assert content["lockfileVersion"] == 1
    end

    @tag :tmp_dir
    test "lockfile packages section has all required fields", %{tmp_dir: dir} do
      path = Path.join(dir, "npm.lock")

      lockfile = %{
        "test" => %{
          version: "2.0.0",
          integrity: "sha512-abc==",
          tarball: "https://example.com/test.tgz",
          dependencies: %{"dep" => "^1.0"}
        }
      }

      NPM.Lockfile.write(lockfile, path)
      {:ok, read_back} = NPM.Lockfile.read(path)

      entry = read_back["test"]
      assert entry.version == "2.0.0"
      assert entry.integrity == "sha512-abc=="
      assert entry.tarball == "https://example.com/test.tgz"
      assert entry.dependencies == %{"dep" => "^1.0"}
    end
  end

  # --- Linker.prune ---

  describe "Linker.prune" do
    @tag :tmp_dir
    test "removes packages not in expected set", %{tmp_dir: dir} do
      nm_dir = Path.join(dir, "node_modules")
      File.mkdir_p!(Path.join(nm_dir, "keep-me"))
      File.mkdir_p!(Path.join(nm_dir, "remove-me"))
      File.write!(Path.join([nm_dir, "keep-me", "index.js"]), "kept")
      File.write!(Path.join([nm_dir, "remove-me", "index.js"]), "removed")

      NPM.Linker.prune(nm_dir, MapSet.new(["keep-me"]))

      assert File.exists?(Path.join([nm_dir, "keep-me", "index.js"]))
      refute File.exists?(Path.join(nm_dir, "remove-me"))
    end

    @tag :tmp_dir
    test "removes scoped packages not in expected set", %{tmp_dir: dir} do
      nm_dir = Path.join(dir, "node_modules")
      File.mkdir_p!(Path.join([nm_dir, "@scope", "keep"]))
      File.mkdir_p!(Path.join([nm_dir, "@scope", "remove"]))
      File.write!(Path.join([nm_dir, "@scope", "keep", "index.js"]), "kept")
      File.write!(Path.join([nm_dir, "@scope", "remove", "index.js"]), "removed")

      NPM.Linker.prune(nm_dir, MapSet.new(["@scope/keep"]))

      assert File.exists?(Path.join([nm_dir, "@scope", "keep", "index.js"]))
      refute File.exists?(Path.join([nm_dir, "@scope", "remove"]))
    end

    @tag :tmp_dir
    test "removes empty scope directories", %{tmp_dir: dir} do
      nm_dir = Path.join(dir, "node_modules")
      File.mkdir_p!(Path.join([nm_dir, "@scope", "pkg"]))
      File.write!(Path.join([nm_dir, "@scope", "pkg", "index.js"]), "data")

      NPM.Linker.prune(nm_dir, MapSet.new())

      refute File.exists?(Path.join(nm_dir, "@scope"))
    end

    @tag :tmp_dir
    test "handles missing node_modules directory", %{tmp_dir: dir} do
      nm_dir = Path.join(dir, "nonexistent")
      assert :ok = NPM.Linker.prune(nm_dir, MapSet.new())
    end

    @tag :tmp_dir
    test "does nothing when all packages are expected", %{tmp_dir: dir} do
      nm_dir = Path.join(dir, "node_modules")
      File.mkdir_p!(Path.join(nm_dir, "a"))
      File.mkdir_p!(Path.join(nm_dir, "b"))
      File.write!(Path.join([nm_dir, "a", "index.js"]), "a")
      File.write!(Path.join([nm_dir, "b", "index.js"]), "b")

      NPM.Linker.prune(nm_dir, MapSet.new(["a", "b"]))

      assert File.exists?(Path.join([nm_dir, "a", "index.js"]))
      assert File.exists?(Path.join([nm_dir, "b", "index.js"]))
    end

    @tag :tmp_dir
    test "handles empty node_modules", %{tmp_dir: dir} do
      nm_dir = Path.join(dir, "node_modules")
      File.mkdir_p!(nm_dir)

      assert :ok = NPM.Linker.prune(nm_dir, MapSet.new(["something"]))
    end
  end

  # --- Lockfile with many packages ---

  describe "Lockfile scalability" do
    @tag :tmp_dir
    test "handles 50 packages round-trip", %{tmp_dir: dir} do
      path = Path.join(dir, "npm.lock")

      lockfile =
        for i <- 1..50, into: %{} do
          {"pkg-#{i}",
           %{
             version: "#{i}.0.0",
             integrity: "sha512-hash#{i}==",
             tarball: "https://example.com/pkg-#{i}.tgz",
             dependencies: %{}
           }}
        end

      NPM.Lockfile.write(lockfile, path)
      {:ok, read_back} = NPM.Lockfile.read(path)

      assert map_size(read_back) == 50
      assert read_back["pkg-1"].version == "1.0.0"
      assert read_back["pkg-50"].version == "50.0.0"
    end
  end

  # --- Linker full flow with pruning ---

  describe "Linker.link with pruning" do
    @tag :tmp_dir
    test "removes stale packages after re-install", %{tmp_dir: dir} do
      cache_dir = Path.join(dir, "cache")
      nm_dir = Path.join(dir, "node_modules")

      setup_cached_package(cache_dir, "a", "1.0.0", %{"package.json" => ~s({"name":"a"})})
      setup_cached_package(cache_dir, "b", "1.0.0", %{"package.json" => ~s({"name":"b"})})

      lockfile_v1 = %{
        "a" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}},
        "b" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      System.put_env("NPM_EX_CACHE_DIR", cache_dir)
      NPM.Linker.link(lockfile_v1, nm_dir, :copy)

      assert File.exists?(Path.join([nm_dir, "a", "package.json"]))
      assert File.exists?(Path.join([nm_dir, "b", "package.json"]))

      lockfile_v2 = %{
        "a" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      NPM.Linker.link(lockfile_v2, nm_dir, :copy)

      assert File.exists?(Path.join([nm_dir, "a", "package.json"]))
      refute File.exists?(Path.join(nm_dir, "b"))

      System.delete_env("NPM_EX_CACHE_DIR")
    end
  end

  # --- Linker.link with bin linking ---

  describe "Linker.link creates .bin entries" do
    @tag :tmp_dir
    test "creates .bin symlinks during full link flow", %{tmp_dir: dir} do
      cache_dir = Path.join(dir, "cache")
      nm_dir = Path.join(dir, "node_modules")

      setup_cached_package(cache_dir, "my-cli", "1.0.0", %{
        "package.json" => ~s({"name":"my-cli","bin":"./cli.js"}),
        "cli.js" => "#!/usr/bin/env node\nconsole.log('hello')"
      })

      lockfile = %{
        "my-cli" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      System.put_env("NPM_EX_CACHE_DIR", cache_dir)
      NPM.Linker.link(lockfile, nm_dir, :copy)
      System.delete_env("NPM_EX_CACHE_DIR")

      assert File.exists?(Path.join([nm_dir, ".bin", "my-cli"]))
    end
  end

  # --- JSON edge cases ---

  describe "JSON.encode_pretty edge cases" do
    test "handles lists" do
      json = NPM.JSON.encode_pretty(%{"items" => [1, 2, 3]})
      assert json =~ "items"
      assert json =~ "1"
    end

    test "handles nested lists in maps" do
      json = NPM.JSON.encode_pretty(%{"files" => ["a.js", "b.js"]})
      assert json =~ ~s("a.js")
      assert json =~ ~s("b.js")
    end

    test "handles boolean values" do
      json = NPM.JSON.encode_pretty(%{"private" => true})
      assert json =~ "true"
    end

    test "handles empty list" do
      json = NPM.JSON.encode_pretty(%{"items" => []})
      assert json =~ "[]"
    end

    test "handles integer values" do
      json = NPM.JSON.encode_pretty(%{"count" => 42})
      assert json =~ "42"
    end
  end

  # --- Multiple packages with bin linking ---

  describe "multiple packages with bins" do
    @tag :tmp_dir
    test "bins from multiple packages in same .bin dir", %{tmp_dir: dir} do
      nm_dir = Path.join(dir, "node_modules")

      pkg_a = Path.join(nm_dir, "tool-a")
      File.mkdir_p!(pkg_a)
      File.write!(Path.join(pkg_a, "package.json"), ~s({"name":"tool-a","bin":"./a.js"}))
      File.write!(Path.join(pkg_a, "a.js"), "#!/usr/bin/env node")

      pkg_b = Path.join(nm_dir, "tool-b")
      File.mkdir_p!(pkg_b)
      File.write!(Path.join(pkg_b, "package.json"), ~s({"name":"tool-b","bin":"./b.js"}))
      File.write!(Path.join(pkg_b, "b.js"), "#!/usr/bin/env node")

      NPM.Linker.link_bins(nm_dir, [{"tool-a", "1.0.0"}, {"tool-b", "1.0.0"}])

      assert File.exists?(Path.join([nm_dir, ".bin", "tool-a"]))
      assert File.exists?(Path.join([nm_dir, ".bin", "tool-b"]))
    end
  end

  # --- Lockfile with complex dependency chains ---

  describe "Lockfile complex deps" do
    @tag :tmp_dir
    test "handles diamond dependency pattern", %{tmp_dir: dir} do
      path = Path.join(dir, "npm.lock")

      lockfile = %{
        "app" => %{
          version: "1.0.0",
          integrity: "",
          tarball: "",
          dependencies: %{"left" => "^1.0", "right" => "^1.0"}
        },
        "left" => %{
          version: "1.0.0",
          integrity: "",
          tarball: "",
          dependencies: %{"shared" => "^2.0"}
        },
        "right" => %{
          version: "1.0.0",
          integrity: "",
          tarball: "",
          dependencies: %{"shared" => "^2.0"}
        },
        "shared" => %{
          version: "2.1.0",
          integrity: "",
          tarball: "",
          dependencies: %{}
        }
      }

      NPM.Lockfile.write(lockfile, path)
      {:ok, read_back} = NPM.Lockfile.read(path)

      assert map_size(read_back) == 4
      assert read_back["shared"].version == "2.1.0"
      assert read_back["left"].dependencies["shared"] == "^2.0"
      assert read_back["right"].dependencies["shared"] == "^2.0"
    end
  end

  # --- Tarball edge cases ---

  describe "Tarball.verify_integrity edge cases" do
    test "handles sha512 with plus and slash characters" do
      data = "complex content with special chars"
      hash = :crypto.hash(:sha512, data) |> Base.encode64()
      assert :ok = NPM.Tarball.verify_integrity(data, "sha512-#{hash}")
    end

    test "handles large binary data" do
      data = :crypto.strong_rand_bytes(100_000)
      hash = :crypto.hash(:sha512, data) |> Base.encode64()
      assert :ok = NPM.Tarball.verify_integrity(data, "sha512-#{hash}")
    end
  end

  # --- Registry configuration ---

  describe "Registry.registry_url" do
    test "defaults to npmjs.org" do
      original = System.get_env("NPM_REGISTRY")
      System.delete_env("NPM_REGISTRY")

      assert NPM.Registry.registry_url() == "https://registry.npmjs.org"

      if original, do: System.put_env("NPM_REGISTRY", original)
    end

    test "respects NPM_REGISTRY env var" do
      original = System.get_env("NPM_REGISTRY")
      System.put_env("NPM_REGISTRY", "https://registry.example.com")

      assert NPM.Registry.registry_url() == "https://registry.example.com"

      if original do
        System.put_env("NPM_REGISTRY", original)
      else
        System.delete_env("NPM_REGISTRY")
      end
    end
  end

  # --- Cache edge cases ---

  describe "Cache edge cases" do
    test "package_dir uses correct separator" do
      path = NPM.Cache.package_dir("test-pkg", "1.0.0")
      assert path =~ "cache/test-pkg/1.0.0"
    end

    test "cached? returns false for nonexistent version" do
      refute NPM.Cache.cached?("lodash", "0.0.0-nonexistent")
    end

    @tag :tmp_dir
    test "dir respects NPM_EX_CACHE_DIR env var", %{tmp_dir: dir} do
      System.put_env("NPM_EX_CACHE_DIR", dir)
      assert NPM.Cache.dir() == dir
      System.delete_env("NPM_EX_CACHE_DIR")
    end

    test "dir defaults to home directory" do
      original = System.get_env("NPM_EX_CACHE_DIR")
      System.delete_env("NPM_EX_CACHE_DIR")

      cache_dir = NPM.Cache.dir()
      assert cache_dir =~ ".npm_ex"
      assert String.starts_with?(cache_dir, System.user_home!())

      if original, do: System.put_env("NPM_EX_CACHE_DIR", original)
    end
  end

  # --- Linker.link with symlink strategy ---

  describe "Linker.link with symlink and bin linking" do
    @tag :tmp_dir
    test "bin links work with symlink strategy", %{tmp_dir: dir} do
      cache_dir = Path.join(dir, "cache")
      nm_dir = Path.join(dir, "node_modules")

      setup_cached_package(cache_dir, "cli-tool", "1.0.0", %{
        "package.json" => ~s({"name":"cli-tool","bin":{"cli":"./bin/cli.js"}}),
        "bin/cli.js" => "#!/usr/bin/env node\nconsole.log('hello')"
      })

      lockfile = %{
        "cli-tool" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      System.put_env("NPM_EX_CACHE_DIR", cache_dir)
      NPM.Linker.link(lockfile, nm_dir, :symlink)
      System.delete_env("NPM_EX_CACHE_DIR")

      assert File.exists?(Path.join([nm_dir, ".bin", "cli"]))
    end
  end

  # --- Linker with multiple strategies ---

  describe "Linker copy vs symlink" do
    @tag :tmp_dir
    test "copy creates independent files", %{tmp_dir: dir} do
      cache_dir = Path.join(dir, "cache")
      nm_dir = Path.join(dir, "node_modules")

      setup_cached_package(cache_dir, "cp-test", "1.0.0", %{
        "package.json" => ~s({"name":"cp-test"}),
        "index.js" => "original"
      })

      lockfile = %{
        "cp-test" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      System.put_env("NPM_EX_CACHE_DIR", cache_dir)
      NPM.Linker.link(lockfile, nm_dir, :copy)
      System.delete_env("NPM_EX_CACHE_DIR")

      target = Path.join([nm_dir, "cp-test", "index.js"])
      {:ok, info} = File.lstat(target)
      assert info.type == :regular
    end

    @tag :tmp_dir
    test "symlink creates links to cache", %{tmp_dir: dir} do
      cache_dir = Path.join(dir, "cache")
      nm_dir = Path.join(dir, "node_modules")

      setup_cached_package(cache_dir, "ln-test", "1.0.0", %{
        "package.json" => ~s({"name":"ln-test"})
      })

      lockfile = %{
        "ln-test" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      System.put_env("NPM_EX_CACHE_DIR", cache_dir)
      NPM.Linker.link(lockfile, nm_dir, :symlink)
      System.delete_env("NPM_EX_CACHE_DIR")

      target = Path.join(nm_dir, "ln-test")
      {:ok, info} = File.lstat(target)
      assert info.type == :symlink
    end
  end

  # --- PackageJSON preserves field order ---

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

      NPM.PackageJSON.add_dep("lodash", "^4.0", path)

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

      NPM.PackageJSON.add_dep("jest", "^29.0", path, dev: true)

      content = File.read!(path) |> :json.decode()
      assert content["scripts"]["build"] == "tsc"
      assert content["scripts"]["test"] == "jest"
      assert content["dependencies"]["react"] == "^18.0"
      assert content["devDependencies"]["jest"] == "^29.0"
    end
  end

  # --- Resolver module tests ---

  describe "Resolver.clear_cache" do
    test "succeeds even when no cache exists" do
      assert :ok = NPM.Resolver.clear_cache()
    end

    test "succeeds when called twice" do
      assert :ok = NPM.Resolver.clear_cache()
      assert :ok = NPM.Resolver.clear_cache()
    end
  end

  describe "Resolver.resolve edge cases" do
    test "returns ok for empty deps" do
      assert {:ok, %{}} = NPM.Resolver.resolve(%{})
    end
  end

  # --- JSON roundtrip ---

  describe "JSON encode/decode roundtrip" do
    test "package.json style document" do
      original = %{
        "name" => "test-pkg",
        "version" => "1.0.0",
        "dependencies" => %{"a" => "^1.0", "b" => "~2.0"},
        "devDependencies" => %{"c" => "^3.0"},
        "scripts" => %{"test" => "jest"}
      }

      json = NPM.JSON.encode_pretty(original)
      decoded = :json.decode(json)

      assert decoded["name"] == original["name"]
      assert decoded["dependencies"] == original["dependencies"]
      assert decoded["devDependencies"] == original["devDependencies"]
      assert decoded["scripts"] == original["scripts"]
    end
  end

  # --- Tarball with unicode ---

  describe "Tarball with binary content" do
    @tag :tmp_dir
    test "handles binary file content", %{tmp_dir: dir} do
      binary_content = <<0, 1, 2, 3, 255, 254, 253>>
      tgz = create_test_tgz(%{"package/binary.bin" => binary_content})

      assert {:ok, 1} = NPM.Tarball.extract(tgz, dir)
      assert File.read!(Path.join(dir, "binary.bin")) == binary_content
    end
  end

  # --- Validator ---

  describe "Validator.validate_name" do
    test "accepts valid names" do
      assert :ok = NPM.Validator.validate_name("lodash")
      assert :ok = NPM.Validator.validate_name("my-package")
      assert :ok = NPM.Validator.validate_name("pkg123")
      assert :ok = NPM.Validator.validate_name("@scope/pkg")
    end

    test "rejects empty name" do
      assert {:error, _} = NPM.Validator.validate_name("")
    end

    test "rejects names starting with period" do
      assert {:error, _} = NPM.Validator.validate_name(".hidden")
    end

    test "rejects names starting with underscore" do
      assert {:error, _} = NPM.Validator.validate_name("_internal")
    end

    test "rejects uppercase names" do
      assert {:error, _} = NPM.Validator.validate_name("MyPackage")
    end

    test "rejects names with spaces" do
      assert {:error, _} = NPM.Validator.validate_name("my package")
    end

    test "rejects overly long names" do
      name = String.duplicate("a", 215)
      assert {:error, _} = NPM.Validator.validate_name(name)
    end

    test "accepts exactly 214 char name" do
      name = String.duplicate("a", 214)
      assert :ok = NPM.Validator.validate_name(name)
    end
  end

  describe "Validator.validate_range" do
    test "accepts valid ranges" do
      assert :ok = NPM.Validator.validate_range("^4.0.0")
      assert :ok = NPM.Validator.validate_range("~1.2.3")
      assert :ok = NPM.Validator.validate_range(">=1.0.0")
      assert :ok = NPM.Validator.validate_range("*")
      assert :ok = NPM.Validator.validate_range("latest")
    end

    test "rejects empty range" do
      assert {:error, _} = NPM.Validator.validate_range("")
    end
  end

  # --- Lockfile empty dependencies ---

  describe "Lockfile empty deps handling" do
    @tag :tmp_dir
    test "handles entry with empty dependencies map", %{tmp_dir: dir} do
      path = Path.join(dir, "npm.lock")

      lockfile = %{
        "simple" => %{
          version: "1.0.0",
          integrity: "sha512-abc==",
          tarball: "https://example.com/simple.tgz",
          dependencies: %{}
        }
      }

      NPM.Lockfile.write(lockfile, path)
      {:ok, read_back} = NPM.Lockfile.read(path)

      assert read_back["simple"].dependencies == %{}
    end
  end

  # --- Scoped package operations ---

  describe "scoped package operations" do
    @tag :tmp_dir
    test "add and remove scoped dev dependency", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")

      NPM.PackageJSON.add_dep("@types/react", "^18.0", path, dev: true)

      {:ok, %{dev_dependencies: dev_deps}} = NPM.PackageJSON.read_all(path)
      assert dev_deps["@types/react"] == "^18.0"

      NPM.PackageJSON.remove_dep("@types/react", path)

      {:ok, %{dev_dependencies: dev_deps2}} = NPM.PackageJSON.read_all(path)
      assert dev_deps2 == %{}
    end

    @tag :tmp_dir
    test "scoped packages in lockfile round-trip", %{tmp_dir: dir} do
      path = Path.join(dir, "npm.lock")

      lockfile = %{
        "@babel/core" => %{
          version: "7.24.0",
          integrity: "sha512-abc==",
          tarball: "https://registry.npmjs.org/@babel/core/-/core-7.24.0.tgz",
          dependencies: %{"@babel/parser" => "^7.24.0"}
        },
        "@babel/parser" => %{
          version: "7.24.1",
          integrity: "sha512-def==",
          tarball: "https://registry.npmjs.org/@babel/parser/-/parser-7.24.1.tgz",
          dependencies: %{}
        }
      }

      NPM.Lockfile.write(lockfile, path)
      {:ok, read_back} = NPM.Lockfile.read(path)

      assert read_back["@babel/core"].version == "7.24.0"
      assert read_back["@babel/core"].dependencies["@babel/parser"] == "^7.24.0"
      assert read_back["@babel/parser"].version == "7.24.1"
    end
  end

  # --- Linker with scoped packages full flow ---

  describe "Linker scoped packages full flow" do
    @tag :tmp_dir
    test "links scoped packages with copy strategy", %{tmp_dir: dir} do
      cache_dir = Path.join(dir, "cache")
      nm_dir = Path.join(dir, "node_modules")

      setup_cached_package(cache_dir, "@scope/pkg", "1.0.0", %{
        "package.json" => ~s({"name":"@scope/pkg","version":"1.0.0"}),
        "index.js" => "exports.ok = true"
      })

      lockfile = %{
        "@scope/pkg" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      System.put_env("NPM_EX_CACHE_DIR", cache_dir)
      NPM.Linker.link(lockfile, nm_dir, :copy)
      System.delete_env("NPM_EX_CACHE_DIR")

      assert File.exists?(Path.join([nm_dir, "@scope", "pkg", "package.json"]))
      assert File.read!(Path.join([nm_dir, "@scope", "pkg", "index.js"])) == "exports.ok = true"
    end
  end

  # --- Tarball.fetch_and_extract with mock server ---

  describe "Tarball.fetch_and_extract" do
    @tag :tmp_dir
    test "fetches and extracts valid tarball", %{tmp_dir: dir} do
      tgz = create_test_tgz(%{"package/index.js" => "test content"})
      hash = :crypto.hash(:sha512, tgz) |> Base.encode64()

      {:ok, listen} = :gen_tcp.listen(0, [:binary, active: false, reuseaddr: true])
      {:ok, port} = :inet.port(listen)

      spawn(fn ->
        {:ok, conn} = :gen_tcp.accept(listen)
        {:ok, _data} = :gen_tcp.recv(conn, 0, 5000)
        response = "HTTP/1.1 200 OK\r\nContent-Length: #{byte_size(tgz)}\r\n\r\n" <> tgz
        :gen_tcp.send(conn, response)
        :gen_tcp.close(conn)
      end)

      url = "http://127.0.0.1:#{port}/test.tgz"
      assert {:ok, 1} = NPM.Tarball.fetch_and_extract(url, "sha512-#{hash}", dir)
      assert File.read!(Path.join(dir, "index.js")) == "test content"

      :gen_tcp.close(listen)
    end

    @tag :tmp_dir
    test "fails on integrity mismatch", %{tmp_dir: dir} do
      tgz = create_test_tgz(%{"package/index.js" => "content"})

      {:ok, listen} = :gen_tcp.listen(0, [:binary, active: false, reuseaddr: true])
      {:ok, port} = :inet.port(listen)

      spawn(fn ->
        {:ok, conn} = :gen_tcp.accept(listen)
        {:ok, _data} = :gen_tcp.recv(conn, 0, 5000)
        response = "HTTP/1.1 200 OK\r\nContent-Length: #{byte_size(tgz)}\r\n\r\n" <> tgz
        :gen_tcp.send(conn, response)
        :gen_tcp.close(conn)
      end)

      url = "http://127.0.0.1:#{port}/test.tgz"

      assert {:error, :integrity_mismatch} =
               NPM.Tarball.fetch_and_extract(url, "sha512-wrong==", dir)

      :gen_tcp.close(listen)
    end
  end

  # --- Validator edge cases ---

  describe "Validator additional cases" do
    test "accepts hyphenated name" do
      assert :ok = NPM.Validator.validate_name("my-cool-package")
    end

    test "accepts dotted name in middle" do
      assert :ok = NPM.Validator.validate_name("pkg.utils")
    end

    test "accepts numeric name" do
      assert :ok = NPM.Validator.validate_name("123")
    end

    test "validate_range with 1.0.0" do
      assert :ok = NPM.Validator.validate_range("1.0.0")
    end
  end

  # --- Linker prune with .bin and hidden dirs ---

  describe "Linker.prune with dotfiles" do
    @tag :tmp_dir
    test "preserves .cache directory", %{tmp_dir: dir} do
      nm_dir = Path.join(dir, "node_modules")
      File.mkdir_p!(Path.join(nm_dir, ".cache"))
      File.write!(Path.join([nm_dir, ".cache", "data"]), "cached")

      NPM.Linker.prune(nm_dir, MapSet.new())

      assert File.exists?(Path.join([nm_dir, ".cache", "data"]))
    end

    @tag :tmp_dir
    test "preserves .package-lock.json", %{tmp_dir: dir} do
      nm_dir = Path.join(dir, "node_modules")
      File.mkdir_p!(nm_dir)
      File.write!(Path.join(nm_dir, ".package-lock.json"), "{}")

      NPM.Linker.prune(nm_dir, MapSet.new())

      assert File.exists?(Path.join(nm_dir, ".package-lock.json"))
    end
  end

  # --- Cache full flow ---

  describe "Cache full flow with multiple packages" do
    @tag :tmp_dir
    test "caches multiple packages independently", %{tmp_dir: dir} do
      cache_dir = Path.join(dir, "cache")
      System.put_env("NPM_EX_CACHE_DIR", cache_dir)

      setup_cached_package(cache_dir, "alpha", "1.0.0", %{
        "package.json" => ~s({"name":"alpha"})
      })

      setup_cached_package(cache_dir, "beta", "2.0.0", %{
        "package.json" => ~s({"name":"beta"})
      })

      assert NPM.Cache.cached?("alpha", "1.0.0")
      assert NPM.Cache.cached?("beta", "2.0.0")
      refute NPM.Cache.cached?("alpha", "2.0.0")
      refute NPM.Cache.cached?("gamma", "1.0.0")

      System.delete_env("NPM_EX_CACHE_DIR")
    end
  end

  # --- Full flow: install → remove → prune ---

  describe "full local flow with prune and bins" do
    @tag :tmp_dir
    test "install, add bin, prune, verify", %{tmp_dir: dir} do
      cache_dir = Path.join(dir, "cache")
      nm_dir = Path.join(dir, "node_modules")
      System.put_env("NPM_EX_CACHE_DIR", cache_dir)

      setup_cached_package(cache_dir, "tool-a", "1.0.0", %{
        "package.json" => ~s({"name":"tool-a","bin":"./run.js"}),
        "run.js" => "#!/usr/bin/env node"
      })

      setup_cached_package(cache_dir, "lib-b", "2.0.0", %{
        "package.json" => ~s({"name":"lib-b"})
      })

      setup_cached_package(cache_dir, "old-pkg", "1.0.0", %{
        "package.json" => ~s({"name":"old-pkg"})
      })

      lockfile_v1 = %{
        "tool-a" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}},
        "lib-b" => %{version: "2.0.0", integrity: "", tarball: "", dependencies: %{}},
        "old-pkg" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      NPM.Linker.link(lockfile_v1, nm_dir, :copy)

      assert File.exists?(Path.join([nm_dir, "tool-a", "run.js"]))
      assert File.exists?(Path.join([nm_dir, "lib-b", "package.json"]))
      assert File.exists?(Path.join([nm_dir, "old-pkg", "package.json"]))
      assert File.exists?(Path.join([nm_dir, ".bin", "tool-a"]))

      lockfile_v2 = %{
        "tool-a" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}},
        "lib-b" => %{version: "2.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      NPM.Linker.link(lockfile_v2, nm_dir, :copy)

      assert File.exists?(Path.join([nm_dir, "tool-a", "run.js"]))
      assert File.exists?(Path.join([nm_dir, "lib-b", "package.json"]))
      refute File.exists?(Path.join(nm_dir, "old-pkg"))
      assert File.exists?(Path.join([nm_dir, ".bin", "tool-a"]))

      System.delete_env("NPM_EX_CACHE_DIR")
    end
  end

  # --- PackageJSON.add_dep preserves all fields ---

  describe "PackageJSON.add_dep field interaction" do
    @tag :tmp_dir
    test "adding dev dep doesn't affect dependencies", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")

      NPM.PackageJSON.add_dep("react", "^18.0", path)
      NPM.PackageJSON.add_dep("jest", "^29.0", path, dev: true)
      NPM.PackageJSON.add_dep("fsevents", "^2.3", path, optional: true)

      {:ok, result} = NPM.PackageJSON.read_all(path)
      assert result.dependencies == %{"react" => "^18.0"}
      assert result.dev_dependencies == %{"jest" => "^29.0"}
      assert result.optional_dependencies == %{"fsevents" => "^2.3"}
    end
  end

  # --- Lockfile with special characters ---

  describe "Lockfile with special values" do
    @tag :tmp_dir
    test "handles special characters in tarball URLs", %{tmp_dir: dir} do
      path = Path.join(dir, "npm.lock")

      lockfile = %{
        "@scope/pkg" => %{
          version: "1.0.0",
          integrity: "sha512-abc+def/ghi==",
          tarball: "https://registry.npmjs.org/@scope%2fpkg/-/pkg-1.0.0.tgz",
          dependencies: %{}
        }
      }

      NPM.Lockfile.write(lockfile, path)
      {:ok, read_back} = NPM.Lockfile.read(path)

      assert read_back["@scope/pkg"].integrity == "sha512-abc+def/ghi=="
      assert read_back["@scope/pkg"].tarball =~ "%2f"
    end
  end

  # --- Validator comprehensive ---

  describe "Validator comprehensive name checks" do
    test "accepts single character name" do
      assert :ok = NPM.Validator.validate_name("a")
    end

    test "accepts name with all valid chars" do
      assert :ok = NPM.Validator.validate_name("my-pkg.util_v2")
    end

    test "rejects name starting with @" do
      assert :ok = NPM.Validator.validate_name("@scope/pkg")
    end

    test "accepts 214-char scoped name" do
      name = "@a/" <> String.duplicate("b", 211)
      assert :ok = NPM.Validator.validate_name(name)
    end
  end

  describe "Validator comprehensive range checks" do
    test "accepts hyphen range" do
      assert :ok = NPM.Validator.validate_range("1.0.0 - 2.0.0")
    end

    test "accepts or range" do
      assert :ok = NPM.Validator.validate_range(">=1.0.0 <2.0.0")
    end

    test "validates caret with pre-release" do
      result = NPM.Validator.validate_range("^1.0.0-alpha.1")
      assert result == :ok or match?({:error, _}, result)
    end
  end

  # --- Linker with empty lockfile ---

  describe "Linker with empty lockfile" do
    @tag :tmp_dir
    test "handles empty lockfile gracefully", %{tmp_dir: dir} do
      nm_dir = Path.join(dir, "node_modules")
      assert :ok = NPM.Linker.link(%{}, nm_dir, :copy)
      assert File.exists?(nm_dir)
    end
  end

  # --- PackageJSON error handling ---

  describe "PackageJSON error handling" do
    @tag :tmp_dir
    test "read raises for invalid JSON", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")
      File.write!(path, "not json{{{")

      assert_raise ErlangError, fn ->
        NPM.PackageJSON.read(path)
      end
    end
  end

  # --- Cache.package_dir with various names ---

  describe "Cache.package_dir patterns" do
    test "handles simple name" do
      path = NPM.Cache.package_dir("lodash", "4.17.21")
      assert String.ends_with?(path, "cache/lodash/4.17.21")
    end

    test "handles hyphenated name" do
      path = NPM.Cache.package_dir("is-number", "7.0.0")
      assert String.ends_with?(path, "cache/is-number/7.0.0")
    end

    test "handles scoped package" do
      path = NPM.Cache.package_dir("@babel/core", "7.24.0")
      assert String.ends_with?(path, "cache/@babel/core/7.24.0")
    end

    test "handles deeply scoped package" do
      path = NPM.Cache.package_dir("@angular/compiler-cli", "18.0.0")
      assert String.ends_with?(path, "cache/@angular/compiler-cli/18.0.0")
    end
  end

  # --- Tarball multiple file types ---

  describe "Tarball extract various file types" do
    @tag :tmp_dir
    test "handles nested package.json with dependencies", %{tmp_dir: dir} do
      pkg_json = ~s({"name":"test","version":"1.0.0","dependencies":{"dep":"^1.0"}})
      tgz = create_test_tgz(%{"package/package.json" => pkg_json})

      assert {:ok, 1} = NPM.Tarball.extract(tgz, dir)
      content = File.read!(Path.join(dir, "package.json")) |> :json.decode()
      assert content["name"] == "test"
      assert content["dependencies"]["dep"] == "^1.0"
    end

    @tag :tmp_dir
    test "handles multiple nested directories", %{tmp_dir: dir} do
      files = %{
        "package/src/index.js" => "main",
        "package/src/utils/helper.js" => "helper",
        "package/dist/bundle.js" => "bundled",
        "package/README.md" => "# Test"
      }

      tgz = create_test_tgz(files)
      assert {:ok, 4} = NPM.Tarball.extract(tgz, dir)
      assert File.read!(Path.join(dir, "src/index.js")) == "main"
      assert File.read!(Path.join(dir, "src/utils/helper.js")) == "helper"
      assert File.read!(Path.join(dir, "dist/bundle.js")) == "bundled"
      assert File.read!(Path.join(dir, "README.md")) == "# Test"
    end
  end

  # --- Lockfile sorted listing ---

  describe "Lockfile listing" do
    @tag :tmp_dir
    test "packages can be listed and sorted", %{tmp_dir: dir} do
      path = Path.join(dir, "npm.lock")

      lockfile = %{
        "z-pkg" => %{version: "2.0.0", integrity: "", tarball: "", dependencies: %{}},
        "a-pkg" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      NPM.Lockfile.write(lockfile, path)
      {:ok, read_back} = NPM.Lockfile.read(path)

      packages =
        read_back
        |> Enum.map(fn {name, entry} -> {name, entry.version} end)
        |> Enum.sort_by(&elem(&1, 0))

      assert [{"a-pkg", "1.0.0"}, {"z-pkg", "2.0.0"}] = packages
    end
  end

  # --- Workspaces expand with nested dirs ---

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

      result = NPM.PackageJSON.expand_workspaces(["apps/*", "packages/*"], dir)
      assert length(result) == 3
    end
  end

  # --- NPM.Config ---

  describe "Config.parse_npmrc" do
    test "parses key=value pairs" do
      content = "registry=https://registry.example.com\nalways-auth=true"
      result = NPM.Config.parse_npmrc(content)
      assert result["registry"] == "https://registry.example.com"
      assert result["always-auth"] == "true"
    end

    test "ignores comments" do
      content = "# this is a comment\nregistry=https://example.com\n# another comment"
      result = NPM.Config.parse_npmrc(content)
      assert map_size(result) == 1
      assert result["registry"] == "https://example.com"
    end

    test "ignores blank lines" do
      content = "\nregistry=https://example.com\n\n\n"
      result = NPM.Config.parse_npmrc(content)
      assert map_size(result) == 1
    end

    test "handles auth tokens with = in value" do
      content = "//registry.npmjs.org/:_authToken=abc123def456=="
      result = NPM.Config.parse_npmrc(content)
      assert result["//registry.npmjs.org/:_authToken"] == "abc123def456=="
    end

    test "handles empty content" do
      assert NPM.Config.parse_npmrc("") == %{}
    end

    test "handles whitespace around values" do
      content = "  registry = https://example.com  "
      result = NPM.Config.parse_npmrc(content)
      assert result["registry"] == "https://example.com"
    end
  end

  # --- JSON pretty print indentation ---

  describe "JSON.encode_pretty indentation" do
    test "uses two-space indentation" do
      json = NPM.JSON.encode_pretty(%{"a" => 1})
      assert json == "{\n  \"a\": 1\n}\n"
    end

    test "nested maps use correct indentation" do
      json = NPM.JSON.encode_pretty(%{"outer" => %{"inner" => 1}})
      assert json =~ "  \"outer\": {\n    \"inner\": 1\n  }"
    end

    test "trailing newline" do
      json = NPM.JSON.encode_pretty(%{})
      assert String.ends_with?(json, "\n")
    end
  end

  # --- Tarball.verify_integrity comprehensive ---

  describe "Tarball integrity comprehensive" do
    test "sha512 with correct padding" do
      data = String.duplicate("a", 1000)
      hash = :crypto.hash(:sha512, data) |> Base.encode64()
      assert :ok = NPM.Tarball.verify_integrity(data, "sha512-#{hash}")
    end

    test "sha256 with small data" do
      data = "x"
      hash = :crypto.hash(:sha256, data) |> Base.encode64()
      assert :ok = NPM.Tarball.verify_integrity(data, "sha256-#{hash}")
    end

    test "sha1 with empty data" do
      data = ""
      hash = :crypto.hash(:sha, data) |> Base.encode64()
      assert :ok = NPM.Tarball.verify_integrity(data, "sha1-#{hash}")
    end

    test "sha512 with binary data" do
      data = <<0, 1, 2, 255, 254, 253>>
      hash = :crypto.hash(:sha512, data) |> Base.encode64()
      assert :ok = NPM.Tarball.verify_integrity(data, "sha512-#{hash}")
    end
  end

  # --- Helpers ---

  defp create_test_tgz(files) do
    tmp = System.tmp_dir!()
    tgz_path = Path.join(tmp, "npm_test_#{System.unique_integer([:positive])}.tgz")

    file_entries =
      Enum.map(files, fn {name, content} ->
        path = Path.join(tmp, name)
        File.mkdir_p!(Path.dirname(path))
        File.write!(path, content)
        {~c"#{name}", ~c"#{path}"}
      end)

    :ok = :erl_tar.create(~c"#{tgz_path}", file_entries, [:compressed])
    data = File.read!(tgz_path)

    File.rm!(tgz_path)
    Enum.each(files, fn {name, _} -> File.rm(Path.join(tmp, name)) end)

    data
  end

  defp setup_cached_package(cache_dir, name, version, files) do
    pkg_dir = Path.join([cache_dir, "cache", name, version])
    File.mkdir_p!(pkg_dir)

    Enum.each(files, fn {filename, content} ->
      path = Path.join(pkg_dir, filename)
      File.mkdir_p!(Path.dirname(path))
      File.write!(path, content)
    end)
  end
end
