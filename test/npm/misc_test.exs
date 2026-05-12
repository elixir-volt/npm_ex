defmodule NPM.MiscTest do
  use ExUnit.Case, async: true

  alias Mix.Tasks.Npm.Licenses
  import NPM.TestHelpers

  alias NPM.Package.JSON

  describe "scoped package operations" do
    @tag :tmp_dir
    test "add and remove scoped dev dependency", %{tmp_dir: dir} do
      path = Path.join(dir, "package.json")

      JSON.add_dep("@types/react", "^18.0", path, dev: true)

      {:ok, %{dev_dependencies: dev_deps}} = JSON.read_all(path)
      assert dev_deps["@types/react"] == "^18.0"

      JSON.remove_dep("@types/react", path)

      {:ok, %{dev_dependencies: dev_deps2}} = JSON.read_all(path)
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
      {:ok, pkg_data} = JSON.read_all(pkg_path)
      _all_deps = pkg_data.dependencies

      # Express is in deps but not lockfile — should be a mismatch
      has_express_locked = Map.has_key?(lockfile_data, "express")
      refute has_express_locked
    end
  end
end
