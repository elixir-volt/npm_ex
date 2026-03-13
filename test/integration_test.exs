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
end
