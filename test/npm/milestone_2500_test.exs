defmodule NPM.Milestone2500Test do
  use ExUnit.Case, async: true

  describe "DepFreshness + SnapshotDiff" do
    test "freshness changes after update" do
      old = %{"lodash" => %{version: "4.17.0"}}
      new = %{"lodash" => %{version: "4.17.21"}}
      diff = NPM.SnapshotDiff.diff(old, new)
      assert hd(diff.updated).to == "4.17.21"
      assert :current = NPM.Dependency.Freshness.classify("4.17.21", "4.17.21")
    end
  end

  describe "Validate + PackageQuality" do
    test "valid high-quality package" do
      data = %{
        "name" => "good",
        "version" => "1.0.0",
        "description" => "A package",
        "license" => "MIT",
        "repository" => "user/repo",
        "keywords" => ["test"],
        "engines" => %{"node" => ">=18"},
        "types" => "./index.d.ts",
        "exports" => %{"." => "./index.js"},
        "files" => ["dist/"],
        "author" => "Author"
      }

      assert NPM.Validate.valid?(data)
      assert NPM.Package.Quality.score(data) >= 80
    end
  end

  describe "LockfileStats + Report" do
    test "both count packages" do
      lockfile = %{
        "a" => %{version: "1.0", integrity: "sha512-x", dependencies: %{}},
        "b" => %{version: "2.0", integrity: "sha512-y", dependencies: %{}}
      }

      stats = NPM.Lockfile.Stats.content_stats(lockfile)
      report = NPM.Report.dependency_summary(lockfile)
      assert stats.total_packages == report.total
    end
  end

  describe "Diagnostics + NodeVersion" do
    @tag :tmp_dir
    test "project with .nvmrc", %{tmp_dir: dir} do
      File.write!(Path.join(dir, "package.json"), "{}")
      File.write!(Path.join(dir, "npm.lock"), "")
      File.mkdir_p!(Path.join(dir, "node_modules"))
      File.write!(Path.join(dir, ".nvmrc"), "v20.10.0\n")
      assert {:ok, "20.10.0", ".nvmrc"} = NPM.NodeVersion.detect(dir)
      issues = NPM.Diagnostics.run(dir)
      refute Enum.any?(issues, &(&1.level == :error))
    end
  end

  describe "BundleAnalysis + SideEffects" do
    test "tree-shakeable contributes to bundle score" do
      data = %{"sideEffects" => false}
      score = NPM.BundleAnalysis.score(data)
      assert score >= 25
    end
  end

  describe "InstallStrategy + HoistingConflict" do
    test "nested strategy avoids hoisting" do
      config = %{"install-strategy" => "nested"}
      assert :nested = NPM.InstallStrategy.detect(config)
      assert :infinity = NPM.InstallStrategy.max_depth(:nested)
    end
  end

  describe "Migration + Corepack" do
    test "npm version from corepack determines lockfile version" do
      data = %{"packageManager" => "npm@10.2.0"}
      version = NPM.Corepack.manager_version(data)
      assert 3 = NPM.Migration.lockfile_version(version)
    end
  end

  describe "DepRange + DepFreshness" do
    test "pinned deps are easier to track freshness" do
      assert :exact = NPM.Dependency.Range.classify("4.17.21")
      assert :current = NPM.Dependency.Freshness.classify("4.17.21", "4.17.21")
    end
  end

  describe "DepFreshness additional" do
    test "same major different patch is current" do
      assert :current = NPM.Dependency.Freshness.classify("4.17.0", "4.17.5")
    end

    test "group returns empty map for empty list" do
      assert %{} = NPM.Dependency.Freshness.group([])
    end

    test "format empty groups" do
      assert "" = NPM.Dependency.Freshness.format(%{})
    end
  end

  describe "LockfileCheck + DepRange" do
    test "file dep not checked by semver" do
      assert :file = NPM.Dependency.Range.classify("file:../local")
    end
  end

  describe "Workspaces + Monorepo" do
    @tag :tmp_dir
    test "workspaces implies monorepo", %{tmp_dir: dir} do
      File.write!(Path.join(dir, "package.json"), ~s({"workspaces":["packages/*"]}))
      data = %{"workspaces" => ["packages/*"]}
      assert NPM.Workspaces.configured?(data)
      assert NPM.Monorepo.monorepo?(dir)
    end
  end

  describe "Bin + DepPath" do
    test "bin path resolution" do
      data = %{"name" => "eslint", "bin" => %{"eslint" => "./bin/eslint.js"}}
      cmds = NPM.Node.Bin.commands(data)
      path = NPM.NodeModules.Path.bin_path(hd(cmds))
      assert path =~ ".bin/eslint"
    end
  end

  describe "Conditional + TypeField" do
    test "ESM package with conditional exports" do
      data = %{
        "type" => "module",
        "exports" => %{
          "." => %{"import" => "./dist/index.mjs", "require" => "./dist/index.cjs"}
        }
      }

      assert NPM.TypeField.esm?(data)
      entry = data["exports"]["."]
      assert "./dist/index.mjs" = NPM.Resolution.Conditional.resolve(entry, ["import"])
    end
  end
end
