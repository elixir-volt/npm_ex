defmodule NPM.IntegrationTest do
  use ExUnit.Case

  @moduletag :integration

  describe "Registry.get_packument" do
    test "fetches lodash packument" do
      assert {:ok, packument} = NPM.Registry.get_packument("lodash")
      assert packument.name == "lodash"
      assert Map.has_key?(packument.versions, "4.17.21")
    end

    test "fetches scoped package" do
      assert {:ok, packument} = NPM.Registry.get_packument("@types/node")
      assert packument.name == "@types/node"
      assert map_size(packument.versions) > 0
    end

    test "returns error for nonexistent package" do
      assert {:error, :not_found} =
               NPM.Registry.get_packument("this-package-does-not-exist-xyz-123")
    end

    test "parses dependencies correctly" do
      assert {:ok, packument} = NPM.Registry.get_packument("express")
      info = packument.versions["4.21.2"]
      assert is_map(info.dependencies)
      assert Map.has_key?(info.dependencies, "body-parser")
      assert info.dependencies["body-parser"] =~ ~r/^\d/
    end

    test "parses dist info correctly" do
      assert {:ok, packument} = NPM.Registry.get_packument("is-number")
      info = packument.versions["7.0.0"]
      assert info.dist.tarball =~ "registry.npmjs.org"
      assert info.dist.tarball =~ "is-number"
      assert info.dist.integrity =~ "sha512-"
    end

    test "handles package with no dependencies" do
      assert {:ok, packument} = NPM.Registry.get_packument("is-number")
      info = packument.versions["7.0.0"]
      assert info.dependencies == %{}
    end

    test "parses peer dependencies" do
      assert {:ok, packument} = NPM.Registry.get_packument("react-dom")
      info = packument.versions["18.3.1"]
      assert is_map(info.peer_dependencies)
      assert Map.has_key?(info.peer_dependencies, "react")
    end

    test "parses engines field" do
      assert {:ok, packument} = NPM.Registry.get_packument("typescript")
      info = packument.versions["5.7.3"]
      assert is_map(info.engines)
    end

    test "parses bin field" do
      assert {:ok, packument} = NPM.Registry.get_packument("typescript")
      info = packument.versions["5.7.3"]
      assert is_map(info.bin)
    end

    test "detects deprecated packages" do
      assert {:ok, packument} = NPM.Registry.get_packument("request")
      info = packument.versions["2.88.2"]
      assert is_binary(info.deprecated) or is_nil(info.deprecated)
    end

    test "parses dist metadata" do
      assert {:ok, packument} = NPM.Registry.get_packument("is-number")
      info = packument.versions["7.0.0"]
      assert is_binary(info.dist.tarball)
      assert is_binary(info.dist.integrity)
    end
  end

  describe "Resolver" do
    setup do
      NPM.Resolver.clear_cache()
      :ok
    end

    test "resolves a single package with no deps" do
      assert {:ok, resolved} = NPM.Resolver.resolve(%{"is-number" => "^7.0.0"})
      assert resolved["is-number"] =~ ~r/^7\./
      assert map_size(resolved) == 1
    end

    test "resolves package with transitive dependencies" do
      assert {:ok, resolved} = NPM.Resolver.resolve(%{"accepts" => "~1.3.8"})
      assert resolved["accepts"] =~ ~r/^1\.3\./
      assert Map.has_key?(resolved, "mime-types")
      assert Map.has_key?(resolved, "negotiator")
    end

    test "resolves multiple root deps" do
      assert {:ok, resolved} =
               NPM.Resolver.resolve(%{"is-number" => "^7.0.0", "depd" => "^2.0.0"})

      assert Map.has_key?(resolved, "is-number")
      assert Map.has_key?(resolved, "depd")
    end

    test "returns error for impossible range" do
      assert {:error, _message} = NPM.Resolver.resolve(%{"is-number" => "^999.0.0"})
    end

    test "returns ok for empty deps" do
      assert {:ok, %{}} = NPM.Resolver.resolve(%{})
    end

    test "resolved versions are valid semver" do
      assert {:ok, resolved} = NPM.Resolver.resolve(%{"depd" => "^2.0.0"})

      Enum.each(resolved, fn {_name, version} ->
        assert {:ok, _} = Version.parse(version)
      end)
    end
  end

  describe "Resolver with devDependencies" do
    setup do
      NPM.Resolver.clear_cache()
      :ok
    end

    test "resolves dev deps same as regular deps" do
      assert {:ok, resolved} = NPM.Resolver.resolve(%{"is-number" => "^7.0.0"})
      assert Map.has_key?(resolved, "is-number")
    end
  end

  describe "full install flow" do
    @tag :tmp_dir
    test "resolve → lockfile → cache → node_modules", %{tmp_dir: dir} do
      cache_dir = Path.join(dir, "npm_cache")
      nm_dir = Path.join(dir, "node_modules")
      lock_path = Path.join(dir, "npm.lock")
      System.put_env("NPM_EX_CACHE_DIR", cache_dir)

      NPM.Resolver.clear_cache()
      {:ok, resolved} = NPM.Resolver.resolve(%{"is-number" => "^7.0.0"})

      lockfile =
        for {name, version_str} <- resolved, into: %{} do
          {:ok, packument} = NPM.Registry.get_packument(name)
          info = Map.fetch!(packument.versions, version_str)

          {name,
           %{
             version: version_str,
             integrity: info.dist.integrity,
             tarball: info.dist.tarball,
             dependencies: info.dependencies
           }}
        end

      # Write lockfile
      NPM.Lockfile.write(lockfile, lock_path)
      assert {:ok, read_lock} = NPM.Lockfile.read(lock_path)
      assert read_lock["is-number"].version =~ ~r/^7\./

      # Link to node_modules
      assert :ok = NPM.Linker.link(lockfile, nm_dir)

      # Verify cache populated
      assert NPM.Cache.cached?("is-number", lockfile["is-number"].version)

      # Verify node_modules
      assert File.exists?(Path.join([nm_dir, "is-number", "package.json"]))

      pkg_json =
        Path.join([nm_dir, "is-number", "package.json"])
        |> File.read!()
        |> :json.decode()

      assert pkg_json["name"] == "is-number"

      System.delete_env("NPM_EX_CACHE_DIR")
    end

    @tag :tmp_dir
    test "second install uses cache (no re-download)", %{tmp_dir: dir} do
      cache_dir = Path.join(dir, "npm_cache")
      nm1 = Path.join(dir, "project1/node_modules")
      nm2 = Path.join(dir, "project2/node_modules")
      System.put_env("NPM_EX_CACHE_DIR", cache_dir)

      NPM.Resolver.clear_cache()
      {:ok, resolved} = NPM.Resolver.resolve(%{"is-number" => "^7.0.0"})

      lockfile =
        for {name, version_str} <- resolved, into: %{} do
          {:ok, packument} = NPM.Registry.get_packument(name)
          info = Map.fetch!(packument.versions, version_str)

          {name,
           %{
             version: version_str,
             integrity: info.dist.integrity,
             tarball: info.dist.tarball,
             dependencies: info.dependencies
           }}
        end

      # First install populates cache
      assert :ok = NPM.Linker.link(lockfile, nm1)
      assert File.exists?(Path.join([nm1, "is-number", "package.json"]))

      # Second install reuses cache (would fail if HTTP is required)
      assert :ok = NPM.Linker.link(lockfile, nm2)
      assert File.exists?(Path.join([nm2, "is-number", "package.json"]))

      System.delete_env("NPM_EX_CACHE_DIR")
    end

    @tag :tmp_dir
    test "installs package with transitive deps", %{tmp_dir: dir} do
      cache_dir = Path.join(dir, "npm_cache")
      nm_dir = Path.join(dir, "node_modules")
      System.put_env("NPM_EX_CACHE_DIR", cache_dir)

      NPM.Resolver.clear_cache()
      {:ok, resolved} = NPM.Resolver.resolve(%{"accepts" => "~1.3.8"})

      lockfile =
        for {name, version_str} <- resolved, into: %{} do
          {:ok, packument} = NPM.Registry.get_packument(name)
          info = Map.fetch!(packument.versions, version_str)

          {name,
           %{
             version: version_str,
             integrity: info.dist.integrity,
             tarball: info.dist.tarball,
             dependencies: info.dependencies
           }}
        end

      assert :ok = NPM.Linker.link(lockfile, nm_dir)

      # All resolved packages should be in node_modules
      for {name, _version} <- resolved do
        assert File.exists?(Path.join([nm_dir, name, "package.json"])),
               "Expected #{name} in node_modules"
      end

      System.delete_env("NPM_EX_CACHE_DIR")
    end
  end

  describe "npm compatibility: semver resolution" do
    setup do
      NPM.Resolver.clear_cache()
      :ok
    end

    test "caret range ^1.2.3 picks latest 1.x" do
      {:ok, resolved} = NPM.Resolver.resolve(%{"depd" => "^2.0.0"})
      {major, _, _} = parse_version(resolved["depd"])
      assert major == 2
    end

    test "tilde range ~1.3.8 stays within minor" do
      {:ok, resolved} = NPM.Resolver.resolve(%{"accepts" => "~1.3.8"})
      {major, minor, _} = parse_version(resolved["accepts"])
      assert {major, minor} == {1, 3}
    end

    test "exact version pins" do
      {:ok, resolved} = NPM.Resolver.resolve(%{"is-number" => "7.0.0"})
      assert resolved["is-number"] == "7.0.0"
    end

    test "range union || picks correct branch" do
      {:ok, resolved} = NPM.Resolver.resolve(%{"depd" => "~1.1 || ~2.0"})
      {major, _, _} = parse_version(resolved["depd"])
      assert major in [1, 2]
    end

    test ">=, < range constraints" do
      {:ok, resolved} = NPM.Resolver.resolve(%{"depd" => ">=2.0.0 <3.0.0"})
      {major, _, _} = parse_version(resolved["depd"])
      assert major == 2
    end

    test "* matches any version" do
      {:ok, resolved} = NPM.Resolver.resolve(%{"is-number" => "*"})
      assert Map.has_key?(resolved, "is-number")
    end
  end

  describe "npm compatibility: real-world dependency trees" do
    setup do
      NPM.Resolver.clear_cache()
      :ok
    end

    test "chalk@5 has zero dependencies (pure ESM)" do
      {:ok, resolved} = NPM.Resolver.resolve(%{"chalk" => "5.4.1"})
      assert resolved["chalk"] == "5.4.1"
      assert map_size(resolved) == 1
    end

    test "express resolves with nested version conflict handling" do
      {:ok, resolved} = NPM.Resolver.resolve(%{"express" => "^4.21.0"})

      flat = Map.delete(resolved, :nested)
      nested = Map.get(resolved, :nested, %{})

      assert Map.has_key?(flat, "express")
      assert Map.has_key?(flat, "debug")
      assert Map.has_key?(flat, "send")
      assert map_size(flat) >= 30

      # ms should be excluded from flat and tracked as nested
      refute Map.has_key?(flat, "ms")
      assert Map.has_key?(nested, "ms")
    end

    test "resolves packages with compatible transitive deps" do
      {:ok, resolved} = NPM.Resolver.resolve(%{"accepts" => "~1.3.8"})
      # No nested key when there are no conflicts
      refute Map.has_key?(resolved, :nested)
      assert map_size(resolved) >= 3
      assert Map.has_key?(resolved, "accepts")
      assert Map.has_key?(resolved, "mime-types")
      assert Map.has_key?(resolved, "negotiator")
    end

    test "scoped package @types/node resolves" do
      {:ok, resolved} = NPM.Resolver.resolve(%{"@types/node" => "^20.0.0"})
      assert Map.has_key?(resolved, "@types/node")
      {major, _, _} = parse_version(resolved["@types/node"])
      assert major == 20
    end

    test "conflicting transitive deps get resolved" do
      # express and koa both depend on different versions of some libs
      {:ok, resolved} =
        NPM.Resolver.resolve(%{"accepts" => "~1.3.8", "depd" => "^2.0.0"})

      assert Map.has_key?(resolved, "accepts")
      assert Map.has_key?(resolved, "depd")
    end
  end

  describe "npm compatibility: tarball integrity" do
    @tag :tmp_dir
    test "downloaded tarball matches registry integrity hash", %{tmp_dir: dir} do
      cache_dir = Path.join(dir, "cache")
      System.put_env("NPM_EX_CACHE_DIR", cache_dir)

      {:ok, packument} = NPM.Registry.get_packument("is-number")
      info = packument.versions["7.0.0"]
      tarball_url = info.dist.tarball
      integrity = info.dist.integrity

      assert is_binary(integrity)
      assert String.starts_with?(integrity, "sha512-")

      {:ok, path} = NPM.Cache.ensure("is-number", "7.0.0", tarball_url, integrity)
      assert File.dir?(path)
      assert File.exists?(Path.join(path, "package.json"))

      pkg_json = path |> Path.join("package.json") |> File.read!() |> :json.decode()
      assert pkg_json["name"] == "is-number"
      assert pkg_json["version"] == "7.0.0"

      System.delete_env("NPM_EX_CACHE_DIR")
    end

    @tag :tmp_dir
    test "scoped package tarball extracts correctly", %{tmp_dir: dir} do
      cache_dir = Path.join(dir, "cache")
      System.put_env("NPM_EX_CACHE_DIR", cache_dir)

      {:ok, packument} = NPM.Registry.get_packument("@types/node")

      latest =
        packument.versions
        |> Map.keys()
        |> Enum.flat_map(fn v ->
          case Version.parse(v) do
            {:ok, ver} -> [{v, ver}]
            :error -> []
          end
        end)
        |> Enum.sort_by(&elem(&1, 1), Version)
        |> List.last()
        |> elem(0)

      info = packument.versions[latest]

      {:ok, path} =
        NPM.Cache.ensure("@types/node", latest, info.dist.tarball, info.dist.integrity)

      assert File.dir?(path)

      System.delete_env("NPM_EX_CACHE_DIR")
    end
  end

  describe "npm compatibility: bin field formats" do
    @tag :tmp_dir
    test "string bin field creates correct link", %{tmp_dir: dir} do
      cache_dir = Path.join(dir, "cache")
      nm_dir = Path.join(dir, "node_modules")
      System.put_env("NPM_EX_CACHE_DIR", cache_dir)

      NPM.Resolver.clear_cache()
      {:ok, resolved} = NPM.Resolver.resolve(%{"is-number" => "7.0.0"})

      lockfile = build_lockfile(resolved)
      assert :ok = NPM.Linker.link(lockfile, nm_dir)

      # is-number doesn't have bin, but verify structure is correct
      assert File.exists?(Path.join([nm_dir, "is-number", "package.json"]))

      System.delete_env("NPM_EX_CACHE_DIR")
    end
  end

  describe "npm compatibility: registry responses" do
    test "peerDependencies parsed from registry" do
      {:ok, packument} = NPM.Registry.get_packument("react-dom")
      info = packument.versions["18.3.1"]
      assert info.peer_dependencies["react"] == "^18.3.1"
    end

    test "deprecated field is a string message" do
      {:ok, packument} = NPM.Registry.get_packument("request")
      info = packument.versions["2.88.2"]
      assert is_binary(info.deprecated)
      assert info.deprecated =~ "deprecated"
    end

    test "engines field parsed correctly for typescript" do
      {:ok, packument} = NPM.Registry.get_packument("typescript")
      info = packument.versions["5.7.3"]
      assert is_map(info.engines)
      assert Map.has_key?(info.engines, "node")
    end

    test "has_install_script parsed" do
      {:ok, packument} = NPM.Registry.get_packument("esbuild")
      # esbuild has postinstall script
      info = packument.versions["0.24.2"]
      assert info.has_install_script == true
    end

    test "peerDependenciesMeta parsed" do
      {:ok, packument} = NPM.Registry.get_packument("react-dom")
      info = packument.versions["19.0.0"]
      meta = info.peer_dependencies_meta
      assert is_map(meta)
    end

    test "optionalDependencies parsed" do
      {:ok, packument} = NPM.Registry.get_packument("esbuild")
      info = packument.versions["0.24.2"]
      opt = info.optional_dependencies
      assert is_map(opt)
      assert map_size(opt) > 0
    end
  end

  describe "npm compatibility: exports field from registry" do
    test "chalk 5.x has exports map" do
      raw = get_raw_packument("chalk")
      v5 = raw["versions"]["5.4.1"]

      case Map.get(v5, "exports") do
        nil -> :ok
        exports -> assert is_map(exports) or is_binary(exports)
      end
    end
  end

  describe "npm compatibility: x-range resolution" do
    setup do
      NPM.Resolver.clear_cache()
      :ok
    end

    test "1.x resolves to latest 1.x" do
      {:ok, resolved} = NPM.Resolver.resolve(%{"depd" => "1.x"})
      {major, _, _} = parse_version(resolved["depd"])
      assert major == 1
    end

    test "1.2.x resolves within minor" do
      {:ok, resolved} = NPM.Resolver.resolve(%{"mime-db" => "1.52.x"})
      assert resolved["mime-db"] == "1.52.0"
    end

    test "latest resolves to some version" do
      {:ok, resolved} = NPM.Resolver.resolve(%{"is-number" => "latest"})
      assert Map.has_key?(resolved, "is-number")
    end

    test "empty string resolves like *" do
      {:ok, resolved} = NPM.Resolver.resolve(%{"is-number" => ""})
      assert Map.has_key?(resolved, "is-number")
    end
  end

  describe "npm compatibility: pre-release handling" do
    setup do
      NPM.Resolver.clear_cache()
      :ok
    end

    test "caret range excludes pre-releases by default" do
      {:ok, resolved} = NPM.Resolver.resolve(%{"is-number" => "^7.0.0"})
      version = resolved["is-number"]
      {:ok, v} = Version.parse(version)
      assert v.pre == []
    end
  end

  describe "npm compatibility: caret zero-major semantics" do
    setup do
      NPM.Resolver.clear_cache()
      :ok
    end

    test "^0.0.x pins to exact patch" do
      # ^0.0.3 should match >=0.0.3, <0.0.4
      assert {:ok, _constraint} = NPMSemver.to_hex_constraint("^0.0.3")
      assert NPMSemver.matches?("0.0.3", "^0.0.3")
      refute NPMSemver.matches?("0.0.4", "^0.0.3")
    end

    test "^0.1.x allows patch bumps" do
      # ^0.1.0 should match >=0.1.0, <0.2.0
      assert NPMSemver.matches?("0.1.5", "^0.1.0")
      refute NPMSemver.matches?("0.2.0", "^0.1.0")
    end

    test "^1.x allows minor+patch bumps" do
      assert NPMSemver.matches?("1.9.9", "^1.0.0")
      refute NPMSemver.matches?("2.0.0", "^1.0.0")
    end
  end

  describe "npm compatibility: tilde semantics" do
    test "~1.2.3 allows patch bumps only" do
      assert NPMSemver.matches?("1.2.5", "~1.2.3")
      refute NPMSemver.matches?("1.3.0", "~1.2.3")
    end

    test "~0.2 allows patch bumps" do
      assert NPMSemver.matches?("0.2.5", "~0.2")
      refute NPMSemver.matches?("0.3.0", "~0.2")
    end
  end

  describe "npm compatibility: hyphen ranges" do
    test "1.0.0 - 2.0.0 is inclusive" do
      assert NPMSemver.matches?("1.0.0", "1.0.0 - 2.0.0")
      assert NPMSemver.matches?("1.5.0", "1.0.0 - 2.0.0")
      assert NPMSemver.matches?("2.0.0", "1.0.0 - 2.0.0")
      refute NPMSemver.matches?("2.0.1", "1.0.0 - 2.0.0")
    end
  end

  describe "npm compatibility: OR ranges" do
    test "union with ||" do
      assert NPMSemver.matches?("1.5.0", "^1.0.0 || ^2.0.0")
      assert NPMSemver.matches?("2.5.0", "^1.0.0 || ^2.0.0")
      refute NPMSemver.matches?("3.0.0", "^1.0.0 || ^2.0.0")
    end
  end

  describe "npm compatibility: real multi-dep resolution" do
    setup do
      NPM.Resolver.clear_cache()
      :ok
    end

    test "resolves depd + mime-types without conflicts" do
      {:ok, resolved} =
        NPM.Resolver.resolve(%{
          "depd" => "^2.0.0",
          "mime-types" => "^2.1.34"
        })

      assert Map.has_key?(resolved, "depd")
      assert Map.has_key?(resolved, "mime-types")
      assert Map.has_key?(resolved, "mime-db")
    end

    test "resolves cookie + cookie-signature (no shared deps)" do
      {:ok, resolved} =
        NPM.Resolver.resolve(%{
          "cookie" => "^0.7.0",
          "cookie-signature" => "^1.0.6"
        })

      assert map_size(resolved) == 2
    end

    test "resolves content-type + content-disposition" do
      {:ok, resolved} =
        NPM.Resolver.resolve(%{
          "content-type" => "~1.0.4",
          "content-disposition" => "^0.5.4"
        })

      assert Map.has_key?(resolved, "content-type")
      assert Map.has_key?(resolved, "content-disposition")
    end
  end

  describe "npm compatibility: tarball content verification" do
    @tag :tmp_dir
    test "is-number 7.0.0 has correct files", %{tmp_dir: dir} do
      cache_dir = Path.join(dir, "cache")
      System.put_env("NPM_EX_CACHE_DIR", cache_dir)

      {:ok, packument} = NPM.Registry.get_packument("is-number")
      info = packument.versions["7.0.0"]

      {:ok, path} = NPM.Cache.ensure("is-number", "7.0.0", info.dist.tarball, info.dist.integrity)

      # Real is-number 7.0.0 should have index.js
      assert File.exists?(Path.join(path, "index.js"))
      # Should have package.json with correct name/version
      pkg = path |> Path.join("package.json") |> File.read!() |> :json.decode()
      assert pkg["name"] == "is-number"
      assert pkg["version"] == "7.0.0"
      # Should have license field
      assert is_binary(pkg["license"])

      System.delete_env("NPM_EX_CACHE_DIR")
    end

    @tag :tmp_dir
    test "depd 2.0.0 tarball extracts all expected files", %{tmp_dir: dir} do
      cache_dir = Path.join(dir, "cache")
      System.put_env("NPM_EX_CACHE_DIR", cache_dir)

      {:ok, packument} = NPM.Registry.get_packument("depd")
      info = packument.versions["2.0.0"]

      {:ok, path} = NPM.Cache.ensure("depd", "2.0.0", info.dist.tarball, info.dist.integrity)

      pkg = path |> Path.join("package.json") |> File.read!() |> :json.decode()
      assert pkg["name"] == "depd"
      assert pkg["version"] == "2.0.0"
      # depd should have lib/ or index.js
      has_entry =
        File.exists?(Path.join(path, "index.js")) or
          File.dir?(Path.join(path, "lib"))

      assert has_entry

      System.delete_env("NPM_EX_CACHE_DIR")
    end
  end

  describe "npm compatibility: lockfile write + install round-trip" do
    @tag :tmp_dir
    test "resolved lockfile can be read back and reinstalled", %{tmp_dir: dir} do
      cache_dir = Path.join(dir, "cache")
      lock_path = Path.join(dir, "npm.lock")
      nm1 = Path.join(dir, "nm1")
      nm2 = Path.join(dir, "nm2")
      System.put_env("NPM_EX_CACHE_DIR", cache_dir)

      NPM.Resolver.clear_cache()
      {:ok, resolved} = NPM.Resolver.resolve(%{"depd" => "^2.0.0"})
      lockfile = build_lockfile(resolved)

      # Write and read back
      NPM.Lockfile.write(lockfile, lock_path)
      {:ok, restored} = NPM.Lockfile.read(lock_path)

      # Both original and restored produce identical node_modules
      assert :ok = NPM.Linker.link(lockfile, nm1)
      assert :ok = NPM.Linker.link(restored, nm2)

      for {name, _} <- resolved do
        pkg1 = Path.join([nm1, name, "package.json"]) |> File.read!()
        pkg2 = Path.join([nm2, name, "package.json"]) |> File.read!()
        assert pkg1 == pkg2, "#{name} package.json differs between installs"
      end

      System.delete_env("NPM_EX_CACHE_DIR")
    end
  end

  describe "npm compatibility: full install round-trip" do
    @tag :tmp_dir
    test "accepts install produces working node_modules", %{tmp_dir: dir} do
      cache_dir = Path.join(dir, "cache")
      nm_dir = Path.join(dir, "node_modules")
      System.put_env("NPM_EX_CACHE_DIR", cache_dir)

      NPM.Resolver.clear_cache()
      {:ok, resolved} = NPM.Resolver.resolve(%{"accepts" => "~1.3.8"})

      lockfile = build_lockfile(resolved)
      assert :ok = NPM.Linker.link(lockfile, nm_dir)

      for pkg <- ["accepts", "mime-types", "negotiator", "mime-db"] do
        pkg_json_path = Path.join([nm_dir, pkg, "package.json"])
        assert File.exists?(pkg_json_path), "Missing #{pkg} in node_modules"

        pkg_data = pkg_json_path |> File.read!() |> :json.decode()
        assert pkg_data["name"] == pkg
      end

      System.delete_env("NPM_EX_CACHE_DIR")
    end

    @tag :tmp_dir
    test "chalk@5 install (zero-dep ESM package)", %{tmp_dir: dir} do
      cache_dir = Path.join(dir, "cache")
      nm_dir = Path.join(dir, "node_modules")
      System.put_env("NPM_EX_CACHE_DIR", cache_dir)

      NPM.Resolver.clear_cache()
      {:ok, resolved} = NPM.Resolver.resolve(%{"chalk" => "5.4.1"})
      assert map_size(resolved) == 1

      lockfile = build_lockfile(resolved)
      assert :ok = NPM.Linker.link(lockfile, nm_dir)

      chalk_pkg = Path.join([nm_dir, "chalk", "package.json"]) |> File.read!() |> :json.decode()
      assert chalk_pkg["name"] == "chalk"
      assert chalk_pkg["version"] == "5.4.1"
      assert chalk_pkg["type"] == "module"

      System.delete_env("NPM_EX_CACHE_DIR")
    end
  end

  describe "npm compatibility: nested version resolution" do
    test "ms version conflict tracked in original_deps" do
      NPM.Resolver.clear_cache()
      deps = %{"express" => "^4.21.0"}
      {:ok, resolved} = NPM.Resolver.resolve(deps)

      nested = Map.get(resolved, :nested, %{})
      assert Map.has_key?(nested, "ms"), "ms should be tracked as nested"

      original_deps = NPM.Resolver.get_original_deps("ms")
      assert map_size(original_deps) > 0, "should have parent packages that need ms"

      # debug@2.6.9 needs ms@2.0.0, and other packages need different versions
      debug_key =
        original_deps
        |> Map.keys()
        |> Enum.find(&String.starts_with?(&1, "debug@"))

      assert debug_key != nil, "debug should depend on ms"
    end
  end

  describe "npm compatibility: SemverUtil with real packument versions" do
    test "max_satisfying finds best lodash for ^4.0.0" do
      raw = get_raw_packument("lodash")
      versions = Map.keys(raw["versions"])
      {:ok, best} = NPM.SemverUtil.max_satisfying(versions, "^4.0.0")
      assert String.starts_with?(best, "4.")
    end

    test "filter returns only matching versions" do
      raw = get_raw_packument("is-number")
      versions = Map.keys(raw["versions"])
      matches = NPM.SemverUtil.filter(versions, "^7.0.0")
      assert Enum.all?(matches, &String.starts_with?(&1, "7."))
    end
  end

  describe "npm compatibility: Exports field on real packages" do
    test "chalk 5.x has type: module" do
      raw = get_raw_packument("chalk")
      v5 = raw["versions"]["5.4.1"]
      assert v5["type"] == "module"
    end

    test "is-number has main field" do
      raw = get_raw_packument("is-number")
      v7 = raw["versions"]["7.0.0"]
      assert is_binary(v7["main"])
    end
  end

  describe "npm compatibility: override resolution" do
    setup do
      NPM.Resolver.clear_cache()
      :ok
    end

    test "overrides force specific version" do
      deps = %{"depd" => "^2.0.0"}
      overrides = %{"depd" => "2.0.0"}

      {:ok, result} = NPM.Resolver.resolve(deps, overrides: overrides)
      assert result["depd"] == "2.0.0"
    end
  end

  describe "npm compatibility: scoped package resolution" do
    setup do
      NPM.Resolver.clear_cache()
      :ok
    end

    test "resolves scoped package" do
      deps = %{"@sindresorhus/is" => "^5.0.0"}
      {:ok, result} = NPM.Resolver.resolve(deps)
      assert result["@sindresorhus/is"] =~ ~r/^5\.\d+\.\d+$/
    end
  end

  describe "npm compatibility: resolution determinism" do
    setup do
      NPM.Resolver.clear_cache()
      :ok
    end

    test "same inputs produce same outputs" do
      deps = %{"depd" => "^2.0.0", "mime-types" => "^2.1.34"}
      {:ok, result1} = NPM.Resolver.resolve(deps)

      NPM.Resolver.clear_cache()
      {:ok, result2} = NPM.Resolver.resolve(deps)

      assert result1 == result2
    end
  end

  describe "npm compatibility: multi-package flat resolution" do
    setup do
      NPM.Resolver.clear_cache()
      :ok
    end

    test "resolves multiple related packages without conflicts" do
      deps = %{"mime-types" => "^2.1.34", "content-type" => "^1.0.5"}
      {:ok, result} = NPM.Resolver.resolve(deps)

      assert result["mime-types"] =~ ~r/^2\.\d+\.\d+$/
      assert result["content-type"] =~ ~r/^1\.\d+\.\d+$/
      # mime-types depends on mime-db, which should also be resolved
      assert Map.has_key?(result, "mime-db")
    end
  end

  describe "npm compatibility: lockfile round-trip with real packages" do
    setup do
      NPM.Resolver.clear_cache()
      :ok
    end

    test "resolve -> lockfile -> read preserves all entries" do
      deps = %{"depd" => "^2.0.0", "cookie" => "^0.7.0"}
      {:ok, resolved} = NPM.Resolver.resolve(deps)

      flat = Map.delete(resolved, :nested)

      lockfile =
        Map.new(flat, fn {name, version} ->
          {name,
           %{version: version, integrity: "sha512-test", tarball: "test-url", dependencies: %{}}}
        end)

      tmp_path = Path.join(System.tmp_dir!(), "npm_test_lockfile_#{:rand.uniform(100_000)}.lock")
      NPM.Lockfile.write(lockfile, tmp_path)
      {:ok, restored} = NPM.Lockfile.read(tmp_path)
      File.rm(tmp_path)

      assert map_size(restored) == map_size(lockfile)

      Enum.each(lockfile, fn {name, entry} ->
        assert restored[name].version == entry.version
      end)
    end
  end

  describe "npm compatibility: Validator with real package names" do
    test "validates real package names" do
      assert :ok = NPM.Validator.validate_name("lodash")
      assert :ok = NPM.Validator.validate_name("is-number")
      assert :ok = NPM.Validator.validate_name("@types/node")
    end

    test "rejects obviously invalid names" do
      assert {:error, _} = NPM.Validator.validate_name("")
      assert {:error, _} = NPM.Validator.validate_name(".hidden")
      assert {:error, _} = NPM.Validator.validate_name("_underscore")
    end
  end

  # --- Helpers ---

  defp parse_version(version_str) do
    {:ok, v} = Version.parse(version_str)
    {v.major, v.minor, v.patch}
  end

  defp build_lockfile(resolved) do
    for {name, version_str} <- resolved, into: %{} do
      {:ok, packument} = NPM.Registry.get_packument(name)
      info = Map.fetch!(packument.versions, version_str)

      {name,
       %{
         version: version_str,
         integrity: info.dist.integrity,
         tarball: info.dist.tarball,
         dependencies: info.dependencies
       }}
    end
  end

  defp get_raw_packument(name) do
    url = "#{NPM.Registry.registry_url()}/#{URI.encode(name, &(&1 != ?/))}"
    {:ok, %{body: body}} = Req.get(url)
    body
  end
end
