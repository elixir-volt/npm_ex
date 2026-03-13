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

    test "passes for unknown hash algorithm" do
      assert :ok = NPM.Tarball.verify_integrity("anything", "sha256-something==")
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

  # --- Cache edge cases ---

  describe "Cache edge cases" do
    test "package_dir uses correct separator" do
      path = NPM.Cache.package_dir("test-pkg", "1.0.0")
      assert path =~ "cache/test-pkg/1.0.0"
    end

    test "cached? returns false for nonexistent version" do
      refute NPM.Cache.cached?("lodash", "0.0.0-nonexistent")
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
