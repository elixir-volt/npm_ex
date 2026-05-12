defmodule NPM.EdgeCases6Test do
  use ExUnit.Case, async: true

  describe "BundleAnalysis + TypeField" do
    test "CJS-only package scores 0 for ESM" do
      data = %{"main" => "./index.js", "type" => "commonjs"}
      score = NPM.BundleAnalysis.score(data)
      assert score < 10
    end
  end

  describe "Migration + PackageLock" do
    test "lockfile v3 needs npm 9+" do
      assert 3 = NPM.Migration.lockfile_version("9.0.0")
      assert NPM.Lockfile.PackageLock.requires_npm7?(%{"lockfileVersion" => 3})
    end
  end

  describe "Diagnostics edge cases" do
    @tag :tmp_dir
    test "clean npmrc no warning", %{tmp_dir: dir} do
      File.write!(Path.join(dir, "package.json"), "{}")
      File.write!(Path.join(dir, "npm.lock"), "")
      File.mkdir_p!(Path.join(dir, "node_modules"))
      File.write!(Path.join(dir, ".npmrc"), "registry=https://npm.com\n")
      issues = NPM.Diagnostics.run(dir)
      refute Enum.any?(issues, &(&1.check == "npmrc"))
    end
  end

  describe "PackageQuality + Validate" do
    test "invalid package has low quality" do
      data = %{}
      refute NPM.Validate.valid?(data)
      score = NPM.Package.Quality.score(data)
      assert score <= 5
    end
  end

  describe "SupplyChain + LockfileStats" do
    test "both analyze integrity" do
      lockfile = %{
        "a" => %{version: "1.0", integrity: "sha512-abc"},
        "b" => %{version: "2.0"}
      }

      stats = NPM.Lockfile.Stats.content_stats(lockfile)
      assert stats.with_integrity == 1

      chain =
        NPM.Security.SupplyChain.assess(
          %{"dependencies" => %{"a" => "^1", "b" => "^2"}},
          lockfile
        )

      assert chain.integrity_coverage == 50.0
    end
  end

  describe "ImportMap edge cases" do
    test "generates for string version entry" do
      lockfile = %{"pkg" => %{"version" => "3.0.0"}}
      map = NPM.ImportMap.generate(lockfile)
      assert map["imports"]["pkg"] == "https://esm.sh/pkg@3.0.0"
    end

    test "merge with empty base" do
      base = %{"imports" => %{}}
      override = %{"imports" => %{"react" => "https://esm.sh/react@18.2.0"}}
      merged = NPM.ImportMap.merge(base, override)
      assert Map.has_key?(merged["imports"], "react")
    end
  end

  describe "Conditional + Exports" do
    test "resolve string export directly" do
      assert "./index.js" = NPM.Resolution.Conditional.resolve("./index.js", ["import"])
    end
  end

  describe "DepStats + Scope" do
    test "top_scopes works with single scope" do
      lockfile = %{"@types/node" => %{version: "18.0.0"}}
      scopes = NPM.Dependency.Stats.top_scopes(lockfile)
      assert [{"types", 1}] = scopes
    end
  end

  describe "PhantomDep + DepRange" do
    test "phantom dep has a range type in lockfile" do
      pkg = %{"dependencies" => %{"express" => "^4.18"}}
      lockfile = %{"express" => %{version: "4.18.2"}, "debug" => %{version: "4.3.4"}}
      phantoms = NPM.Dependency.Phantom.detect(pkg, lockfile)
      assert "debug" in phantoms
    end
  end

  describe "SnapshotDiff + TreeFormat" do
    test "tree count changes with diff" do
      old = %{"a" => %{version: "1.0"}}
      new = %{"a" => %{version: "1.0"}, "b" => %{version: "2.0"}}
      d = NPM.SnapshotDiff.diff(old, new)
      assert "b" in d.added
      assert NPM.TreeFormat.count(new) == 2
    end
  end

  describe "Compat + NodeVersion" do
    test "normalize then check compat" do
      version = NPM.NodeVersion.normalize("20")
      data = %{"engines" => %{"node" => ">=18"}}
      assert NPM.Compat.compatible?(data, version)
    end
  end

  describe "PeerDep + Validate" do
    test "valid peer deps format" do
      data = %{"name" => "pkg", "version" => "1.0.0", "peerDependencies" => %{"react" => "^18.0"}}
      assert NPM.Validate.valid?(data)
      peers = NPM.Dependency.Peer.extract(data)
      assert peers["react"] == "^18.0"
    end
  end

  describe "Funding + Repository" do
    test "package with both" do
      data = %{
        "funding" => "https://github.com/sponsors/user",
        "repository" => "user/repo"
      }

      assert NPM.Package.Funding.has_funding?(data)
      assert NPM.Package.Repository.has_repository?(data)
    end
  end

  describe "Corepack + Engines" do
    test "pnpm project with node engine" do
      data = %{
        "packageManager" => "pnpm@8.10.0",
        "engines" => %{"node" => ">=18"}
      }

      assert NPM.Corepack.pnpm?(data)
      assert NPM.Engines.node_range(data) == ">=18"
    end
  end

  describe "SideEffects + PackageFiles" do
    test "tree-shakeable with files whitelist" do
      data = %{"sideEffects" => false, "files" => ["dist/"]}
      assert NPM.SideEffects.tree_shakeable?(data)
      assert NPM.Package.Files.has_whitelist?(data)
    end
  end

  describe "Npmrc + RegistryUrl" do
    test "parsed registry used for URL" do
      config = NPM.Npmrc.parse("registry=https://custom.registry.io")
      url = NPM.RegistryUrl.package_url("lodash", config["registry"])
      assert url =~ "custom.registry.io"
    end
  end
end
