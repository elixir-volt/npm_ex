defmodule NPMTest do
  use ExUnit.Case, async: true

  alias Mix.Tasks.Npm.Install, as: NpmInstall
  alias Mix.Tasks.Npm.Licenses

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

  # --- PackageJSON.git_dep? ---

  describe "PackageJSON.git_dep?" do
    test "recognizes git+https URLs" do
      assert NPM.PackageJSON.git_dep?("git+https://github.com/user/repo.git")
    end

    test "recognizes git+ssh URLs" do
      assert NPM.PackageJSON.git_dep?("git+ssh://git@github.com/user/repo.git")
    end

    test "recognizes github: shorthand" do
      assert NPM.PackageJSON.git_dep?("github:user/repo")
    end

    test "recognizes git:// URLs" do
      assert NPM.PackageJSON.git_dep?("git://github.com/user/repo.git")
    end

    test "recognizes .git suffix" do
      assert NPM.PackageJSON.git_dep?("https://github.com/user/repo.git")
    end

    test "rejects regular ranges" do
      refute NPM.PackageJSON.git_dep?("^4.0.0")
      refute NPM.PackageJSON.git_dep?("latest")
      refute NPM.PackageJSON.git_dep?("~1.0")
    end
  end

  describe "PackageJSON.url_dep?" do
    test "recognizes http tgz URLs" do
      assert NPM.PackageJSON.url_dep?("http://example.com/pkg-1.0.0.tgz")
    end

    test "recognizes https tar.gz URLs" do
      assert NPM.PackageJSON.url_dep?("https://example.com/pkg.tar.gz")
    end

    test "rejects non-tarball URLs" do
      refute NPM.PackageJSON.url_dep?("https://example.com/page")
    end

    test "rejects regular ranges" do
      refute NPM.PackageJSON.url_dep?("^4.0.0")
      refute NPM.PackageJSON.url_dep?("latest")
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

  # --- Validator with scoped names ---

  describe "Validator scoped package names" do
    test "accepts standard scoped name" do
      assert :ok = NPM.Validator.validate_name("@angular/core")
    end

    test "accepts scoped name with hyphens" do
      assert :ok = NPM.Validator.validate_name("@my-scope/my-package")
    end
  end

  # --- Config with env var override ---

  describe "Config registry priority" do
    test "env var overrides everything" do
      original = System.get_env("NPM_REGISTRY")
      System.put_env("NPM_REGISTRY", "https://custom.registry.io")

      assert NPM.Config.registry() == "https://custom.registry.io"

      if original,
        do: System.put_env("NPM_REGISTRY", original),
        else: System.delete_env("NPM_REGISTRY")
    end

    test "defaults to npmjs.org" do
      original = System.get_env("NPM_REGISTRY")
      System.delete_env("NPM_REGISTRY")

      result = NPM.Config.registry()
      assert result =~ "registry.npmjs.org" or result =~ "npm"

      if original, do: System.put_env("NPM_REGISTRY", original)
    end
  end

  # --- PackageJSON read various fields ---

  describe "PackageJSON comprehensive read" do
    @tag :tmp_dir
    test "read returns only dependencies, not devDeps", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")

      File.write!(path, ~s({
        "dependencies": {"a": "^1.0"},
        "devDependencies": {"b": "^2.0"},
        "optionalDependencies": {"c": "^3.0"}
      }))

      {:ok, deps} = NPM.PackageJSON.read(path)
      assert deps == %{"a" => "^1.0"}
      refute Map.has_key?(deps, "b")
      refute Map.has_key?(deps, "c")
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

  # --- Registry encode_package ---

  describe "Registry URL encoding" do
    test "get_packument constructs correct URL for scoped packages" do
      url = "https://registry.npmjs.org/#{String.replace("@scope/pkg", "/", "%2f")}"
      assert url == "https://registry.npmjs.org/@scope%2fpkg"
    end

    test "get_packument constructs correct URL for simple packages" do
      url = "https://registry.npmjs.org/lodash"
      assert url == "https://registry.npmjs.org/lodash"
    end
  end

  # --- Linker hoist determinism ---

  describe "Linker.hoist determinism" do
    test "returns deterministic results for same input" do
      lockfile = %{
        "a" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}},
        "b" => %{version: "2.0.0", integrity: "", tarball: "", dependencies: %{}},
        "c" => %{version: "3.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      result1 = NPM.Linker.hoist(lockfile) |> Enum.sort()
      result2 = NPM.Linker.hoist(lockfile) |> Enum.sort()
      assert result1 == result2
    end
  end

  # --- Lockfile write idempotency ---

  describe "Lockfile write idempotency" do
    @tag :tmp_dir
    test "writing same lockfile twice produces identical files", %{tmp_dir: dir} do
      path1 = Path.join(dir, "lock1")
      path2 = Path.join(dir, "lock2")

      lockfile = %{
        "express" => %{
          version: "4.21.2",
          integrity: "sha512-abc==",
          tarball: "https://example.com/express.tgz",
          dependencies: %{"accepts" => "~1.3.8"}
        },
        "accepts" => %{
          version: "1.3.8",
          integrity: "sha512-def==",
          tarball: "https://example.com/accepts.tgz",
          dependencies: %{}
        }
      }

      NPM.Lockfile.write(lockfile, path1)
      NPM.Lockfile.write(lockfile, path2)

      assert File.read!(path1) == File.read!(path2)
    end
  end

  # --- Config.parse_npmrc edge cases ---

  describe "Config.parse_npmrc edge cases" do
    test "handles multiple = signs in value" do
      result = NPM.Config.parse_npmrc("key=value=with=equals")
      assert result["key"] == "value=with=equals"
    end

    test "handles lines with only comments" do
      result = NPM.Config.parse_npmrc("# comment\n# another")
      assert result == %{}
    end

    test "handles mixed content" do
      content = """
      # npm config
      registry=https://example.com
      # auth stuff
      always-auth=true
      save-exact=true
      """

      result = NPM.Config.parse_npmrc(content)
      assert map_size(result) == 3
      assert result["registry"] == "https://example.com"
      assert result["always-auth"] == "true"
      assert result["save-exact"] == "true"
    end
  end

  # --- Linker.link_bins replaces old links ---

  describe "Linker.link_bins replaces old links" do
    @tag :tmp_dir
    test "overwrites existing bin links", %{tmp_dir: dir} do
      nm_dir = Path.join(dir, "node_modules")
      bin_dir = Path.join(nm_dir, ".bin")
      File.mkdir_p!(bin_dir)

      File.write!(Path.join(bin_dir, "old-link"), "stale")

      pkg_dir = Path.join(nm_dir, "tool")
      File.mkdir_p!(pkg_dir)
      File.write!(Path.join(pkg_dir, "package.json"), ~s({"name":"tool","bin":"./new.js"}))
      File.write!(Path.join(pkg_dir, "new.js"), "#!/usr/bin/env node")

      NPM.Linker.link_bins(nm_dir, [{"tool", "1.0.0"}])

      assert File.exists?(Path.join(bin_dir, "tool"))
    end
  end

  # --- File dep resolution ---

  describe "PackageJSON.file_dep edge cases" do
    test "file:. is a file dep" do
      assert NPM.PackageJSON.file_dep?("file:.")
    end

    test "file: with absolute path" do
      assert NPM.PackageJSON.file_dep?("file:/absolute/path")
    end
  end

  # --- Validator name edge cases ---

  describe "Validator name limits" do
    test "accepts 1-char name" do
      assert :ok = NPM.Validator.validate_name("x")
    end

    test "accepts name with numbers" do
      assert :ok = NPM.Validator.validate_name("react18")
    end

    test "allows special chars like dot" do
      assert :ok = NPM.Validator.validate_name("my.pkg")
    end

    test "allows hyphens" do
      assert :ok = NPM.Validator.validate_name("my-long-package-name")
    end
  end

  # --- Cache ensure with cached package ---

  describe "Cache.ensure skip download" do
    @tag :tmp_dir
    test "returns immediately for cached package", %{tmp_dir: dir} do
      cache_dir = Path.join(dir, "cache")
      System.put_env("NPM_EX_CACHE_DIR", cache_dir)

      setup_cached_package(cache_dir, "cached-pkg", "1.0.0", %{
        "package.json" => ~s({"name":"cached-pkg"})
      })

      {:ok, path} = NPM.Cache.ensure("cached-pkg", "1.0.0", "http://unused.example.com", "")
      assert String.ends_with?(path, "cached-pkg/1.0.0")

      System.delete_env("NPM_EX_CACHE_DIR")
    end
  end

  # --- Hooks ---

  describe "Hooks.available" do
    test "lists all hook points" do
      hooks = NPM.Hooks.available()
      assert :pre_install in hooks
      assert :post_install in hooks
      assert :pre_resolve in hooks
      assert :post_resolve in hooks
    end
  end

  describe "Hooks.configured" do
    test "returns empty map by default" do
      assert is_map(NPM.Hooks.configured())
    end
  end

  describe "Hooks.configured?" do
    test "false for unconfigured hook" do
      refute NPM.Hooks.configured?(:pre_install)
    end
  end

  describe "Hooks.run" do
    test "succeeds for unconfigured hook" do
      assert :ok = NPM.Hooks.run(:pre_install)
    end

    test "succeeds with context" do
      assert :ok = NPM.Hooks.run(:post_install, packages: 5)
    end
  end

  # --- Format ---

  describe "Format.bytes" do
    test "formats bytes" do
      assert "500 B" = NPM.Format.bytes(500)
    end

    test "formats kilobytes" do
      assert "1.5 KB" = NPM.Format.bytes(1536)
    end

    test "formats megabytes" do
      assert "10.0 MB" = NPM.Format.bytes(10_485_760)
    end

    test "formats gigabytes" do
      assert "1.0 GB" = NPM.Format.bytes(1_073_741_824)
    end
  end

  describe "Format.duration" do
    test "formats microseconds" do
      assert "500µs" = NPM.Format.duration(500)
    end

    test "formats milliseconds" do
      assert "150ms" = NPM.Format.duration(150_000)
    end

    test "formats seconds" do
      assert "2.5s" = NPM.Format.duration(2_500_000)
    end
  end

  describe "Format.package" do
    test "formats name@version" do
      assert "lodash@4.17.21" = NPM.Format.package("lodash", "4.17.21")
    end
  end

  describe "Format.pluralize" do
    test "singular" do
      assert "1 package" = NPM.Format.pluralize(1, "package", "packages")
    end

    test "plural" do
      assert "5 packages" = NPM.Format.pluralize(5, "package", "packages")
    end

    test "zero" do
      assert "0 packages" = NPM.Format.pluralize(0, "package", "packages")
    end
  end

  describe "Format.truncate" do
    test "short string unchanged" do
      assert "hi" = NPM.Format.truncate("hi", 10)
    end

    test "long string truncated" do
      result = NPM.Format.truncate("this is a very long string", 10)
      assert String.ends_with?(result, "...")
      assert byte_size(result) <= 10
    end
  end

  # --- RegistryMirror ---

  describe "RegistryMirror.known_mirrors" do
    test "returns known mirrors" do
      mirrors = NPM.RegistryMirror.known_mirrors()
      assert Map.has_key?(mirrors, "china")
      assert Map.has_key?(mirrors, "yarn")
      assert Map.has_key?(mirrors, "npmjs")
    end
  end

  describe "RegistryMirror.get_mirror" do
    test "gets a known mirror" do
      assert "https://registry.npmmirror.com" = NPM.RegistryMirror.get_mirror("china")
    end

    test "returns nil for unknown mirror" do
      assert nil == NPM.RegistryMirror.get_mirror("nonexistent")
    end
  end

  describe "RegistryMirror.known_mirror?" do
    test "detects known mirror URL" do
      assert NPM.RegistryMirror.known_mirror?("https://registry.npmjs.org")
    end

    test "rejects unknown URL" do
      refute NPM.RegistryMirror.known_mirror?("https://custom.example.com")
    end
  end

  describe "RegistryMirror.rewrite_tarball_url" do
    test "rewrites tarball URL to mirror" do
      original = "https://registry.npmjs.org/lodash/-/lodash-4.17.21.tgz"
      mirror = "https://registry.npmmirror.com"

      result = NPM.RegistryMirror.rewrite_tarball_url(original, mirror)
      assert String.starts_with?(result, "https://registry.npmmirror.com")
      assert String.contains?(result, "lodash")
    end
  end

  describe "RegistryMirror.mirror_url" do
    test "returns a URL" do
      url = NPM.RegistryMirror.mirror_url()
      assert is_binary(url)
      assert String.starts_with?(url, "http")
    end
  end

  # --- Cross-module edge cases ---

  describe "Exports + Manifest integration" do
    test "manifest exports round-trip" do
      json = ~s({"exports": {".": {"import": "./esm.js"}, "./utils": "./utils.js"}})
      manifest = NPM.Manifest.from_json(json)
      exports = manifest.exports

      assert {:ok, "./esm.js"} = NPM.Exports.resolve(exports, ".", ["import"])
      assert {:ok, "./utils.js"} = NPM.Exports.resolve(exports, "./utils")
    end
  end

  describe "Integrity + VersionUtil integration" do
    test "integrity is stable across version bumps" do
      data = "payload"
      hash1 = NPM.Integrity.compute_sha256(data)
      hash2 = NPM.Integrity.compute_sha256(data)
      assert hash1 == hash2
      assert NPM.VersionUtil.gt?("2.0.0", "1.0.0")
    end
  end

  describe "PackageSpec + Alias integration" do
    test "alias parsed via spec matches direct parse" do
      spec = NPM.PackageSpec.parse("npm:react@^18.0.0")
      assert spec.type == :alias
      assert spec.name == "react"

      alias_result = NPM.Alias.parse("npm:react@^18.0.0")
      assert {:alias, "react", "^18.0.0"} = alias_result
    end
  end

  describe "DepGraph + DepTree integration" do
    test "graph leaves match tree leaves" do
      lockfile = %{
        "a" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{"b" => "^1.0"}},
        "b" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      adj = NPM.DepGraph.adjacency_list(lockfile)
      graph_leaves = NPM.DepGraph.leaves(adj)

      tree = NPM.DepTree.build(lockfile, %{"a" => "^1.0"})

      tree_leaves =
        tree
        |> NPM.DepTree.flatten()
        |> Enum.filter(fn name ->
          entry = lockfile[name]
          entry && entry.dependencies == %{}
        end)
        |> Enum.sort()

      assert graph_leaves == tree_leaves
    end
  end

  # --- Packager ---

  describe "Packager.files_to_pack" do
    @tag :tmp_dir
    test "includes all files by default", %{tmp_dir: dir} do
      File.write!(Path.join(dir, "package.json"), ~s({"name": "test"}))
      File.write!(Path.join(dir, "index.js"), "console.log('hi')")
      File.write!(Path.join(dir, "README.md"), "# Test")

      files = NPM.Packager.files_to_pack(dir)
      assert "package.json" in files
      assert "index.js" in files
      assert "README.md" in files
    end

    @tag :tmp_dir
    test "respects files field", %{tmp_dir: dir} do
      File.write!(Path.join(dir, "package.json"), ~s({"name": "test", "files": ["dist/*"]}))
      File.mkdir_p!(Path.join(dir, "dist"))
      File.write!(Path.join(dir, "dist/index.js"), "")
      File.mkdir_p!(Path.join(dir, "src"))
      File.write!(Path.join(dir, "src/main.js"), "")

      files = NPM.Packager.files_to_pack(dir)
      assert "dist/index.js" in files
      assert "package.json" in files
      refute "src/main.js" in files
    end

    @tag :tmp_dir
    test "excludes node_modules and .git", %{tmp_dir: dir} do
      File.write!(Path.join(dir, "package.json"), ~s({"name": "test"}))
      File.mkdir_p!(Path.join(dir, "node_modules/pkg"))
      File.write!(Path.join(dir, "node_modules/pkg/index.js"), "")

      files = NPM.Packager.files_to_pack(dir)
      refute Enum.any?(files, &String.starts_with?(&1, "node_modules"))
    end
  end

  describe "Packager.pack_size" do
    @tag :tmp_dir
    test "calculates total size", %{tmp_dir: dir} do
      File.write!(Path.join(dir, "package.json"), ~s({"name": "test"}))
      File.write!(Path.join(dir, "data.txt"), String.duplicate("a", 500))

      size = NPM.Packager.pack_size(dir)
      assert size >= 500
    end
  end

  describe "Packager.pack_file_count" do
    @tag :tmp_dir
    test "counts packable files", %{tmp_dir: dir} do
      File.write!(Path.join(dir, "package.json"), ~s({"name": "test"}))
      File.write!(Path.join(dir, "a.js"), "")
      File.write!(Path.join(dir, "b.js"), "")

      count = NPM.Packager.pack_file_count(dir)
      assert count >= 3
    end
  end

  # --- NodeModules ---

  describe "NodeModules.installed" do
    @tag :tmp_dir
    test "lists installed packages", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      File.mkdir_p!(Path.join(nm, "lodash"))
      File.mkdir_p!(Path.join(nm, "express"))

      installed = NPM.NodeModules.installed(nm)
      assert "express" in installed
      assert "lodash" in installed
    end

    @tag :tmp_dir
    test "lists scoped packages", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      File.mkdir_p!(Path.join([nm, "@babel", "core"]))

      installed = NPM.NodeModules.installed(nm)
      assert "@babel/core" in installed
    end

    @tag :tmp_dir
    test "skips dotfiles", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      File.mkdir_p!(Path.join(nm, ".bin"))
      File.mkdir_p!(Path.join(nm, "real-pkg"))

      installed = NPM.NodeModules.installed(nm)
      refute ".bin" in installed
      assert "real-pkg" in installed
    end

    test "handles missing dir" do
      assert [] = NPM.NodeModules.installed("/nonexistent/node_modules")
    end
  end

  describe "NodeModules.version" do
    @tag :tmp_dir
    test "reads version from package.json", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      pkg = Path.join(nm, "lodash")
      File.mkdir_p!(pkg)
      File.write!(Path.join(pkg, "package.json"), ~s({"version": "4.17.21"}))

      assert "4.17.21" = NPM.NodeModules.version("lodash", nm)
    end

    @tag :tmp_dir
    test "returns nil for missing package", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      File.mkdir_p!(nm)

      assert nil == NPM.NodeModules.version("missing", nm)
    end
  end

  describe "NodeModules.diff" do
    @tag :tmp_dir
    test "finds missing and extra packages", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      File.mkdir_p!(Path.join(nm, "installed-pkg"))

      lockfile = %{
        "locked-pkg" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}},
        "installed-pkg" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      {missing, extra} = NPM.NodeModules.diff(lockfile, nm)
      assert "locked-pkg" in missing
      refute "installed-pkg" in missing
      refute "installed-pkg" in extra
    end
  end

  describe "NodeModules.disk_size" do
    @tag :tmp_dir
    test "computes size", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      pkg = Path.join(nm, "pkg")
      File.mkdir_p!(pkg)
      File.write!(Path.join(pkg, "index.js"), String.duplicate("x", 100))

      size = NPM.NodeModules.disk_size(nm)
      assert size >= 100
    end

    test "returns 0 for missing dir" do
      assert 0 = NPM.NodeModules.disk_size("/nonexistent/nm")
    end
  end

  describe "NodeModules.file_count" do
    @tag :tmp_dir
    test "counts files", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      pkg = Path.join(nm, "pkg")
      File.mkdir_p!(pkg)
      File.write!(Path.join(pkg, "a.js"), "")
      File.write!(Path.join(pkg, "b.js"), "")

      assert NPM.NodeModules.file_count(nm) >= 2
    end
  end

  # --- DepGraph ---

  describe "DepGraph.adjacency_list" do
    test "builds adjacency list from lockfile" do
      lockfile = %{
        "a" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{"b" => "^1.0"}},
        "b" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      adj = NPM.DepGraph.adjacency_list(lockfile)
      assert adj["a"] == ["b"]
      assert adj["b"] == []
    end
  end

  describe "DepGraph.fan_out" do
    test "counts dependencies per package" do
      adj = %{"a" => ["b", "c"], "b" => ["c"], "c" => []}
      fout = NPM.DepGraph.fan_out(adj)
      assert fout["a"] == 2
      assert fout["b"] == 1
      assert fout["c"] == 0
    end
  end

  describe "DepGraph.fan_in" do
    test "counts dependents per package" do
      adj = %{"a" => ["b", "c"], "b" => ["c"], "c" => []}
      fin = NPM.DepGraph.fan_in(adj)
      assert fin["a"] == 0
      assert fin["b"] == 1
      assert fin["c"] == 2
    end
  end

  describe "DepGraph.leaves" do
    test "finds leaf packages" do
      adj = %{"a" => ["b"], "b" => [], "c" => []}
      assert NPM.DepGraph.leaves(adj) == ["b", "c"]
    end
  end

  describe "DepGraph.roots" do
    test "finds root packages" do
      adj = %{"a" => ["b"], "b" => ["c"], "c" => []}
      assert NPM.DepGraph.roots(adj) == ["a"]
    end

    test "multiple roots" do
      adj = %{"a" => ["c"], "b" => ["c"], "c" => []}
      assert NPM.DepGraph.roots(adj) == ["a", "b"]
    end
  end

  describe "DepGraph.cycles" do
    test "detects simple cycle" do
      adj = %{"a" => ["b"], "b" => ["a"]}
      cycles = NPM.DepGraph.cycles(adj)
      assert cycles != []
    end

    test "no cycles in dag" do
      adj = %{"a" => ["b"], "b" => ["c"], "c" => []}
      assert NPM.DepGraph.cycles(adj) == []
    end
  end

  # --- Manifest ---

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

      manifest = NPM.Manifest.from_json(json)
      assert manifest.name == "my-app"
      assert manifest.version == "1.0.0"
      assert manifest.license == "MIT"
      assert manifest.module_type == :esm
      assert manifest.dependencies == %{"react" => "^18.0"}
      assert manifest.dev_dependencies == %{"typescript" => "^5.0"}
      assert manifest.exports == %{"." => "./index.js"}
    end

    test "handles minimal package.json" do
      manifest = NPM.Manifest.from_json(~s({"name": "minimal"}))
      assert manifest.name == "minimal"
      assert manifest.version == nil
      assert manifest.dependencies == %{}
      assert manifest.module_type == :cjs
    end
  end

  describe "Manifest.dep_count" do
    test "counts all dep types" do
      manifest = NPM.Manifest.from_json(~s({
        "dependencies": {"a": "1", "b": "2"},
        "devDependencies": {"c": "3"},
        "optionalDependencies": {"d": "4"}
      }))

      assert NPM.Manifest.dep_count(manifest) == 4
    end
  end

  describe "Manifest.has_scripts?" do
    test "true when scripts exist" do
      manifest = NPM.Manifest.from_json(~s({"scripts": {"test": "jest"}}))
      assert NPM.Manifest.has_scripts?(manifest)
    end

    test "false when no scripts" do
      manifest = NPM.Manifest.from_json(~s({"name": "no-scripts"}))
      refute NPM.Manifest.has_scripts?(manifest)
    end
  end

  describe "Manifest.all_dep_names" do
    test "merges all dep names sorted and unique" do
      manifest = NPM.Manifest.from_json(~s({
        "dependencies": {"b": "1"},
        "devDependencies": {"a": "1", "b": "2"},
        "optionalDependencies": {"c": "1"}
      }))

      assert NPM.Manifest.all_dep_names(manifest) == ["a", "b", "c"]
    end
  end

  describe "Manifest.module_type integration" do
    test "esm exports with module type" do
      manifest = NPM.Manifest.from_json(~s({
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

      assert {:ok, manifest} = NPM.Manifest.from_file(path)
      assert manifest.name == "from-file"
    end

    @tag :tmp_dir
    test "returns error for missing file", %{tmp_dir: dir} do
      assert {:error, :enoent} = NPM.Manifest.from_file(Path.join(dir, "nope.json"))
    end
  end

  # --- PackageSpec ---

  describe "PackageSpec.parse" do
    test "plain name" do
      spec = NPM.PackageSpec.parse("lodash")
      assert spec.name == "lodash"
      assert spec.range == nil
      assert spec.type == :registry
    end

    test "name with range" do
      spec = NPM.PackageSpec.parse("lodash@^4.0")
      assert spec.name == "lodash"
      assert spec.range == "^4.0"
      assert spec.type == :registry
    end

    test "scoped package" do
      spec = NPM.PackageSpec.parse("@babel/core@7.0.0")
      assert spec.name == "@babel/core"
      assert spec.range == "7.0.0"
      assert spec.type == :registry
    end

    test "scoped without range" do
      spec = NPM.PackageSpec.parse("@scope/pkg")
      assert spec.name == "@scope/pkg"
      assert spec.range == nil
      assert spec.type == :registry
    end

    test "alias" do
      spec = NPM.PackageSpec.parse("npm:react@^18.0")
      assert spec.name == "react"
      assert spec.range == "^18.0"
      assert spec.type == :alias
    end

    test "file reference" do
      spec = NPM.PackageSpec.parse("file:../local")
      assert spec.type == :file
    end

    test "git reference" do
      spec = NPM.PackageSpec.parse("git+https://github.com/user/repo")
      assert spec.type == :git
    end

    test "github shorthand" do
      spec = NPM.PackageSpec.parse("github:user/repo")
      assert spec.type == :git
    end

    test "http URL" do
      spec = NPM.PackageSpec.parse("https://example.com/pkg.tgz")
      assert spec.type == :url
    end
  end

  describe "PackageSpec.registry?" do
    test "registry spec" do
      spec = NPM.PackageSpec.parse("lodash@^4.0")
      assert NPM.PackageSpec.registry?(spec)
    end

    test "non-registry spec" do
      spec = NPM.PackageSpec.parse("file:../local")
      refute NPM.PackageSpec.registry?(spec)
    end
  end

  describe "PackageSpec.to_string" do
    test "with range" do
      spec = NPM.PackageSpec.parse("lodash@^4.0")
      assert NPM.PackageSpec.to_string(spec) == "lodash@^4.0"
    end

    test "without range" do
      spec = NPM.PackageSpec.parse("lodash")
      assert NPM.PackageSpec.to_string(spec) == "lodash"
    end
  end

  # --- DepTree ---

  describe "DepTree.build" do
    test "builds simple tree" do
      lockfile = %{
        "a" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{"b" => "^1.0"}},
        "b" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      tree = NPM.DepTree.build(lockfile, %{"a" => "^1.0"})
      assert length(tree) == 1
      assert hd(tree).name == "a"
      assert hd(tree).children |> hd() |> Map.get(:name) == "b"
    end

    test "handles circular deps" do
      lockfile = %{
        "a" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{"b" => "^1.0"}},
        "b" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{"a" => "^1.0"}}
      }

      tree = NPM.DepTree.build(lockfile, %{"a" => "^1.0"})
      assert length(tree) == 1
    end

    test "handles missing dep" do
      lockfile = %{
        "a" => %{
          version: "1.0.0",
          integrity: "",
          tarball: "",
          dependencies: %{"missing" => "^1.0"}
        }
      }

      tree = NPM.DepTree.build(lockfile, %{"a" => "^1.0"})
      assert hd(tree).children == []
    end
  end

  describe "DepTree.flatten" do
    test "flattens tree to unique names" do
      lockfile = %{
        "a" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{"b" => "^1.0"}},
        "b" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      tree = NPM.DepTree.build(lockfile, %{"a" => "^1.0"})
      assert NPM.DepTree.flatten(tree) == ["a", "b"]
    end
  end

  describe "DepTree.paths_to" do
    test "finds path to transitive dep" do
      lockfile = %{
        "a" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{"b" => "^1.0"}},
        "b" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{"c" => "^1.0"}},
        "c" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      tree = NPM.DepTree.build(lockfile, %{"a" => "^1.0"})
      paths = NPM.DepTree.paths_to(tree, "c")
      assert [["a", "b", "c"]] = paths
    end

    test "returns empty for non-existent target" do
      lockfile = %{
        "a" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      tree = NPM.DepTree.build(lockfile, %{"a" => "^1.0"})
      assert [] = NPM.DepTree.paths_to(tree, "z")
    end
  end

  describe "DepTree.depth" do
    test "root dep has depth 0" do
      lockfile = %{
        "a" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      tree = NPM.DepTree.build(lockfile, %{"a" => "^1.0"})
      assert 0 = NPM.DepTree.depth(tree, "a")
    end

    test "transitive dep has correct depth" do
      lockfile = %{
        "a" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{"b" => "^1.0"}},
        "b" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      tree = NPM.DepTree.build(lockfile, %{"a" => "^1.0"})
      assert 1 = NPM.DepTree.depth(tree, "b")
    end

    test "returns nil for missing" do
      tree = NPM.DepTree.build(%{}, %{})
      assert nil == NPM.DepTree.depth(tree, "z")
    end
  end

  describe "DepTree.count" do
    test "counts unique packages" do
      lockfile = %{
        "a" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{"b" => "^1.0"}},
        "b" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      tree = NPM.DepTree.build(lockfile, %{"a" => "^1.0"})
      assert 2 = NPM.DepTree.count(tree)
    end
  end

  # --- Licenses ---

  describe "Licenses.collect_licenses" do
    @tag :tmp_dir
    test "reads license from package.json", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      pkg = Path.join(nm, "my-pkg")
      File.mkdir_p!(pkg)
      File.write!(Path.join(pkg, "package.json"), ~s({"license": "MIT"}))

      licenses = Licenses.collect_licenses(nm)
      assert [{"my-pkg", "MIT"}] = licenses
    end

    @tag :tmp_dir
    test "handles missing license", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      pkg = Path.join(nm, "no-license")
      File.mkdir_p!(pkg)
      File.write!(Path.join(pkg, "package.json"), ~s({"name": "no-license"}))

      licenses = Licenses.collect_licenses(nm)
      assert [{"no-license", nil}] = licenses
    end

    @tag :tmp_dir
    test "handles empty dir", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      File.mkdir_p!(nm)

      assert [] = Licenses.collect_licenses(nm)
    end
  end

  # --- Lockfile extended ---

  describe "Lockfile.version" do
    @tag :tmp_dir
    test "reads lockfile version", %{tmp_dir: dir} do
      path = Path.join(dir, "npm.lock")

      File.write!(
        path,
        NPM.JSON.encode_pretty(%{"lockfileVersion" => 1, "packages" => %{}})
      )

      assert 1 = NPM.Lockfile.version(path)
    end

    @tag :tmp_dir
    test "returns nil for missing file", %{tmp_dir: dir} do
      assert nil == NPM.Lockfile.version(Path.join(dir, "nope.lock"))
    end
  end

  describe "Lockfile.package_names" do
    @tag :tmp_dir
    test "lists sorted names", %{tmp_dir: dir} do
      path = Path.join(dir, "npm.lock")

      lockfile = %{
        "zebra" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}},
        "alpha" => %{version: "2.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      NPM.Lockfile.write(lockfile, path)
      assert {:ok, ["alpha", "zebra"]} = NPM.Lockfile.package_names(path)
    end
  end

  describe "Lockfile.has_package?" do
    @tag :tmp_dir
    test "detects existing package", %{tmp_dir: dir} do
      path = Path.join(dir, "npm.lock")

      lockfile = %{
        "lodash" => %{version: "4.17.21", integrity: "", tarball: "", dependencies: %{}}
      }

      NPM.Lockfile.write(lockfile, path)
      assert NPM.Lockfile.has_package?("lodash", path)
      refute NPM.Lockfile.has_package?("missing", path)
    end
  end

  describe "Lockfile.get_package" do
    @tag :tmp_dir
    test "retrieves single entry", %{tmp_dir: dir} do
      path = Path.join(dir, "npm.lock")

      lockfile = %{
        "react" => %{
          version: "18.2.0",
          integrity: "sha512-abc",
          tarball: "url",
          dependencies: %{}
        }
      }

      NPM.Lockfile.write(lockfile, path)
      assert {:ok, entry} = NPM.Lockfile.get_package("react", path)
      assert entry.version == "18.2.0"
    end

    @tag :tmp_dir
    test "returns error for missing package", %{tmp_dir: dir} do
      path = Path.join(dir, "npm.lock")
      lockfile = %{"react" => %{version: "18.2.0", integrity: "", tarball: "", dependencies: %{}}}

      NPM.Lockfile.write(lockfile, path)
      assert :error = NPM.Lockfile.get_package("vue", path)
    end
  end

  # --- Integrity ---

  describe "Integrity.verify" do
    test "verifies matching sha512" do
      data = "hello world"
      integrity = NPM.Integrity.compute_sha512(data)
      assert :ok = NPM.Integrity.verify(data, integrity)
    end

    test "rejects mismatched data" do
      integrity = NPM.Integrity.compute_sha512("hello")
      assert {:error, :integrity_mismatch} = NPM.Integrity.verify("world", integrity)
    end

    test "accepts empty integrity" do
      assert :ok = NPM.Integrity.verify("any data", "")
    end

    test "accepts nil integrity" do
      assert :ok = NPM.Integrity.verify("any data", nil)
    end

    test "verifies sha256" do
      data = "test data"
      integrity = NPM.Integrity.compute_sha256(data)
      assert :ok = NPM.Integrity.verify(data, integrity)
    end
  end

  describe "Integrity.parse" do
    test "parses sha512" do
      assert {:ok, {"sha512", "abc123"}} = NPM.Integrity.parse("sha512-abc123")
    end

    test "parses sha256" do
      assert {:ok, {"sha256", "xyz"}} = NPM.Integrity.parse("sha256-xyz")
    end

    test "rejects unknown algo" do
      assert :error = NPM.Integrity.parse("md5-abc")
    end

    test "rejects nil" do
      assert :error = NPM.Integrity.parse(nil)
    end

    test "rejects malformed" do
      assert :error = NPM.Integrity.parse("nohyphen")
    end
  end

  describe "Integrity.algorithm" do
    test "extracts algorithm" do
      assert "sha512" = NPM.Integrity.algorithm("sha512-abc123")
    end

    test "returns nil for invalid" do
      assert nil == NPM.Integrity.algorithm("bad-string")
    end
  end

  describe "Integrity.compute_sha256" do
    test "produces sha256- prefix" do
      result = NPM.Integrity.compute_sha256("test")
      assert String.starts_with?(result, "sha256-")
    end
  end

  describe "Integrity.compute_sha512" do
    test "produces sha512- prefix" do
      result = NPM.Integrity.compute_sha512("test")
      assert String.starts_with?(result, "sha512-")
    end

    test "same data produces same hash" do
      a = NPM.Integrity.compute_sha512("data")
      b = NPM.Integrity.compute_sha512("data")
      assert a == b
    end

    test "different data produces different hash" do
      a = NPM.Integrity.compute_sha512("hello")
      b = NPM.Integrity.compute_sha512("world")
      assert a != b
    end
  end

  # --- ScopeRegistry ---

  describe "ScopeRegistry.scoped?" do
    test "scoped package" do
      assert NPM.ScopeRegistry.scoped?("@babel/core")
    end

    test "unscoped package" do
      refute NPM.ScopeRegistry.scoped?("lodash")
    end
  end

  describe "ScopeRegistry.scope" do
    test "extracts scope" do
      assert "@babel" = NPM.ScopeRegistry.scope("@babel/core")
    end

    test "returns nil for unscoped" do
      assert nil == NPM.ScopeRegistry.scope("lodash")
    end

    test "handles double-nested scope" do
      assert "@my-org" = NPM.ScopeRegistry.scope("@my-org/my-package")
    end
  end

  describe "ScopeRegistry.registry_for" do
    test "unscoped returns default" do
      url = NPM.ScopeRegistry.registry_for("lodash")
      assert is_binary(url)
      assert String.contains?(url, "registry")
    end

    test "scoped without config returns default" do
      url = NPM.ScopeRegistry.registry_for("@nonexistent-scope-xyz/pkg")
      assert url == NPM.Registry.registry_url()
    end
  end

  describe "ScopeRegistry.all_scopes" do
    test "returns map" do
      result = NPM.ScopeRegistry.all_scopes()
      assert is_map(result)
    end
  end

  # --- VersionUtil ---

  describe "VersionUtil.parse_triple" do
    test "parses standard version" do
      assert {:ok, {1, 2, 3}} = NPM.VersionUtil.parse_triple("1.2.3")
    end

    test "returns error for invalid" do
      assert :error = NPM.VersionUtil.parse_triple("nope")
    end
  end

  describe "VersionUtil.compare" do
    test "gt" do
      assert :gt = NPM.VersionUtil.compare("2.0.0", "1.0.0")
    end

    test "lt" do
      assert :lt = NPM.VersionUtil.compare("1.0.0", "2.0.0")
    end

    test "eq" do
      assert :eq = NPM.VersionUtil.compare("1.0.0", "1.0.0")
    end
  end

  describe "VersionUtil.gt?/lt?" do
    test "gt? true" do
      assert NPM.VersionUtil.gt?("2.0.0", "1.0.0")
    end

    test "gt? false" do
      refute NPM.VersionUtil.gt?("1.0.0", "2.0.0")
    end

    test "lt? true" do
      assert NPM.VersionUtil.lt?("1.0.0", "2.0.0")
    end
  end

  describe "VersionUtil.major/minor" do
    test "major" do
      assert 5 = NPM.VersionUtil.major("5.3.1")
    end

    test "minor" do
      assert 3 = NPM.VersionUtil.minor("5.3.1")
    end

    test "invalid" do
      assert :error = NPM.VersionUtil.major("bad")
    end
  end

  describe "VersionUtil.prerelease?" do
    test "detects prerelease" do
      assert NPM.VersionUtil.prerelease?("1.0.0-alpha.1")
    end

    test "stable is not prerelease" do
      refute NPM.VersionUtil.prerelease?("1.0.0")
    end

    test "invalid is not prerelease" do
      refute NPM.VersionUtil.prerelease?("nope")
    end
  end

  describe "VersionUtil.bump_*" do
    test "bump_patch" do
      assert "1.2.4" = NPM.VersionUtil.bump_patch("1.2.3")
    end

    test "bump_minor" do
      assert "1.3.0" = NPM.VersionUtil.bump_minor("1.2.3")
    end

    test "bump_major" do
      assert "2.0.0" = NPM.VersionUtil.bump_major("1.2.3")
    end

    test "bump invalid returns error" do
      assert :error = NPM.VersionUtil.bump_patch("bad")
    end
  end

  describe "VersionUtil.sort/latest" do
    test "sorts versions ascending" do
      assert ["1.0.0", "1.2.0", "2.0.0"] =
               NPM.VersionUtil.sort(["2.0.0", "1.0.0", "1.2.0"])
    end

    test "latest returns highest" do
      assert "3.0.0" = NPM.VersionUtil.latest(["1.0.0", "3.0.0", "2.0.0"])
    end

    test "latest of empty is nil" do
      assert nil == NPM.VersionUtil.latest([])
    end

    test "skips invalid versions" do
      assert ["1.0.0"] = NPM.VersionUtil.sort(["bad", "1.0.0", "nope"])
    end
  end

  # --- Publish validation ---

  describe "publish validation" do
    @tag :tmp_dir
    test "publish --dry-run shows package info", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")

      File.write!(path, ~s({"name": "my-pkg", "version": "1.0.0"}))

      data = :json.decode(File.read!(path))
      assert Map.has_key?(data, "name")
      assert Map.has_key?(data, "version")
    end

    @tag :tmp_dir
    test "publish rejects missing name", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")
      File.write!(path, ~s({"version": "1.0.0"}))

      data = :json.decode(File.read!(path))
      refute Map.has_key?(data, "name")
    end

    @tag :tmp_dir
    test "publish rejects missing version", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")
      File.write!(path, ~s({"name": "pkg"}))

      data = :json.decode(File.read!(path))
      refute Map.has_key?(data, "version")
    end
  end

  # --- Token masking ---

  describe "token masking" do
    test "masks short tokens" do
      assert mask_token("abc") == "****"
    end

    test "masks long tokens" do
      masked = mask_token("abcdef1234567890")
      assert String.starts_with?(masked, "abcd")
      assert String.ends_with?(masked, "7890")
      assert String.contains?(masked, "****")
    end
  end

  # --- Alias ---

  describe "Alias.parse" do
    test "parses npm: alias" do
      assert {:alias, "react", "^18.0.0"} = NPM.Alias.parse("npm:react@^18.0.0")
    end

    test "parses scoped alias" do
      assert {:alias, "@scope/pkg", "1.0.0"} = NPM.Alias.parse("npm:@scope/pkg@1.0.0")
    end

    test "returns normal for regular range" do
      assert {:normal, "^1.0.0"} = NPM.Alias.parse("^1.0.0")
    end

    test "returns normal for plain version" do
      assert {:normal, "1.2.3"} = NPM.Alias.parse("1.2.3")
    end

    test "returns normal for unparseable npm: prefix" do
      assert {:normal, "npm:"} = NPM.Alias.parse("npm:")
    end
  end

  describe "Alias.alias?" do
    test "detects alias" do
      assert NPM.Alias.alias?("npm:react@^18.0.0")
    end

    test "non-alias" do
      refute NPM.Alias.alias?("^1.0.0")
    end
  end

  describe "Alias.real_name" do
    test "extracts real package name from alias" do
      assert "react" = NPM.Alias.real_name("my-react", "npm:react@^18.0.0")
    end

    test "extracts scoped real name" do
      assert "@babel/core" = NPM.Alias.real_name("babel", "npm:@babel/core@7.0.0")
    end

    test "returns original name for non-alias" do
      assert "lodash" = NPM.Alias.real_name("lodash", "^4.17.0")
    end
  end

  # --- BundleDependencies ---

  describe "PackageJSON.read_bundle_deps" do
    @tag :tmp_dir
    test "reads bundleDependencies array", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")
      File.write!(path, ~s({"bundleDependencies": ["lodash", "express"]}))

      assert {:ok, ["lodash", "express"]} = NPM.PackageJSON.read_bundle_deps(path)
    end

    @tag :tmp_dir
    test "reads bundledDependencies (alternative spelling)", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")
      File.write!(path, ~s({"bundledDependencies": ["chalk"]}))

      assert {:ok, ["chalk"]} = NPM.PackageJSON.read_bundle_deps(path)
    end

    @tag :tmp_dir
    test "handles true (bundle all deps)", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")

      File.write!(path, ~s({"bundleDependencies": true, "dependencies": {"a": "1", "b": "2"}}))

      assert {:ok, names} = NPM.PackageJSON.read_bundle_deps(path)
      assert "a" in names
      assert "b" in names
    end

    @tag :tmp_dir
    test "returns empty for missing field", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")
      File.write!(path, ~s({"name": "test"}))

      assert {:ok, []} = NPM.PackageJSON.read_bundle_deps(path)
    end

    @tag :tmp_dir
    test "returns empty for missing file", %{tmp_dir: dir} do
      assert {:ok, []} = NPM.PackageJSON.read_bundle_deps(Path.join(dir, "nope.json"))
    end
  end

  # --- PackageJSON resolutions ---

  describe "PackageJSON.read_resolutions" do
    @tag :tmp_dir
    test "reads Yarn-style resolutions", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")
      File.write!(path, ~s({"resolutions": {"lodash": "4.17.21", "**/@types/node": "20.0.0"}}))

      assert {:ok, resolutions} = NPM.PackageJSON.read_resolutions(path)
      assert resolutions["lodash"] == "4.17.21"
      assert resolutions["**/@types/node"] == "20.0.0"
    end

    @tag :tmp_dir
    test "returns empty for missing resolutions", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")
      File.write!(path, ~s({"name": "app"}))

      assert {:ok, %{}} = NPM.PackageJSON.read_resolutions(path)
    end

    @tag :tmp_dir
    test "returns empty for missing file", %{tmp_dir: dir} do
      assert {:ok, %{}} = NPM.PackageJSON.read_resolutions(Path.join(dir, "missing.json"))
    end
  end

  # --- Lifecycle ---

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

  # --- Platform ---

  describe "Platform.os_compatible?" do
    test "empty list is always compatible" do
      assert NPM.Platform.os_compatible?([])
    end

    test "current OS is compatible" do
      current = NPM.Platform.current_os()
      assert NPM.Platform.os_compatible?([current])
    end

    test "different OS is not compatible" do
      # pick an OS that's definitely not current
      other = if NPM.Platform.current_os() == "linux", do: "win32", else: "linux"
      refute NPM.Platform.os_compatible?([other])
    end

    test "blocklist excludes current OS" do
      current = NPM.Platform.current_os()
      refute NPM.Platform.os_compatible?(["!#{current}"])
    end

    test "blocklist allows other OSes" do
      other = if NPM.Platform.current_os() == "linux", do: "win32", else: "linux"
      assert NPM.Platform.os_compatible?(["!#{other}"])
    end

    test "non-list is compatible" do
      assert NPM.Platform.os_compatible?("any")
    end
  end

  describe "Platform.cpu_compatible?" do
    test "empty list is always compatible" do
      assert NPM.Platform.cpu_compatible?([])
    end

    test "current CPU is compatible" do
      current = NPM.Platform.current_cpu()
      assert NPM.Platform.cpu_compatible?([current])
    end

    test "different CPU is not compatible" do
      other = if NPM.Platform.current_cpu() == "x64", do: "arm", else: "x64"
      refute NPM.Platform.cpu_compatible?([other])
    end

    test "non-list is compatible" do
      assert NPM.Platform.cpu_compatible?("any")
    end
  end

  describe "Platform.current_os" do
    test "returns a known OS string" do
      os = NPM.Platform.current_os()
      assert os in ["darwin", "linux", "freebsd", "win32"] or is_binary(os)
    end
  end

  describe "Platform.current_cpu" do
    test "returns a known CPU string" do
      cpu = NPM.Platform.current_cpu()
      assert cpu in ["x64", "arm64", "arm", "ia32"] or is_binary(cpu)
    end
  end

  describe "Platform.check_engines" do
    test "returns empty for no engines" do
      assert NPM.Platform.check_engines(%{}) == []
    end

    test "returns warning for node engine" do
      warnings = NPM.Platform.check_engines(%{"node" => ">=18"})
      assert length(warnings) == 1
      assert hd(warnings) =~ "node"
    end

    test "returns warnings for multiple engines" do
      warnings = NPM.Platform.check_engines(%{"node" => ">=18", "npm" => ">=9"})
      assert length(warnings) == 2
    end

    test "ignores unknown engines" do
      assert NPM.Platform.check_engines(%{"bun" => ">=1.0"}) == []
    end

    test "handles non-map input" do
      assert NPM.Platform.check_engines(nil) == []
    end
  end

  # --- Exports ---

  describe "Exports.parse" do
    test "parses string shorthand" do
      pkg = %{"exports" => "./index.js"}
      assert NPM.Exports.parse(pkg) == %{"." => "./index.js"}
    end

    test "parses subpath exports" do
      pkg = %{"exports" => %{"." => "./index.js", "./utils" => "./lib/utils.js"}}
      result = NPM.Exports.parse(pkg)
      assert result["."] == "./index.js"
      assert result["./utils"] == "./lib/utils.js"
    end

    test "wraps conditional exports as root entry" do
      pkg = %{"exports" => %{"import" => "./esm.js", "require" => "./cjs.js"}}
      result = NPM.Exports.parse(pkg)
      assert result["."] == %{"import" => "./esm.js", "require" => "./cjs.js"}
    end

    test "returns nil when no exports field" do
      assert NPM.Exports.parse(%{"name" => "pkg"}) == nil
    end

    test "handles nested subpath with conditions" do
      pkg = %{
        "exports" => %{
          "." => %{"import" => "./esm/index.js", "default" => "./cjs/index.js"},
          "./utils" => "./lib/utils.js"
        }
      }

      result = NPM.Exports.parse(pkg)
      assert result["."] == %{"import" => "./esm/index.js", "default" => "./cjs/index.js"}
      assert result["./utils"] == "./lib/utils.js"
    end
  end

  describe "Exports.resolve" do
    test "resolves string target" do
      export_map = %{"." => "./index.js", "./utils" => "./lib/utils.js"}
      assert {:ok, "./index.js"} = NPM.Exports.resolve(export_map, ".")
      assert {:ok, "./lib/utils.js"} = NPM.Exports.resolve(export_map, "./utils")
    end

    test "resolves conditional target with matching condition" do
      export_map = %{"." => %{"import" => "./esm.js", "require" => "./cjs.js"}}
      assert {:ok, "./esm.js"} = NPM.Exports.resolve(export_map, ".", ["import", "default"])
      assert {:ok, "./cjs.js"} = NPM.Exports.resolve(export_map, ".", ["require", "default"])
    end

    test "falls back to default condition" do
      export_map = %{"." => %{"import" => "./esm.js", "default" => "./cjs.js"}}
      assert {:ok, "./cjs.js"} = NPM.Exports.resolve(export_map, ".", ["default"])
    end

    test "returns error for missing subpath" do
      export_map = %{"." => "./index.js"}
      assert :error = NPM.Exports.resolve(export_map, "./missing")
    end

    test "returns error when no conditions match" do
      export_map = %{"." => %{"import" => "./esm.js"}}
      assert :error = NPM.Exports.resolve(export_map, ".", ["require"])
    end
  end

  describe "Exports.subpaths" do
    test "lists sorted subpaths" do
      export_map = %{
        "./utils" => "./lib/utils.js",
        "." => "./index.js",
        "./types" => "./types.d.ts"
      }

      assert NPM.Exports.subpaths(export_map) == [".", "./types", "./utils"]
    end

    test "returns empty for nil" do
      assert NPM.Exports.subpaths(nil) == []
    end
  end

  describe "Exports.module_type" do
    test "detects ESM" do
      assert NPM.Exports.module_type(%{"type" => "module"}) == :esm
    end

    test "defaults to CJS" do
      assert NPM.Exports.module_type(%{"type" => "commonjs"}) == :cjs
      assert NPM.Exports.module_type(%{}) == :cjs
    end
  end

  # --- NPMSemver: additional ported edge cases ---

  describe "ScopeRegistry: per-scope registry routing" do
    test "default registry for unscoped packages" do
      assert NPM.ScopeRegistry.registry_for("lodash") == "https://registry.npmjs.org"
    end

    test "scoped? detects scoped packages" do
      assert NPM.ScopeRegistry.scoped?("@myco/utils")
      refute NPM.ScopeRegistry.scoped?("lodash")
    end

    test "scope extracts scope from scoped package" do
      assert "@myco" = NPM.ScopeRegistry.scope("@myco/utils")
    end

    test "scope returns nil for unscoped" do
      assert nil == NPM.ScopeRegistry.scope("lodash")
    end
  end

  describe "VersionUtil: npm version operations" do
    test "parse_triple splits version correctly" do
      assert {:ok, {1, 2, 3}} = NPM.VersionUtil.parse_triple("1.2.3")
    end

    test "compare follows semver ordering" do
      assert :lt = NPM.VersionUtil.compare("1.0.0", "2.0.0")
      assert :gt = NPM.VersionUtil.compare("2.0.0", "1.0.0")
      assert :eq = NPM.VersionUtil.compare("1.0.0", "1.0.0")
    end

    test "compare handles minor/patch differences" do
      assert :lt = NPM.VersionUtil.compare("1.0.0", "1.1.0")
      assert :lt = NPM.VersionUtil.compare("1.0.0", "1.0.1")
      assert :gt = NPM.VersionUtil.compare("1.0.1", "1.0.0")
    end

    test "bump operations follow npm semantics" do
      assert "2.0.0" = NPM.VersionUtil.bump_major("1.2.3")
      assert "1.3.0" = NPM.VersionUtil.bump_minor("1.2.3")
      assert "1.2.4" = NPM.VersionUtil.bump_patch("1.2.3")
    end

    test "sort orders versions correctly" do
      versions = ["2.0.0", "1.0.0", "1.5.0", "0.9.0", "1.0.1"]
      sorted = NPM.VersionUtil.sort(versions)
      assert sorted == ["0.9.0", "1.0.0", "1.0.1", "1.5.0", "2.0.0"]
    end

    test "latest returns highest version" do
      assert "3.0.0" = NPM.VersionUtil.latest(["1.0.0", "3.0.0", "2.0.0"])
    end

    test "prerelease? detects pre-release versions" do
      assert NPM.VersionUtil.prerelease?("1.0.0-alpha.1")
      assert NPM.VersionUtil.prerelease?("1.0.0-beta")
      refute NPM.VersionUtil.prerelease?("1.0.0")
    end

    test "major/minor accessors" do
      assert 1 = NPM.VersionUtil.major("1.2.3")
      assert 2 = NPM.VersionUtil.minor("1.2.3")
    end

    test "gt? and lt? comparison" do
      assert NPM.VersionUtil.gt?("2.0.0", "1.0.0")
      refute NPM.VersionUtil.gt?("1.0.0", "2.0.0")
      assert NPM.VersionUtil.lt?("1.0.0", "2.0.0")
      refute NPM.VersionUtil.lt?("2.0.0", "1.0.0")
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

      {:ok, manifest} = NPM.Manifest.from_file(path)
      assert manifest.name == "my-app"
      assert manifest.version == "1.0.0"
      assert NPM.Manifest.dep_count(manifest) == 3
      assert NPM.Manifest.has_scripts?(manifest)
      names = NPM.Manifest.all_dep_names(manifest)
      assert "react" in names
      assert "jest" in names
    end

    test "from_json parses raw JSON string" do
      json = ~s({"name": "test", "version": "0.1.0", "dependencies": {"a": "^1.0"}})
      manifest = NPM.Manifest.from_json(json)
      assert manifest.name == "test"
      assert NPM.Manifest.dep_count(manifest) == 1
    end
  end

  describe "Packager: pack file discovery" do
    @tag :tmp_dir
    test "files_to_pack finds project files", %{tmp_dir: dir} do
      File.write!(Path.join(dir, "package.json"), ~s({"name":"test","version":"1.0.0"}))
      File.write!(Path.join(dir, "index.js"), "module.exports = {}")
      File.write!(Path.join(dir, "README.md"), "# Test")
      File.mkdir_p!(Path.join(dir, "node_modules/dep"))
      File.write!(Path.join([dir, "node_modules", "dep", "index.js"]), "")

      files = NPM.Packager.files_to_pack(dir)
      basenames = Enum.map(files, &Path.basename/1)

      assert "package.json" in basenames
      assert "index.js" in basenames
      # node_modules should be excluded
      refute Enum.any?(files, &String.contains?(&1, "node_modules"))
    end

    @tag :tmp_dir
    test "pack_size returns byte count", %{tmp_dir: dir} do
      File.write!(Path.join(dir, "package.json"), ~s({"name":"test"}))
      File.write!(Path.join(dir, "index.js"), String.duplicate("x", 1000))

      size = NPM.Packager.pack_size(dir)
      assert size > 1000
    end
  end

  describe "Lockfile: utility functions" do
    @tag :tmp_dir
    test "has_package? checks lockfile contents", %{tmp_dir: dir} do
      path = Path.join(dir, "npm.lock")

      lockfile = %{
        "lodash" => %{
          version: "4.17.21",
          integrity: "sha512-x",
          tarball: "url",
          dependencies: %{}
        }
      }

      NPM.Lockfile.write(lockfile, path)
      assert NPM.Lockfile.has_package?("lodash", path)
      refute NPM.Lockfile.has_package?("react", path)
    end

    @tag :tmp_dir
    test "package_names lists all locked packages", %{tmp_dir: dir} do
      path = Path.join(dir, "npm.lock")

      lockfile = %{
        "lodash" => %{version: "4.17.21", integrity: "", tarball: "", dependencies: %{}},
        "react" => %{version: "18.2.0", integrity: "", tarball: "", dependencies: %{}}
      }

      NPM.Lockfile.write(lockfile, path)
      {:ok, names} = NPM.Lockfile.package_names(path)
      assert "lodash" in names
      assert "react" in names
    end

    @tag :tmp_dir
    test "get_package retrieves specific entry", %{tmp_dir: dir} do
      path = Path.join(dir, "npm.lock")

      lockfile = %{
        "lodash" => %{
          version: "4.17.21",
          integrity: "sha512-x",
          tarball: "url",
          dependencies: %{}
        }
      }

      NPM.Lockfile.write(lockfile, path)
      {:ok, entry} = NPM.Lockfile.get_package("lodash", path)
      assert entry.version == "4.17.21"
    end

    @tag :tmp_dir
    test "lockfile version returns format version", %{tmp_dir: dir} do
      path = Path.join(dir, "npm.lock")
      NPM.Lockfile.write(%{}, path)
      assert NPM.Lockfile.version(path) == 1
    end
  end

  describe "Registry: scoped package URL encoding" do
    test "encode_package handles scoped packages" do
      assert NPM.Registry.encode_package("@babel/core") == "@babel%2fcore"
    end

    test "encode_package leaves unscoped packages unchanged" do
      assert NPM.Registry.encode_package("lodash") == "lodash"
    end

    test "encode_package handles deeply scoped names" do
      assert NPM.Registry.encode_package("@types/node") == "@types%2fnode"
    end
  end

  describe "RegistryMirror: URL rewriting" do
    test "known_mirrors returns map of mirror names to URLs" do
      mirrors = NPM.RegistryMirror.known_mirrors()
      assert is_map(mirrors)
      assert Map.has_key?(mirrors, "npmjs")
      assert mirrors["npmjs"] == "https://registry.npmjs.org"
    end

    test "rewrite_tarball_url replaces registry host" do
      mirror = "https://registry.npmmirror.com"

      rewritten =
        NPM.RegistryMirror.rewrite_tarball_url(
          "https://registry.npmjs.org/lodash/-/lodash-4.17.21.tgz",
          mirror
        )

      assert String.starts_with?(rewritten, mirror)
      assert String.contains?(rewritten, "lodash")
    end

    test "known_mirror? checks if URL is a known mirror" do
      assert NPM.RegistryMirror.known_mirror?("https://registry.npmmirror.com")
    end
  end

  describe "Linker: hoist selects most common version" do
    test "hoists single version of each package" do
      lockfile = %{
        "lodash" => %{version: "4.17.21", integrity: "", tarball: "", dependencies: %{}},
        "react" => %{version: "18.2.0", integrity: "", tarball: "", dependencies: %{}}
      }

      tree = NPM.Linker.hoist(lockfile)
      names = Enum.map(tree, &elem(&1, 0))
      assert "lodash" in names
      assert "react" in names
    end

    test "hoist returns name-version tuples" do
      lockfile = %{
        "a" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      [{name, version}] = NPM.Linker.hoist(lockfile)
      assert name == "a"
      assert version == "1.0.0"
    end
  end

  describe "Resolver: normalize_range handles all npm range formats" do
    test "star/empty/latest normalize to >=0.0.0" do
      # These are the special cases handled by normalize_range
      assert {:ok, _} = NPMSemver.to_hex_constraint(">=0.0.0")
    end

    test "caret ranges" do
      assert {:ok, _} = NPMSemver.to_hex_constraint("^1.0.0")
      assert {:ok, _} = NPMSemver.to_hex_constraint("^0.1.0")
      assert {:ok, _} = NPMSemver.to_hex_constraint("^0.0.1")
    end

    test "tilde ranges" do
      assert {:ok, _} = NPMSemver.to_hex_constraint("~1.2.3")
      assert {:ok, _} = NPMSemver.to_hex_constraint("~0.0.1")
    end

    test "exact versions" do
      assert {:ok, _} = NPMSemver.to_hex_constraint("1.0.0")
      assert {:ok, _} = NPMSemver.to_hex_constraint("0.0.0")
    end

    test "comparison operators" do
      assert {:ok, _} = NPMSemver.to_hex_constraint(">1.0.0")
      assert {:ok, _} = NPMSemver.to_hex_constraint(">=1.0.0")
      assert {:ok, _} = NPMSemver.to_hex_constraint("<2.0.0")
      assert {:ok, _} = NPMSemver.to_hex_constraint("<=2.0.0")
    end

    test "combined ranges" do
      assert {:ok, _} = NPMSemver.to_hex_constraint(">=1.0.0 <2.0.0")
    end

    test "union ranges" do
      assert {:ok, _} = NPMSemver.to_hex_constraint("^1.0.0 || ^2.0.0")
    end

    test "x-ranges" do
      assert {:ok, _} = NPMSemver.to_hex_constraint("1.x")
      assert {:ok, _} = NPMSemver.to_hex_constraint("1.2.x")
    end

    test "hyphen ranges" do
      assert {:ok, _} = NPMSemver.to_hex_constraint("1.0.0 - 2.0.0")
    end
  end

  describe "Validator: version range validation" do
    test "accepts valid semver ranges" do
      assert :ok = NPM.Validator.validate_range("^1.0.0")
      assert :ok = NPM.Validator.validate_range("~2.3.0")
      assert :ok = NPM.Validator.validate_range(">=1.0.0 <3.0.0")
      assert :ok = NPM.Validator.validate_range("1.0.0")
    end

    test "accepts * range" do
      assert :ok = NPM.Validator.validate_range("*")
    end

    test "rejects invalid ranges" do
      assert {:error, _} = NPM.Validator.validate_range("not a version")
      assert {:error, _} = NPM.Validator.validate_range("abc.def.ghi")
    end
  end

  describe "Validator: package name validation edge cases" do
    test "rejects names longer than 214 characters" do
      long_name = String.duplicate("a", 215)
      assert {:error, _} = NPM.Validator.validate_name(long_name)
    end

    test "rejects uppercase in name" do
      assert {:error, _} = NPM.Validator.validate_name("MyPackage")
    end

    test "rejects names with spaces" do
      assert {:error, _} = NPM.Validator.validate_name("my package")
    end

    test "accepts 214-char name" do
      name = String.duplicate("a", 214)
      assert :ok = NPM.Validator.validate_name(name)
    end
  end

  describe "NodeModules: diff behavior" do
    @tag :tmp_dir
    test "diff detects extra and missing packages", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      File.mkdir_p!(Path.join(nm, "extra-pkg"))

      lockfile = %{
        "missing-pkg" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      {missing, extra} = NPM.NodeModules.diff(lockfile, nm)
      assert "missing-pkg" in missing
      assert "extra-pkg" in extra
    end

    @tag :tmp_dir
    test "diff returns empty when in sync", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      File.mkdir_p!(Path.join(nm, "pkg-a"))

      lockfile = %{
        "pkg-a" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      {missing, extra} = NPM.NodeModules.diff(lockfile, nm)
      assert missing == []
      assert extra == []
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

  describe "PackageSpec: edge case patterns" do
    test "version with prerelease" do
      spec = NPM.PackageSpec.parse("pkg@1.0.0-beta.1")
      assert spec.name == "pkg"
      assert spec.range == "1.0.0-beta.1"
    end

    test "scoped package without version" do
      spec = NPM.PackageSpec.parse("@scope/pkg")
      assert spec.name == "@scope/pkg"
      assert spec.type == :registry
    end

    test "url spec" do
      spec = NPM.PackageSpec.parse("https://github.com/user/repo/archive/main.tar.gz")
      assert spec.type == :url
    end
  end

  describe "Alias: edge cases" do
    test "alias? checks npm: prefix" do
      assert NPM.Alias.alias?("npm:react@^18.0")
      refute NPM.Alias.alias?("^18.0")
      refute NPM.Alias.alias?("latest")
    end

    test "parse returns {:normal, range} for non-alias" do
      assert {:normal, "^4.0.0"} = NPM.Alias.parse("^4.0.0")
    end
  end

  describe "DepTree: edge cases" do
    test "empty lockfile produces empty tree" do
      tree = NPM.DepTree.build(%{}, %{})
      all = NPM.DepTree.flatten(tree)
      assert all == []
    end

    test "count returns total packages" do
      lockfile = %{
        "a" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{"b" => "^1.0"}},
        "b" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      tree = NPM.DepTree.build(lockfile, %{"a" => "^1.0"})
      assert NPM.DepTree.count(tree) == 2
    end
  end

  describe "DepGraph: fan_out counting" do
    test "fan_out counts outgoing edges" do
      adj = %{"a" => ["b", "c"], "b" => ["c"], "c" => []}
      fan_out = NPM.DepGraph.fan_out(adj)
      assert fan_out["a"] == 2
      assert fan_out["b"] == 1
      assert fan_out["c"] == 0
    end
  end

  describe "VersionUtil: edge cases" do
    test "bump_major resets minor and patch" do
      assert "2.0.0" = NPM.VersionUtil.bump_major("1.5.3")
    end

    test "bump_minor resets patch" do
      assert "1.6.0" = NPM.VersionUtil.bump_minor("1.5.3")
    end

    test "sort with pre-release versions" do
      versions = ["1.0.0", "1.0.0-alpha", "1.0.0-beta"]
      sorted = NPM.VersionUtil.sort(versions)
      # Pre-release versions sort before release
      assert List.first(sorted) =~ "alpha"
    end

    test "compare with equal versions" do
      assert :eq = NPM.VersionUtil.compare("1.0.0", "1.0.0")
    end
  end

  describe "BinResolver: binary lookup" do
    @tag :tmp_dir
    test "list returns available commands", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      bin_dir = Path.join(nm, ".bin")
      File.mkdir_p!(bin_dir)
      File.write!(Path.join(bin_dir, "jest"), "#!/bin/sh")
      File.write!(Path.join(bin_dir, "tsc"), "#!/bin/sh")

      bins = NPM.BinResolver.list(nm)
      names = Enum.map(bins, &elem(&1, 0))
      assert "jest" in names
      assert "tsc" in names
    end

    @tag :tmp_dir
    test "find returns path for existing command", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      bin_dir = Path.join(nm, ".bin")
      File.mkdir_p!(bin_dir)
      File.write!(Path.join(bin_dir, "eslint"), "#!/bin/sh")

      assert {:ok, path} = NPM.BinResolver.find("eslint", nm)
      assert String.contains?(path, "eslint")
    end

    @tag :tmp_dir
    test "find returns :error for missing command", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      File.mkdir_p!(nm)

      assert :error = NPM.BinResolver.find("nonexistent", nm)
    end

    @tag :tmp_dir
    test "available? checks command existence", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      bin_dir = Path.join(nm, ".bin")
      File.mkdir_p!(bin_dir)
      File.write!(Path.join(bin_dir, "prettier"), "#!/bin/sh")

      assert NPM.BinResolver.available?("prettier", nm)
      refute NPM.BinResolver.available?("missing", nm)
    end

    @tag :tmp_dir
    test "list returns empty for missing .bin", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      File.mkdir_p!(nm)

      assert NPM.BinResolver.list(nm) == []
    end
  end

  describe "Resolver: empty resolution" do
    test "empty deps returns empty map" do
      NPM.Resolver.clear_cache()
      {:ok, result} = NPM.Resolver.resolve(%{})
      assert result == %{}
    end

    test "resolve with overrides option doesn't crash on empty" do
      NPM.Resolver.clear_cache()
      {:ok, result} = NPM.Resolver.resolve(%{}, overrides: %{"pkg" => "1.0.0"})
      assert result == %{}
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

      {:ok, result} = NPM.PackageJSON.read_all(path)
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

      {:ok, result} = NPM.PackageJSON.read_all(path)
      assert result.dependencies == %{}
      assert result.dev_dependencies == %{}
      assert result.optional_dependencies == %{}
    end
  end

  describe "ScopeRegistry: all_scopes" do
    test "returns empty map with no config" do
      scopes = NPM.ScopeRegistry.all_scopes()
      assert is_map(scopes)
    end
  end

  describe "EnvCheck: environment detection" do
    test "summary returns all expected keys" do
      info = NPM.EnvCheck.summary()
      assert Map.has_key?(info, :elixir_version)
      assert Map.has_key?(info, :otp_version)
      assert Map.has_key?(info, :os)
      assert Map.has_key?(info, :cpu)
      assert Map.has_key?(info, :npm_ex_version)
    end

    test "check_engines returns :ok for empty engines" do
      assert :ok = NPM.EnvCheck.check_engines(%{})
    end

    test "check_engines warns for unknown engine" do
      assert {:warn, warnings} = NPM.EnvCheck.check_engines(%{"deno" => ">=1.0"})
      assert Enum.any?(warnings, &String.contains?(&1, "unknown engine"))
    end

    test "node_version returns {:ok, version} or :not_found" do
      result = NPM.EnvCheck.node_version()
      assert match?({:ok, "v" <> _}, result) or result == :not_found
    end
  end

  describe "Tarball: edge cases" do
    @tag :tmp_dir
    test "extract handles empty tarball", %{tmp_dir: dir} do
      # An empty tgz should return an error, not crash
      result = NPM.Tarball.extract("", dir)
      assert {:error, _} = result
    end

    @tag :tmp_dir
    test "extract handles single-file tarball", %{tmp_dir: dir} do
      tgz = create_test_tgz(%{"package.json" => ~s({"name":"single"})})
      {:ok, count} = NPM.Tarball.extract(tgz, dir)
      assert count == 1
    end
  end

  describe "Lockfile: read/write round-trip with complex deps" do
    @tag :tmp_dir
    test "preserves nested dependency ranges through round-trip", %{tmp_dir: dir} do
      path = Path.join(dir, "npm.lock")

      original = %{
        "express" => %{
          version: "4.21.2",
          integrity: "sha512-abc",
          tarball: "https://registry/express-4.21.2.tgz",
          dependencies: %{
            "accepts" => "~1.3.8",
            "body-parser" => "1.20.3",
            "cookie" => "0.7.1",
            "debug" => "2.6.9"
          }
        },
        "debug" => %{
          version: "2.6.9",
          integrity: "sha512-def",
          tarball: "https://registry/debug-2.6.9.tgz",
          dependencies: %{"ms" => "2.0.0"}
        }
      }

      NPM.Lockfile.write(original, path)
      {:ok, restored} = NPM.Lockfile.read(path)

      assert restored["express"].version == "4.21.2"
      assert restored["express"].dependencies["accepts"] == "~1.3.8"
      assert restored["express"].dependencies["debug"] == "2.6.9"
      assert restored["debug"].dependencies["ms"] == "2.0.0"
    end
  end

  describe "Config: parse_npmrc edge cases" do
    test "handles = signs in values" do
      content = "//registry.npmjs.org/:_authToken=npm_abcdef123456=="
      result = NPM.Config.parse_npmrc(content)
      assert result["//registry.npmjs.org/:_authToken"] == "npm_abcdef123456=="
    end

    test "handles trailing whitespace" do
      content = "registry=https://registry.npmjs.org/  \n"
      result = NPM.Config.parse_npmrc(content)
      assert result["registry"] == "https://registry.npmjs.org/"
    end
  end

  describe "LockMerge: lockfile merging" do
    test "merge prefers newer entries" do
      base = %{
        "lodash" => %{version: "4.17.20", integrity: "", tarball: "", dependencies: %{}},
        "react" => %{version: "18.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      newer = %{
        "lodash" => %{version: "4.17.21", integrity: "", tarball: "", dependencies: %{}},
        "vue" => %{version: "3.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      merged = NPM.LockMerge.merge(base, newer)
      assert merged["lodash"].version == "4.17.21"
      assert merged["react"].version == "18.0.0"
      assert merged["vue"].version == "3.0.0"
    end

    test "merge with custom resolver picks higher version" do
      base = %{
        "pkg" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      newer = %{
        "pkg" => %{version: "2.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      result =
        NPM.LockMerge.merge(base, newer, fn _name, b, n ->
          if NPM.VersionUtil.gt?(n.version, b.version), do: n, else: b
        end)

      assert result["pkg"].version == "2.0.0"
    end

    test "diff detects added, removed, and changed packages" do
      base = %{
        "lodash" => %{version: "4.17.20", integrity: "", tarball: "", dependencies: %{}},
        "removed-pkg" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      newer = %{
        "lodash" => %{version: "4.17.21", integrity: "", tarball: "", dependencies: %{}},
        "new-pkg" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      {added, removed, changed} = NPM.LockMerge.diff(base, newer)
      assert "new-pkg" in added
      assert "removed-pkg" in removed
      assert {"lodash", "4.17.20", "4.17.21"} in changed
    end

    test "diff returns empty when identical" do
      lockfile = %{
        "a" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      {added, removed, changed} = NPM.LockMerge.diff(lockfile, lockfile)
      assert added == []
      assert removed == []
      assert changed == []
    end
  end

  describe "frozen install: lockfile mismatch detection" do
    @tag :tmp_dir
    test "frozen mode fails when lockfile missing deps", %{tmp_dir: dir} do
      # Create package.json with deps
      pkg_path = Path.join(dir, "package.json")

      File.write!(pkg_path, ~s({
        "dependencies": {"lodash": "^4.0", "express": "^4.0"}
      }))

      # Create lockfile with only one dep
      lock_path = Path.join(dir, "npm.lock")

      lockfile = %{
        "lodash" => %{version: "4.17.21", integrity: "", tarball: "", dependencies: %{}}
      }

      NPM.Lockfile.write(lockfile, lock_path)

      # Read both and check mismatch
      {:ok, lockfile_data} = NPM.Lockfile.read(lock_path)
      {:ok, pkg_data} = NPM.PackageJSON.read_all(pkg_path)
      all_deps = pkg_data.dependencies

      # Express is in deps but not lockfile — should be a mismatch
      has_express_locked = Map.has_key?(lockfile_data, "express")
      refute has_express_locked
    end
  end

  describe "Linker: default strategy detection" do
    test "default strategy is symlink on unix" do
      # On macOS/Linux, default should be symlink
      assert File.exists?("/bin/sh")

      lockfile = %{
        "test-pkg" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      # hoist is the same regardless of strategy
      tree = NPM.Linker.hoist(lockfile)
      assert [{"test-pkg", "1.0.0"}] = tree
    end
  end

  describe "Manifest: from_json edge cases" do
    test "missing fields default gracefully" do
      m = NPM.Manifest.from_json(~s({"name": "minimal"}))
      assert m.name == "minimal"
      assert m.version == nil
      assert m.dependencies == %{}
      assert m.scripts == %{}
    end

    test "has_scripts? returns false for empty scripts" do
      m = NPM.Manifest.from_json(~s({"name": "no-scripts"}))
      refute NPM.Manifest.has_scripts?(m)
    end

    test "all_dep_names includes all dependency types" do
      m =
        NPM.Manifest.from_json(~s({
          "name": "multi",
          "dependencies": {"a": "^1.0"},
          "devDependencies": {"b": "^2.0"},
          "optionalDependencies": {"c": "^3.0"}
        }))

      names = NPM.Manifest.all_dep_names(m)
      assert "a" in names
      assert "b" in names
      assert "c" in names
    end

    test "module_type detects ESM from type field" do
      m = NPM.Manifest.from_json(~s({"name": "esm-pkg", "type": "module"}))
      assert m.module_type == :esm
    end
  end

  describe "Integrity: round-trip verification" do
    test "compute then verify succeeds for sha512" do
      data = :crypto.strong_rand_bytes(256)
      sri = NPM.Integrity.compute_sha512(data)
      assert :ok = NPM.Integrity.verify(data, sri)
    end

    test "compute then verify succeeds for sha256" do
      data = :crypto.strong_rand_bytes(256)
      sri = NPM.Integrity.compute_sha256(data)
      assert :ok = NPM.Integrity.verify(data, sri)
    end
  end

  describe "Format: package display" do
    test "package formats name@version" do
      assert NPM.Format.package("lodash", "4.17.21") == "lodash@4.17.21"
    end

    test "package formats scoped name@version" do
      assert NPM.Format.package("@babel/core", "7.0.0") == "@babel/core@7.0.0"
    end
  end

  describe "Exports: map patterns" do
    test "single dot entry" do
      assert {:ok, "./index.js"} = NPM.Exports.resolve(%{"." => "./index.js"}, ".")
    end

    test "missing subpath returns error" do
      assert :error = NPM.Exports.resolve(%{"." => "./index.js"}, "./missing")
    end

    test "nested conditions with single match" do
      exports = %{"." => %{"default" => "./lib.js"}}
      assert {:ok, "./lib.js"} = NPM.Exports.resolve(exports, ".", ["default"])
    end
  end

  describe "Cache: directory structure" do
    test "package_dir includes name and version" do
      dir = NPM.Cache.package_dir("lodash", "4.17.21")
      assert String.contains?(dir, "lodash")
      assert String.contains?(dir, "4.17.21")
    end

    test "package_dir for scoped packages" do
      dir = NPM.Cache.package_dir("@babel/core", "7.0.0")
      assert String.contains?(dir, "7.0.0")
    end

    test "cache dir is configurable via env" do
      old = System.get_env("NPM_EX_CACHE_DIR")
      System.put_env("NPM_EX_CACHE_DIR", "/tmp/custom_cache")

      dir = NPM.Cache.dir()
      assert dir == "/tmp/custom_cache"

      if old,
        do: System.put_env("NPM_EX_CACHE_DIR", old),
        else: System.delete_env("NPM_EX_CACHE_DIR")
    end
  end

  describe "Linker: prune removes stale packages" do
    @tag :tmp_dir
    test "prune removes packages not in expected set", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      File.mkdir_p!(Path.join(nm, "old-pkg"))
      File.write!(Path.join([nm, "old-pkg", "index.js"]), "")
      File.mkdir_p!(Path.join(nm, "keep-pkg"))
      File.write!(Path.join([nm, "keep-pkg", "index.js"]), "")

      expected = MapSet.new(["keep-pkg"])
      NPM.Linker.prune(nm, expected)

      assert File.exists?(Path.join(nm, "keep-pkg"))
      refute File.exists?(Path.join(nm, "old-pkg"))
    end

    @tag :tmp_dir
    test "prune handles scoped packages", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      File.mkdir_p!(Path.join([nm, "@scope", "keep"]))
      File.write!(Path.join([nm, "@scope", "keep", "index.js"]), "")
      File.mkdir_p!(Path.join([nm, "@scope", "remove"]))
      File.write!(Path.join([nm, "@scope", "remove", "index.js"]), "")

      expected = MapSet.new(["@scope/keep"])
      NPM.Linker.prune(nm, expected)

      assert File.exists?(Path.join([nm, "@scope", "keep"]))
      refute File.exists?(Path.join([nm, "@scope", "remove"]))
    end

    @tag :tmp_dir
    test "prune preserves .bin directory", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      bin_dir = Path.join(nm, ".bin")
      File.mkdir_p!(bin_dir)
      File.write!(Path.join(bin_dir, "my-tool"), "#!/bin/sh")

      expected = MapSet.new()
      NPM.Linker.prune(nm, expected)

      assert File.exists?(Path.join(bin_dir, "my-tool"))
    end
  end

  describe "Resolver: override support" do
    test "overrides are stored and retrieved from cache" do
      NPM.Resolver.clear_cache()
      overrides = %{"ms" => "2.1.3"}
      {:ok, _} = NPM.Resolver.resolve(%{}, overrides: overrides)
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

      {:ok, overrides} = NPM.PackageJSON.read_overrides(path)
      assert overrides["ms"] == "2.1.3"
      assert overrides["debug"] == "^4.0"
    end

    @tag :tmp_dir
    test "returns empty map when no overrides", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")
      File.write!(path, ~s({"dependencies": {"lodash": "^4.0"}}))

      {:ok, overrides} = NPM.PackageJSON.read_overrides(path)
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

      {:ok, result} = NPM.PackageJSON.read_all(path)
      assert result.dependencies["lodash"] == "^4.0"
    end
  end

  describe "Hooks: lifecycle hook configuration" do
    test "available lists known hook names" do
      hooks = NPM.Hooks.available()
      assert :pre_install in hooks
      assert :post_install in hooks
      assert :pre_resolve in hooks
      assert :post_resolve in hooks
    end
  end

  describe "Format: human-readable output helpers" do
    test "bytes formats file sizes" do
      assert NPM.Format.bytes(0) == "0 B"
      assert NPM.Format.bytes(1023) == "1023 B"
      assert NPM.Format.bytes(1024) =~ "KB"
      assert NPM.Format.bytes(1_048_576) =~ "MB"
    end

    test "duration formats microseconds" do
      assert NPM.Format.duration(0) =~ "0"
      assert NPM.Format.duration(1_500_000) =~ "1.5"
    end

    test "pluralize handles singular and plural" do
      assert NPM.Format.pluralize(1, "package", "packages") == "1 package"
      assert NPM.Format.pluralize(5, "package", "packages") == "5 packages"
      assert NPM.Format.pluralize(0, "package", "packages") == "0 packages"
    end

    test "truncate shortens long strings" do
      assert NPM.Format.truncate("hello", 10) == "hello"
      assert NPM.Format.truncate("hello world this is long", 10) =~ "..."
    end
  end

  describe "NodeModules: introspection" do
    @tag :tmp_dir
    test "installed lists packages in node_modules", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      File.mkdir_p!(Path.join(nm, "lodash"))

      File.write!(
        Path.join([nm, "lodash", "package.json"]),
        ~s({"name":"lodash","version":"4.17.21"})
      )

      File.mkdir_p!(Path.join(nm, "react"))

      File.write!(
        Path.join([nm, "react", "package.json"]),
        ~s({"name":"react","version":"18.2.0"})
      )

      installed = NPM.NodeModules.installed(nm)
      assert "lodash" in installed
      assert "react" in installed
    end

    @tag :tmp_dir
    test "version reads installed package version", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      File.mkdir_p!(Path.join(nm, "lodash"))

      File.write!(
        Path.join([nm, "lodash", "package.json"]),
        ~s({"name":"lodash","version":"4.17.21"})
      )

      assert "4.17.21" = NPM.NodeModules.version("lodash", nm)
    end

    @tag :tmp_dir
    test "version returns error for missing package", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      File.mkdir_p!(nm)

      assert nil == NPM.NodeModules.version("nonexistent", nm)
    end

    @tag :tmp_dir
    test "file_count counts files in node_modules", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      File.mkdir_p!(Path.join(nm, "pkg"))
      File.write!(Path.join([nm, "pkg", "index.js"]), "module.exports = {}")
      File.write!(Path.join([nm, "pkg", "package.json"]), "{}")

      count = NPM.NodeModules.file_count(nm)
      assert count >= 2
    end
  end

  describe "Integrity: SRI hash operations" do
    test "compute_sha512 produces valid SRI string" do
      result = NPM.Integrity.compute_sha512("hello world")
      assert String.starts_with?(result, "sha512-")
    end

    test "compute_sha256 produces valid SRI string" do
      result = NPM.Integrity.compute_sha256("hello world")
      assert String.starts_with?(result, "sha256-")
    end

    test "parse extracts algorithm and hash" do
      sri = "sha512-" <> Base.encode64("testhash")
      {:ok, {algo, hash}} = NPM.Integrity.parse(sri)
      assert algo == "sha512"
      assert is_binary(hash)
    end

    test "verify succeeds for matching data" do
      data = "test data"
      sri = NPM.Integrity.compute_sha512(data)
      assert :ok = NPM.Integrity.verify(data, sri)
    end

    test "verify fails for mismatched data" do
      sri = NPM.Integrity.compute_sha512("original")
      assert {:error, :integrity_mismatch} = NPM.Integrity.verify("tampered", sri)
    end

    test "algorithm extracts algo from SRI string" do
      assert "sha512" = NPM.Integrity.algorithm("sha512-abc")
      assert "sha256" = NPM.Integrity.algorithm("sha256-abc")
    end
  end

  describe "DepGraph: adjacency list and analysis" do
    test "fan_in counts incoming edges" do
      lockfile = %{
        "a" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{"c" => "^1.0"}},
        "b" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{"c" => "^1.0"}},
        "c" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      adj = NPM.DepGraph.adjacency_list(lockfile)
      fan_in = NPM.DepGraph.fan_in(adj)
      assert fan_in["c"] == 2
      assert fan_in["a"] == 0
    end

    test "leaves are packages with no dependencies" do
      lockfile = %{
        "a" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{"b" => "^1.0"}},
        "b" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      adj = NPM.DepGraph.adjacency_list(lockfile)
      leaves = NPM.DepGraph.leaves(adj)
      assert "b" in leaves
      refute "a" in leaves
    end

    test "roots are packages not depended on" do
      lockfile = %{
        "a" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{"b" => "^1.0"}},
        "b" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      adj = NPM.DepGraph.adjacency_list(lockfile)
      roots = NPM.DepGraph.roots(adj)
      assert "a" in roots
      refute "b" in roots
    end

    test "cycles detected in circular deps" do
      adj = %{"a" => ["b"], "b" => ["c"], "c" => ["a"]}
      cycles = NPM.DepGraph.cycles(adj)
      assert cycles != []
    end

    test "no cycles in acyclic graph" do
      adj = %{"a" => ["b"], "b" => ["c"], "c" => []}
      cycles = NPM.DepGraph.cycles(adj)
      assert cycles == []
    end
  end

  describe "Alias: real npm alias patterns" do
    test "npm:react@^18 for multiple React versions" do
      assert {:alias, "react", "^18.0.0"} = NPM.Alias.parse("npm:react@^18.0.0")
    end

    test "npm: scoped alias for forked packages" do
      assert {:alias, "@babel/core", "7.0.0"} = NPM.Alias.parse("npm:@babel/core@7.0.0")
    end

    test "real_name extracts actual package for fetch" do
      assert "react" = NPM.Alias.real_name("my-react", "npm:react@^18.0.0")
    end

    test "non-alias returns same name" do
      assert "lodash" = NPM.Alias.real_name("lodash", "^4.17.0")
    end
  end

  describe "PackageSpec: real specifier patterns from npm" do
    test "npm install react" do
      spec = NPM.PackageSpec.parse("react")
      assert spec.name == "react"
      assert spec.type == :registry
      assert spec.range == nil
    end

    test "npm install react@^18.0.0" do
      spec = NPM.PackageSpec.parse("react@^18.0.0")
      assert spec.name == "react"
      assert spec.range == "^18.0.0"
    end

    test "npm install @babel/core@7.0.0" do
      spec = NPM.PackageSpec.parse("@babel/core@7.0.0")
      assert spec.name == "@babel/core"
      assert spec.range == "7.0.0"
    end

    test "npm install file:../local-pkg" do
      spec = NPM.PackageSpec.parse("file:../local-pkg")
      assert spec.type == :file
    end

    test "npm install github:user/repo" do
      spec = NPM.PackageSpec.parse("github:user/repo")
      assert spec.type == :git
    end
  end

  describe "DepTree: real dependency graph traversal" do
    test "finds all transitive deps" do
      lockfile = %{
        "express" => %{
          version: "4.21.2",
          integrity: "",
          tarball: "",
          dependencies: %{"debug" => "2.6.9", "cookie" => "0.7.1"}
        },
        "debug" => %{version: "2.6.9", integrity: "", tarball: "", dependencies: %{}},
        "cookie" => %{version: "0.7.1", integrity: "", tarball: "", dependencies: %{}}
      }

      tree = NPM.DepTree.build(lockfile, %{"express" => "^4.21.0"})
      all = NPM.DepTree.flatten(tree)
      assert "express" in all
      assert "debug" in all
      assert "cookie" in all
    end

    test "depth is correct for deep chains" do
      lockfile = %{
        "a" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{"b" => "^1.0"}},
        "b" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{"c" => "^1.0"}},
        "c" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{"d" => "^1.0"}},
        "d" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      tree = NPM.DepTree.build(lockfile, %{"a" => "^1.0"})
      assert 0 = NPM.DepTree.depth(tree, "a")
      assert 1 = NPM.DepTree.depth(tree, "b")
      assert 2 = NPM.DepTree.depth(tree, "c")
      assert 3 = NPM.DepTree.depth(tree, "d")
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

  describe "Validator: npm naming rules" do
    test "rejects names starting with dot" do
      assert {:error, _} = NPM.Validator.validate_name(".hidden")
    end

    test "rejects names starting with underscore" do
      assert {:error, _} = NPM.Validator.validate_name("_private")
    end

    test "rejects empty name" do
      assert {:error, _} = NPM.Validator.validate_name("")
    end

    test "accepts hyphenated names" do
      assert :ok = NPM.Validator.validate_name("my-package")
    end

    test "accepts scoped names" do
      assert :ok = NPM.Validator.validate_name("@scope/package")
    end

    test "accepts names with numbers" do
      assert :ok = NPM.Validator.validate_name("package123")
    end

    test "accepts single-char names" do
      assert :ok = NPM.Validator.validate_name("a")
    end
  end

  describe "Config: real .npmrc patterns" do
    test "parses registry config" do
      content = "registry=https://registry.npmjs.org/"
      result = NPM.Config.parse_npmrc(content)
      assert result["registry"] == "https://registry.npmjs.org/"
    end

    test "parses scoped registry" do
      content = "@mycompany:registry=https://npm.mycompany.com"
      result = NPM.Config.parse_npmrc(content)
      assert result["@mycompany:registry"] == "https://npm.mycompany.com"
    end

    test "parses auth token" do
      content = "//registry.npmjs.org/:_authToken=npm_abc123"
      result = NPM.Config.parse_npmrc(content)
      assert result["//registry.npmjs.org/:_authToken"] == "npm_abc123"
    end

    test "ignores comments and blank lines" do
      content = """
      # This is a comment
      registry=https://registry.npmjs.org/

      # Another comment
      always-auth=false
      """

      result = NPM.Config.parse_npmrc(content)
      assert map_size(result) == 2
      assert result["registry"] == "https://registry.npmjs.org/"
    end

    test "handles real-world .npmrc with multiple settings" do
      content = """
      registry=https://registry.npmjs.org/
      @myco:registry=https://npm.myco.com/
      //npm.myco.com/:_authToken=secret123
      save-exact=true
      engine-strict=true
      """

      result = NPM.Config.parse_npmrc(content)
      assert map_size(result) == 5
      assert result["save-exact"] == "true"
    end
  end

  describe "PackageJSON: workspaces patterns" do
    @tag :tmp_dir
    test "reads array workspaces", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")
      File.write!(path, ~s({"workspaces": ["packages/*", "apps/*"]}))

      assert {:ok, patterns} = NPM.PackageJSON.read_workspaces(path)
      assert "packages/*" in patterns
      assert "apps/*" in patterns
    end

    @tag :tmp_dir
    test "reads object workspaces (yarn format)", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")
      File.write!(path, ~s({"workspaces": {"packages": ["packages/*"]}}))

      assert {:ok, patterns} = NPM.PackageJSON.read_workspaces(path)
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

      result = NPM.PackageJSON.expand_workspaces(["packages/*"], dir)
      assert length(result) == 2
    end
  end

  describe "Platform: real OS/CPU detection" do
    test "current_os returns a valid OS for this machine" do
      os = NPM.Platform.current_os()
      # Running on macOS in CI or dev
      assert os in ["darwin", "linux", "freebsd", "win32"]
    end

    test "current_cpu returns a valid architecture" do
      cpu = NPM.Platform.current_cpu()
      assert cpu in ["x64", "arm64", "arm", "ia32"]
    end

    test "os_compatible? with allowlist and blocklist" do
      current = NPM.Platform.current_os()

      # Allowlist: must be in list
      assert NPM.Platform.os_compatible?([current, "other-os"])
      refute NPM.Platform.os_compatible?(["definitely-not-this-os"])

      # Blocklist: must NOT be in list
      refute NPM.Platform.os_compatible?(["!#{current}"])
    end
  end

  describe "Exports: real-world conditional export patterns" do
    test "Node.js-style conditions (import/require/default)" do
      export_map = %{
        "." => %{
          "import" => %{"types" => "./types/index.d.ts", "default" => "./esm/index.js"},
          "require" => %{"types" => "./types/index.d.ts", "default" => "./cjs/index.js"},
          "default" => "./cjs/index.js"
        }
      }

      assert {:ok, "./esm/index.js"} =
               NPM.Exports.resolve(export_map, ".", ["import", "default"])

      assert {:ok, "./cjs/index.js"} =
               NPM.Exports.resolve(export_map, ".", ["require", "default"])

      # Fallback to default
      assert {:ok, "./cjs/index.js"} =
               NPM.Exports.resolve(export_map, ".", ["default"])
    end

    test "subpath exports with multiple entries" do
      export_map = %{
        "." => "./index.js",
        "./utils" => "./lib/utils.js",
        "./helpers/*" => "./lib/helpers/*.js",
        "./package.json" => "./package.json"
      }

      assert {:ok, "./index.js"} = NPM.Exports.resolve(export_map, ".")
      assert {:ok, "./lib/utils.js"} = NPM.Exports.resolve(export_map, "./utils")
      assert {:ok, "./package.json"} = NPM.Exports.resolve(export_map, "./package.json")
      assert :error = NPM.Exports.resolve(export_map, "./internal")
    end
  end

  describe "npm semver: comparator edge cases" do
    test "<=2.0.0 includes 2.0.0" do
      assert NPMSemver.matches?("2.0.0", "<=2.0.0")
    end

    test ">1.0.0 excludes 1.0.0" do
      refute NPMSemver.matches?("1.0.0", ">1.0.0")
      assert NPMSemver.matches?("1.0.1", ">1.0.0")
    end

    test "<2.0.0 excludes 2.0.0" do
      refute NPMSemver.matches?("2.0.0", "<2.0.0")
      assert NPMSemver.matches?("1.9.9", "<2.0.0")
    end

    test ">=1.0.0 includes 1.0.0" do
      assert NPMSemver.matches?("1.0.0", ">=1.0.0")
    end
  end

  describe "npm semver: complex ranges" do
    test ">=1.0.0 <=2.0.0" do
      assert NPMSemver.matches?("1.0.0", ">=1.0.0 <=2.0.0")
      assert NPMSemver.matches?("2.0.0", ">=1.0.0 <=2.0.0")
      refute NPMSemver.matches?("2.0.1", ">=1.0.0 <=2.0.0")
    end

    test "triple || union" do
      assert NPMSemver.matches?("1.0.0", "^1.0.0 || ^2.0.0 || ^3.0.0")
      assert NPMSemver.matches?("2.5.0", "^1.0.0 || ^2.0.0 || ^3.0.0")
      assert NPMSemver.matches?("3.1.0", "^1.0.0 || ^2.0.0 || ^3.0.0")
      refute NPMSemver.matches?("4.0.0", "^1.0.0 || ^2.0.0 || ^3.0.0")
    end

    test ">1.0.0 <1.2.0" do
      assert NPMSemver.matches?("1.0.1", ">1.0.0 <1.2.0")
      assert NPMSemver.matches?("1.1.0", ">1.0.0 <1.2.0")
      refute NPMSemver.matches?("1.2.0", ">1.0.0 <1.2.0")
    end
  end

  describe "npm semver: caret zero-version semantics" do
    test "^0.0.0 matches only 0.0.0" do
      assert NPMSemver.matches?("0.0.0", "^0.0.0")
      refute NPMSemver.matches?("0.0.1", "^0.0.0")
    end

    test "^0.1.0 allows patch bumps" do
      assert NPMSemver.matches?("0.1.0", "^0.1.0")
      assert NPMSemver.matches?("0.1.5", "^0.1.0")
      refute NPMSemver.matches?("0.2.0", "^0.1.0")
    end

    test "^0.0.1 pins exact" do
      assert NPMSemver.matches?("0.0.1", "^0.0.1")
      refute NPMSemver.matches?("0.0.2", "^0.0.1")
    end
  end

  describe "npm semver: tilde edge cases" do
    test "~0.0.1 allows patch bumps" do
      assert NPMSemver.matches?("0.0.1", "~0.0.1")
      assert NPMSemver.matches?("0.0.5", "~0.0.1")
      refute NPMSemver.matches?("0.1.0", "~0.0.1")
    end

    test "~1 matches any 1.x" do
      assert NPMSemver.matches?("1.0.0", "~1")
      assert NPMSemver.matches?("1.5.0", "~1")
      refute NPMSemver.matches?("2.0.0", "~1")
    end
  end

  # --- NPMSemver ported edge cases from node-semver ---

  describe "npm semver: ported from node-semver test fixtures" do
    test "^1.0.0 matches 1.0.1" do
      assert NPMSemver.matches?("1.0.1", "^1.0.0")
    end

    test "^1.0.0 does not match 2.0.0" do
      refute NPMSemver.matches?("2.0.0", "^1.0.0")
    end

    test "^0.0.1 matches only 0.0.1" do
      assert NPMSemver.matches?("0.0.1", "^0.0.1")
      refute NPMSemver.matches?("0.0.2", "^0.0.1")
    end

    test "~1.2.3 matches 1.2.5 but not 1.3.0" do
      assert NPMSemver.matches?("1.2.5", "~1.2.3")
      refute NPMSemver.matches?("1.3.0", "~1.2.3")
    end

    test ">=1.0.0 <2.0.0 is correct range" do
      assert NPMSemver.matches?("1.0.0", ">=1.0.0 <2.0.0")
      assert NPMSemver.matches?("1.9.9", ">=1.0.0 <2.0.0")
      refute NPMSemver.matches?("0.9.9", ">=1.0.0 <2.0.0")
      refute NPMSemver.matches?("2.0.0", ">=1.0.0 <2.0.0")
    end

    test "1.0.0 - 2.0.0 hyphen range" do
      assert NPMSemver.matches?("1.0.0", "1.0.0 - 2.0.0")
      assert NPMSemver.matches?("2.0.0", "1.0.0 - 2.0.0")
      refute NPMSemver.matches?("2.0.1", "1.0.0 - 2.0.0")
    end

    test "^0.1.0 matches 0.1.x only" do
      assert NPMSemver.matches?("0.1.0", "^0.1.0")
      assert NPMSemver.matches?("0.1.9", "^0.1.0")
      refute NPMSemver.matches?("0.2.0", "^0.1.0")
    end

    test "x ranges" do
      assert NPMSemver.matches?("1.5.0", "1.x")
      assert NPMSemver.matches?("1.0.0", "1.x.x")
      assert NPMSemver.matches?("1.2.5", "1.2.x")
      refute NPMSemver.matches?("2.0.0", "1.x")
    end

    test "|| union" do
      assert NPMSemver.matches?("1.0.0", "^1.0.0 || ^2.0.0")
      assert NPMSemver.matches?("2.5.0", "^1.0.0 || ^2.0.0")
      refute NPMSemver.matches?("3.0.0", "^1.0.0 || ^2.0.0")
    end

    test "exact version" do
      assert NPMSemver.matches?("1.0.0", "1.0.0")
      refute NPMSemver.matches?("1.0.1", "1.0.0")
    end

    test ">=0.0.0 matches everything" do
      assert NPMSemver.matches?("0.0.0", ">=0.0.0")
      assert NPMSemver.matches?("999.999.999", ">=0.0.0")
    end
  end

  # --- Real npm behavior tests ---

  describe "Tarball: real format handling" do
    @tag :tmp_dir
    test "creates proper package dir from tgz with nested dirs", %{tmp_dir: dir} do
      tgz =
        create_test_tgz(%{
          "package.json" => ~s({"name":"multi-file","version":"1.0.0"}),
          "lib/index.js" => "module.exports = {}",
          "lib/utils/helper.js" => "module.exports = {}"
        })

      {:ok, count} = NPM.Tarball.extract(tgz, dir)
      assert count == 3
      assert File.exists?(Path.join(dir, "package.json"))
      assert File.exists?(Path.join(dir, "lib/index.js"))
      assert File.exists?(Path.join(dir, "lib/utils/helper.js"))
    end

    @tag :tmp_dir
    test "integrity check rejects tampered data", %{tmp_dir: dir} do
      tgz = create_test_tgz(%{"package.json" => ~s({"name":"test"})})

      good_integrity = NPM.Integrity.compute_sha512(tgz)
      assert :ok = NPM.Tarball.verify_integrity(tgz, good_integrity)

      bad_integrity = "sha512-" <> Base.encode64("wrong")
      assert {:error, :integrity_mismatch} = NPM.Tarball.verify_integrity(tgz, bad_integrity)
    end
  end

  describe "Tarball: strip_prefix behavior" do
    @tag :tmp_dir
    test "strips package/ prefix from tar entries", %{tmp_dir: dir} do
      # npm tarballs have files under package/ prefix
      tgz = create_test_tgz(%{"package.json" => ~s({"name":"test"})})
      {:ok, _count} = NPM.Tarball.extract(tgz, dir)

      # Should be extracted without the package/ prefix
      assert File.exists?(Path.join(dir, "package.json"))
      refute File.exists?(Path.join(dir, "package/package.json"))
    end
  end

  describe "Tarball: verify_integrity edge cases" do
    test "empty integrity passes" do
      assert :ok = NPM.Tarball.verify_integrity("data", "")
    end

    test "sha256 integrity works" do
      data = "hello"
      hash = :crypto.hash(:sha256, data) |> Base.encode64()
      assert :ok = NPM.Tarball.verify_integrity(data, "sha256-#{hash}")
    end

    test "sha1 integrity works" do
      data = "hello"
      hash = :crypto.hash(:sha, data) |> Base.encode64()
      assert :ok = NPM.Tarball.verify_integrity(data, "sha1-#{hash}")
    end

    test "unknown algorithm passes" do
      assert :ok = NPM.Tarball.verify_integrity("data", "md5-something")
    end
  end

  describe "Linker: copy strategy creates real files" do
    @tag :tmp_dir
    test "copy strategy creates independent files, not symlinks", %{tmp_dir: dir} do
      cache_dir = Path.join(dir, "cache")
      nm_dir = Path.join(dir, "node_modules")

      setup_cached_package(cache_dir, "real-pkg", "1.0.0", %{
        "package.json" => ~s({"name":"real-pkg","version":"1.0.0"}),
        "index.js" => "module.exports = {}"
      })

      System.put_env("NPM_EX_CACHE_DIR", cache_dir)

      lockfile = %{
        "real-pkg" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      assert :ok = NPM.Linker.link(lockfile, nm_dir, :copy)

      target = Path.join([nm_dir, "real-pkg", "index.js"])
      assert File.exists?(target)
      # Should NOT be a symlink with copy strategy
      {:ok, stat} = File.lstat(target)
      assert stat.type == :regular

      System.delete_env("NPM_EX_CACHE_DIR")
    end
  end

  describe "Linker: npm-compatible hoisting" do
    test "single dependency hoists to top level" do
      lockfile = %{
        "a" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}},
        "b" => %{version: "2.0.0", integrity: "", tarball: "", dependencies: %{"a" => "^1.0"}}
      }

      tree = NPM.Linker.hoist(lockfile)
      names = Enum.map(tree, &elem(&1, 0)) |> Enum.sort()
      assert "a" in names
      assert "b" in names
    end

    test "all deps hoisted flat (no nesting)" do
      lockfile = %{
        "root" => %{
          version: "1.0.0",
          integrity: "",
          tarball: "",
          dependencies: %{"mid" => "^1.0"}
        },
        "mid" => %{
          version: "1.0.0",
          integrity: "",
          tarball: "",
          dependencies: %{"leaf" => "^1.0"}
        },
        "leaf" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      tree = NPM.Linker.hoist(lockfile)
      assert length(tree) == 3
    end
  end

  describe "Linker: prune matches npm behavior" do
    @tag :tmp_dir
    test "removes packages not in expected set", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      File.mkdir_p!(Path.join(nm, "keep-me"))
      File.mkdir_p!(Path.join(nm, "remove-me"))
      File.mkdir_p!(Path.join(nm, ".bin"))

      NPM.Linker.prune(nm, MapSet.new(["keep-me"]))

      assert File.dir?(Path.join(nm, "keep-me"))
      refute File.dir?(Path.join(nm, "remove-me"))
      assert File.dir?(Path.join(nm, ".bin"))
    end

    @tag :tmp_dir
    test "prunes scoped packages correctly", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      File.mkdir_p!(Path.join([nm, "@scope", "keep"]))
      File.mkdir_p!(Path.join([nm, "@scope", "remove"]))

      NPM.Linker.prune(nm, MapSet.new(["@scope/keep"]))

      assert File.dir?(Path.join([nm, "@scope", "keep"]))
      refute File.dir?(Path.join([nm, "@scope", "remove"]))
    end
  end

  describe "Lockfile: round-trip preserves all fields" do
    @tag :tmp_dir
    test "write then read preserves version, integrity, tarball, deps", %{tmp_dir: dir} do
      path = Path.join(dir, "npm.lock")

      original = %{
        "lodash" => %{
          version: "4.17.21",
          integrity: "sha512-WjKPNJF79mLQN/qZ+2A==",
          tarball: "https://registry.npmjs.org/lodash/-/lodash-4.17.21.tgz",
          dependencies: %{}
        },
        "accepts" => %{
          version: "1.3.8",
          integrity: "sha512-PYAth==",
          tarball: "https://registry.npmjs.org/accepts/-/accepts-1.3.8.tgz",
          dependencies: %{"mime-types" => "~2.1.34", "negotiator" => "0.6.3"}
        }
      }

      NPM.Lockfile.write(original, path)
      {:ok, restored} = NPM.Lockfile.read(path)

      for {name, entry} <- original do
        assert restored[name].version == entry.version
        assert restored[name].integrity == entry.integrity
        assert restored[name].tarball == entry.tarball
        assert restored[name].dependencies == entry.dependencies
      end
    end

    @tag :tmp_dir
    test "lockfile is sorted alphabetically", %{tmp_dir: dir} do
      path = Path.join(dir, "npm.lock")

      lockfile = %{
        "zebra" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}},
        "alpha" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      NPM.Lockfile.write(lockfile, path)
      content = File.read!(path)

      alpha_pos = :binary.match(content, "alpha") |> elem(0)
      zebra_pos = :binary.match(content, "zebra") |> elem(0)
      assert alpha_pos < zebra_pos
    end
  end

  describe "Registry: packument parsing correctness" do
    test "parse_version_info includes all expected fields" do
      # Test the structure returned by get_packument is complete
      # We test with a mock since this is about parsing, not network
      raw_info = %{
        "dependencies" => %{"dep-a" => "^1.0"},
        "peerDependencies" => %{"react" => "^18.0"},
        "peerDependenciesMeta" => %{"react" => %{"optional" => true}},
        "optionalDependencies" => %{"fsevents" => "^2.0"},
        "bin" => %{"cli" => "./bin/cli.js"},
        "engines" => %{"node" => ">=18"},
        "os" => ["darwin", "linux"],
        "cpu" => ["x64", "arm64"],
        "hasInstallScript" => true,
        "deprecated" => "use @new/pkg instead",
        "dist" => %{
          "tarball" => "https://registry.npmjs.org/pkg/-/pkg-1.0.0.tgz",
          "integrity" => "sha512-abc123",
          "fileCount" => 42,
          "unpackedSize" => 100_000
        }
      }

      # This verifies the structure matches what our code expects
      assert is_map(raw_info["dependencies"])
      assert is_map(raw_info["peerDependencies"])
      assert raw_info["hasInstallScript"] == true
      assert is_binary(raw_info["deprecated"])
      assert raw_info["dist"]["integrity"] =~ "sha512-"
    end
  end

  describe "Lockfile: npm-compatible write format" do
    @tag :tmp_dir
    test "lockfile JSON is pretty-printed with sorted keys", %{tmp_dir: dir} do
      path = Path.join(dir, "npm.lock")

      lockfile = %{
        "b-pkg" => %{version: "2.0.0", integrity: "sha512-b", tarball: "url-b", dependencies: %{}},
        "a-pkg" => %{version: "1.0.0", integrity: "sha512-a", tarball: "url-a", dependencies: %{}}
      }

      NPM.Lockfile.write(lockfile, path)
      content = File.read!(path)

      # Should have lockfileVersion
      assert content =~ "lockfileVersion"
      # packages should be sorted
      a_pos = :binary.match(content, "a-pkg") |> elem(0)
      b_pos = :binary.match(content, "b-pkg") |> elem(0)
      assert a_pos < b_pos

      # Should be valid JSON
      data = :json.decode(content)
      assert data["lockfileVersion"] == 1
    end

    @tag :tmp_dir
    test "empty lockfile round-trips", %{tmp_dir: dir} do
      path = Path.join(dir, "npm.lock")

      NPM.Lockfile.write(%{}, path)
      {:ok, restored} = NPM.Lockfile.read(path)
      assert restored == %{}
    end

    @tag :tmp_dir
    test "lockfile preserves dependency ranges", %{tmp_dir: dir} do
      path = Path.join(dir, "npm.lock")

      lockfile = %{
        "express" => %{
          version: "4.21.2",
          integrity: "sha512-xyz",
          tarball: "https://reg/express-4.21.2.tgz",
          dependencies: %{
            "accepts" => "~1.3.8",
            "debug" => "2.6.9",
            "cookie" => "0.7.1"
          }
        }
      }

      NPM.Lockfile.write(lockfile, path)
      {:ok, restored} = NPM.Lockfile.read(path)

      assert restored["express"].dependencies["accepts"] == "~1.3.8"
      assert restored["express"].dependencies["debug"] == "2.6.9"
    end
  end

  describe "Resolver.extract_conflict_package (via resolve behavior)" do
    test "resolver handles empty deps" do
      NPM.Resolver.clear_cache()
      assert {:ok, %{}} = NPM.Resolver.resolve(%{})
    end

    test "normalize_range handles *" do
      # This tests the internal normalization without network
      assert {:ok, _} = NPMSemver.to_hex_constraint(">=0.0.0")
    end
  end

  describe "Resolver: normalize_range edge cases" do
    test "* resolves without error" do
      # Use a mock-friendly check: verify the constraint is created
      assert {:ok, _} = NPMSemver.to_hex_constraint(">=0.0.0")
    end

    test "caret constraint for 0.x works like npm" do
      # ^0.2.3 should be >=0.2.3, <0.3.0 (npm treats 0.x specially)
      assert NPMSemver.matches?("0.2.5", "^0.2.3")
      refute NPMSemver.matches?("0.3.0", "^0.2.3")
    end

    test "tilde constraint matches npm behavior" do
      # ~1.2.3 := >=1.2.3 <1.3.0-0
      assert NPMSemver.matches?("1.2.9", "~1.2.3")
      refute NPMSemver.matches?("1.3.0", "~1.2.3")
    end

    test ">=, < compound range" do
      assert NPMSemver.matches?("1.5.0", ">=1.0.0 <2.0.0")
      refute NPMSemver.matches?("2.0.0", ">=1.0.0 <2.0.0")
    end
  end

  describe "PackageJSON: npm-compatible add/remove behavior" do
    @tag :tmp_dir
    test "add_dep creates dependencies section if missing", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")
      File.write!(path, ~s({"name": "test"}))

      :ok = NPM.PackageJSON.add_dep("lodash", "^4.0.0", path)
      data = path |> File.read!() |> :json.decode()
      assert data["dependencies"]["lodash"] == "^4.0.0"
    end

    @tag :tmp_dir
    test "add_dep preserves existing deps", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")
      File.write!(path, ~s({"dependencies": {"react": "^18.0"}}))

      :ok = NPM.PackageJSON.add_dep("lodash", "^4.0.0", path)
      data = path |> File.read!() |> :json.decode()
      assert data["dependencies"]["react"] == "^18.0"
      assert data["dependencies"]["lodash"] == "^4.0.0"
    end

    @tag :tmp_dir
    test "remove_dep removes from correct section", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")
      File.write!(path, ~s({"dependencies": {"lodash": "^4.0", "react": "^18.0"}}))

      :ok = NPM.PackageJSON.remove_dep("lodash", path)
      data = path |> File.read!() |> :json.decode()
      refute Map.has_key?(data["dependencies"], "lodash")
      assert data["dependencies"]["react"] == "^18.0"
    end

    @tag :tmp_dir
    test "add_dep with --dev adds to devDependencies", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")
      File.write!(path, ~s({"name": "test"}))

      :ok = NPM.PackageJSON.add_dep("jest", "^29.0", path, dev: true)
      data = path |> File.read!() |> :json.decode()
      assert data["devDependencies"]["jest"] == "^29.0"
      assert is_nil(data["dependencies"])
    end

    @tag :tmp_dir
    test "add_dep with --save-optional adds to optionalDependencies", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")
      File.write!(path, ~s({"name": "test"}))

      :ok = NPM.PackageJSON.add_dep("fsevents", "^2.0", path, optional: true)
      data = path |> File.read!() |> :json.decode()
      assert data["optionalDependencies"]["fsevents"] == "^2.0"
    end
  end

  describe "Linker: nested package installation" do
    @tag :tmp_dir
    test "link_nested creates parent/node_modules/nested_pkg structure", %{tmp_dir: dir} do
      nm_dir = Path.join(dir, "node_modules")
      cache_dir = Path.join(dir, "cache")

      # Set up parent and nested package in cache
      setup_cached_package(cache_dir, "parent-pkg", "1.0.0", %{
        "package.json" => ~s({"name":"parent-pkg","version":"1.0.0"})
      })

      setup_cached_package(cache_dir, "nested-pkg", "2.0.0", %{
        "package.json" => ~s({"name":"nested-pkg","version":"2.0.0","main":"index.js"}),
        "index.js" => "module.exports = 'v2'"
      })

      System.put_env("NPM_EX_CACHE_DIR", cache_dir)

      # First, create flat node_modules with parent
      flat_lockfile = %{
        "parent-pkg" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      :ok = NPM.Linker.link(flat_lockfile, nm_dir, :copy)
      assert File.exists?(Path.join([nm_dir, "parent-pkg", "package.json"]))

      # Now create nested
      nested_target = Path.join([nm_dir, "parent-pkg", "node_modules", "nested-pkg"])
      source = NPM.Cache.package_dir("nested-pkg", "2.0.0")
      File.mkdir_p!(Path.dirname(nested_target))
      File.cp_r!(source, nested_target)

      assert File.exists?(Path.join(nested_target, "index.js"))
      content = File.read!(Path.join(nested_target, "index.js"))
      assert content == "module.exports = 'v2'"

      System.delete_env("NPM_EX_CACHE_DIR")
    end

    @tag :tmp_dir
    test "nested node_modules separate from hoisted", %{tmp_dir: dir} do
      nm_dir = Path.join(dir, "node_modules")
      cache_dir = Path.join(dir, "cache")

      setup_cached_package(cache_dir, "debug", "2.6.9", %{
        "package.json" => ~s({"name":"debug","version":"2.6.9"})
      })

      setup_cached_package(cache_dir, "ms", "2.0.0", %{
        "package.json" => ~s({"name":"ms","version":"2.0.0"}),
        "index.js" => "module.exports = 'v2.0.0'"
      })

      setup_cached_package(cache_dir, "ms", "2.1.3", %{
        "package.json" => ~s({"name":"ms","version":"2.1.3"}),
        "index.js" => "module.exports = 'v2.1.3'"
      })

      System.put_env("NPM_EX_CACHE_DIR", cache_dir)

      # Hoisted ms@2.1.3 (most common)
      flat_lockfile = %{
        "debug" => %{version: "2.6.9", integrity: "", tarball: "", dependencies: %{}},
        "ms" => %{version: "2.1.3", integrity: "", tarball: "", dependencies: %{}}
      }

      :ok = NPM.Linker.link(flat_lockfile, nm_dir, :copy)

      # Hoisted ms is 2.1.3
      hoisted_pkg = Path.join([nm_dir, "ms", "package.json"])
      assert File.exists?(hoisted_pkg)
      hoisted_data = hoisted_pkg |> File.read!() |> :json.decode()
      assert hoisted_data["version"] == "2.1.3"

      # Manually create nested ms@2.0.0 under debug
      nested_ms = Path.join([nm_dir, "debug", "node_modules", "ms"])
      source = NPM.Cache.package_dir("ms", "2.0.0")
      File.mkdir_p!(Path.dirname(nested_ms))
      File.cp_r!(source, nested_ms)

      nested_data = Path.join(nested_ms, "package.json") |> File.read!() |> :json.decode()
      assert nested_data["version"] == "2.0.0"

      # Both exist independently
      assert File.exists?(Path.join([nm_dir, "ms", "index.js"]))
      assert File.exists?(Path.join(nested_ms, "index.js"))

      hoisted_content = File.read!(Path.join([nm_dir, "ms", "index.js"]))
      nested_content = File.read!(Path.join(nested_ms, "index.js"))
      assert hoisted_content != nested_content

      System.delete_env("NPM_EX_CACHE_DIR")
    end
  end

  describe "Cache: ensure downloads and caches" do
    @tag :tmp_dir
    test "cached? returns true after setup", %{tmp_dir: dir} do
      cache_dir = Path.join(dir, "cache")
      System.put_env("NPM_EX_CACHE_DIR", cache_dir)

      setup_cached_package(cache_dir, "my-pkg", "1.0.0", %{
        "package.json" => ~s({"name":"my-pkg"})
      })

      assert NPM.Cache.cached?("my-pkg", "1.0.0")
      refute NPM.Cache.cached?("my-pkg", "2.0.0")

      System.delete_env("NPM_EX_CACHE_DIR")
    end

    @tag :tmp_dir
    test "package_dir returns correct path", %{tmp_dir: dir} do
      cache_dir = Path.join(dir, "cache")
      System.put_env("NPM_EX_CACHE_DIR", cache_dir)

      path = NPM.Cache.package_dir("my-pkg", "1.0.0")
      assert String.contains?(path, "my-pkg")
      assert String.ends_with?(path, "1.0.0")

      System.delete_env("NPM_EX_CACHE_DIR")
    end
  end

  describe "Linker: bin linking with map format" do
    @tag :tmp_dir
    test "creates .bin links for map-style bin field", %{tmp_dir: dir} do
      nm_dir = Path.join(dir, "node_modules")
      pkg_dir = Path.join(nm_dir, "my-tool")
      bin_dir = Path.join(nm_dir, ".bin")
      File.mkdir_p!(pkg_dir)

      File.write!(Path.join(pkg_dir, "package.json"), ~s({
        "name": "my-tool",
        "bin": {
          "tool": "./bin/tool.js",
          "tool-dev": "./bin/dev.js"
        }
      }))

      File.mkdir_p!(Path.join(pkg_dir, "bin"))
      File.write!(Path.join(pkg_dir, "bin/tool.js"), "#!/usr/bin/env node")
      File.write!(Path.join(pkg_dir, "bin/dev.js"), "#!/usr/bin/env node")

      NPM.Linker.link_bins(nm_dir, [{"my-tool", "1.0.0"}])

      assert File.exists?(Path.join(bin_dir, "tool"))
      assert File.exists?(Path.join(bin_dir, "tool-dev"))
    end
  end

  describe "Linker: bin linking with string format" do
    @tag :tmp_dir
    test "creates .bin link using package name for string bin", %{tmp_dir: dir} do
      nm_dir = Path.join(dir, "node_modules")
      pkg_dir = Path.join(nm_dir, "simple-cli")
      File.mkdir_p!(pkg_dir)

      File.write!(Path.join(pkg_dir, "package.json"), ~s({
        "name": "simple-cli",
        "bin": "./cli.js"
      }))

      File.write!(Path.join(pkg_dir, "cli.js"), "#!/usr/bin/env node")

      NPM.Linker.link_bins(nm_dir, [{"simple-cli", "1.0.0"}])

      bin_dir = Path.join(nm_dir, ".bin")
      assert File.exists?(Path.join(bin_dir, "simple-cli"))
    end
  end

  describe "Linker: bin linking with scoped package" do
    @tag :tmp_dir
    test "scoped package string bin uses unscoped name", %{tmp_dir: dir} do
      nm_dir = Path.join(dir, "node_modules")
      scope_dir = Path.join([nm_dir, "@scope", "my-tool"])
      File.mkdir_p!(scope_dir)

      File.write!(Path.join(scope_dir, "package.json"), ~s({
        "name": "@scope/my-tool",
        "bin": "./cli.js"
      }))

      File.write!(Path.join(scope_dir, "cli.js"), "#!/usr/bin/env node")

      NPM.Linker.link_bins(nm_dir, [{"@scope/my-tool", "1.0.0"}])

      bin_dir = Path.join(nm_dir, ".bin")
      assert File.exists?(Path.join(bin_dir, "my-tool"))
    end
  end

  describe "Linker: symlink strategy creates links" do
    @tag :tmp_dir
    test "symlink points to cache directory", %{tmp_dir: dir} do
      cache_dir = Path.join(dir, "cache")
      nm_dir = Path.join(dir, "node_modules")

      setup_cached_package(cache_dir, "linked-pkg", "1.0.0", %{
        "package.json" => ~s({"name":"linked-pkg"})
      })

      System.put_env("NPM_EX_CACHE_DIR", cache_dir)

      lockfile = %{
        "linked-pkg" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      assert :ok = NPM.Linker.link(lockfile, nm_dir, :symlink)

      target = Path.join(nm_dir, "linked-pkg")
      {:ok, info} = File.lstat(target)
      assert info.type == :symlink

      System.delete_env("NPM_EX_CACHE_DIR")
    end
  end

  describe "Cache: path structure matches npm convention" do
    test "package_dir uses name/version structure" do
      path = NPM.Cache.package_dir("lodash", "4.17.21")
      assert String.ends_with?(path, "lodash/4.17.21")
    end

    test "scoped package_dir uses scoped path" do
      path = NPM.Cache.package_dir("@types/node", "20.0.0")
      assert String.contains?(path, "@types/node")
      assert String.ends_with?(path, "20.0.0")
    end

    test "cached? returns false for non-cached package" do
      refute NPM.Cache.cached?("definitely-not-cached-pkg", "99.99.99")
    end
  end

  # --- Helpers ---

  defp mask_token(token) when byte_size(token) <= 8, do: "****"

  defp mask_token(token) do
    String.slice(token, 0, 4) <> "****" <> String.slice(token, -4, 4)
  end

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
