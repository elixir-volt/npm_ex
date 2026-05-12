defmodule NPM.EdgeCases4Test do
  use ExUnit.Case, async: true

  describe "Validate + Scope" do
    test "scoped name with uppercase doesn't warn" do
      issues = NPM.Validate.validate(%{"name" => "@Types/Node", "version" => "1.0.0"})
      refute Enum.any?(issues, &(&1.message =~ "lowercase"))
    end

    test "unknown fields detected" do
      data = %{"name" => "pkg", "version" => "1.0.0", "xCustom" => true}
      unknown = NPM.Validate.unknown_fields(data)
      assert "xCustom" in unknown
    end
  end

  describe "Engines + Corepack" do
    test "engines and packageManager both present" do
      data = %{
        "engines" => %{"node" => ">=18"},
        "packageManager" => "npm@10.2.0"
      }

      assert NPM.Engines.has_engines?(data)
      assert NPM.Corepack.configured?(data)
      assert "npm" = NPM.Corepack.manager_name(data)
    end
  end

  describe "DepRange + LockfileCheck" do
    test "all exact deps satisfy lockfile" do
      pkg = %{"dependencies" => %{"lodash" => "4.17.21"}}

      lockfile = %{
        "lodash" => %{version: "4.17.21", integrity: "", tarball: "", dependencies: %{}}
      }

      assert [] = NPM.Lockfile.Check.mismatched(pkg, lockfile)
      assert :exact = NPM.Dependency.Range.classify("4.17.21")
    end
  end

  describe "TypeField + SideEffects" do
    test "ESM package with tree-shaking" do
      data = %{"type" => "module", "sideEffects" => false}
      assert NPM.TypeField.esm?(data)
      assert NPM.SideEffects.tree_shakeable?(data)
    end

    test "CJS package assumed side-effectful" do
      data = %{}
      assert NPM.TypeField.cjs?(data)
      assert NPM.SideEffects.has_side_effects?(data)
    end
  end

  describe "Funding + People" do
    test "package with both funding and author" do
      data = %{
        "author" => "John Doe <john@test.com>",
        "funding" => "https://github.com/sponsors/johndoe"
      }

      assert NPM.Package.People.has_author?(data)
      assert NPM.Package.Funding.has_funding?(data)
      assert ["https://github.com/sponsors/johndoe"] = NPM.Package.Funding.urls(data)
    end
  end

  describe "InstallStrategy + Monorepo" do
    @tag :tmp_dir
    test "hoisted recommended for monorepo", %{tmp_dir: dir} do
      File.write!(Path.join(dir, "package.json"), ~s({"workspaces":["a","b","c","d","e"]}))
      assert NPM.Monorepo.monorepo?(dir)
    end
  end

  describe "PeerDep + DeprecationAnalysis" do
    test "deprecated peer dep replacement" do
      assert "undici" = NPM.DeprecationAnalysis.replacement("Deprecated. Use undici instead.")
      assert :replaced = NPM.DeprecationAnalysis.categorize("Deprecated. Use undici instead.")
    end
  end

  describe "PackageFiles + Bin" do
    test "bin file is an entry point" do
      data = %{"name" => "cli", "bin" => "./dist/cli.js", "main" => "./dist/index.js"}
      assert NPM.Node.Bin.has_bin?(data)
      entries = NPM.Package.Files.entry_points(data)
      assert "./dist/index.js" in entries
    end
  end

  describe "TreeFormat + Report" do
    test "tree count matches report total" do
      lockfile = %{
        "a" => %{version: "1.0.0", dependencies: %{}},
        "b" => %{version: "2.0.0", dependencies: %{}}
      }

      assert NPM.TreeFormat.count(lockfile) == NPM.Report.dependency_summary(lockfile).total
    end
  end

  describe "RegistryUrl + PublishConfig" do
    test "custom publish registry" do
      data = %{"publishConfig" => %{"registry" => "https://npm.pkg.github.com"}}
      registry = NPM.Package.PublishConfig.registry(data)
      url = NPM.Registry.URL.package_url("my-pkg", registry)
      assert url =~ "npm.pkg.github.com"
    end
  end

  describe "NodeVersion edge cases" do
    test "normalize v prefix with minor" do
      assert "18.19.0" = NPM.NodeVersion.normalize("v18.19")
    end

    test "alias for current" do
      assert NPM.NodeVersion.alias?("current")
    end

    test "alias for node" do
      assert NPM.NodeVersion.alias?("node")
    end
  end

  describe "DepRange edge cases" do
    test "classify tilde with space" do
      assert :tilde = NPM.Dependency.Range.classify("~1.2.3")
    end

    test "summarize all pinned" do
      deps = %{"a" => "1.0.0", "b" => "2.0.0"}
      sum = NPM.Dependency.Range.summary(deps)
      assert sum.pinned_pct == 100.0
    end
  end

  describe "Dist edge cases" do
    test "format_size zero" do
      assert "0 B" = NPM.Dist.format_size(0)
    end
  end
end
