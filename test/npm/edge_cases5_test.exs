defmodule NPM.EdgeCases5Test do
  use ExUnit.Case, async: true

  describe "Workspaces edge cases" do
    test "object format with packages" do
      data = %{"workspaces" => %{"packages" => ["apps/*"], "nohoist" => ["**/debug"]}}
      assert ["apps/*"] = NPM.Workspaces.globs(data)
    end

    test "count for object format" do
      data = %{"workspaces" => %{"packages" => ["a/*", "b/*"]}}
      assert 2 = NPM.Workspaces.count(data)
    end
  end

  describe "Npmrc edge cases" do
    test "semicolon comments" do
      config = NPM.Config.Npmrc.parse("; comment\nregistry=https://npm.com")
      assert config["registry"] == "https://npm.com"
    end

    test "merge preserves unique keys" do
      merged = NPM.Config.Npmrc.merge([%{"a" => "1"}, %{"b" => "2"}])
      assert merged["a"] == "1"
      assert merged["b"] == "2"
    end
  end

  describe "HoistingConflict edge cases" do
    test "no deps means no conflicts" do
      lockfile = %{"a" => %{version: "1.0.0"}, "b" => %{version: "2.0.0"}}
      refute NPM.HoistingConflict.conflicts?(lockfile)
    end
  end

  describe "SnapshotDiff edge cases" do
    test "diff with string version maps" do
      old = %{"pkg" => %{"version" => "1.0.0"}}
      new = %{"pkg" => %{"version" => "2.0.0"}}
      d = NPM.SnapshotDiff.diff(old, new)
      assert length(d.updated) == 1
    end

    test "added only" do
      d = NPM.SnapshotDiff.diff(%{}, %{"new-pkg" => %{version: "1.0.0"}})
      assert "new-pkg" in d.added
      assert d.removed == []
    end

    test "removed only" do
      d = NPM.SnapshotDiff.diff(%{"old-pkg" => %{version: "1.0.0"}}, %{})
      assert "old-pkg" in d.removed
      assert d.added == []
    end
  end

  describe "PhantomDep edge cases" do
    test "includes optionalDependencies in declared" do
      pkg = %{"optionalDependencies" => %{"fsevents" => "^2.0"}}
      refute NPM.Dependency.Phantom.phantom?("fsevents", pkg)
    end

    test "includes peerDependencies in declared" do
      pkg = %{"peerDependencies" => %{"react" => "^18.0"}}
      refute NPM.Dependency.Phantom.phantom?("react", pkg)
    end
  end

  describe "Conditional edge cases" do
    test "resolve nil exports" do
      assert nil == NPM.Resolution.Conditional.resolve(nil, ["import"])
    end

    test "conditions from nested exports" do
      exports = %{
        "node" => %{
          "import" => "./esm.mjs",
          "require" => "./cjs.js"
        }
      }

      conds = NPM.Resolution.Conditional.conditions(exports)
      assert "node" in conds
      assert "import" in conds
    end
  end

  describe "Compat + Engines" do
    test "package with no engines is always compatible" do
      assert NPM.Compat.compatible?(%{}, "12.0.0")
      refute NPM.Engines.has_engines?(%{})
    end
  end

  describe "DepPath edge cases" do
    test "nested scoped package" do
      path = NPM.NodeModules.Path.nested("express", "@types/express")
      assert path == "node_modules/express/node_modules/@types/express"
    end

    test "custom node_modules bin" do
      assert "custom_nm/.bin/tsc" = NPM.NodeModules.Path.bin_path("tsc", "custom_nm")
    end
  end

  describe "DepStats edge cases" do
    test "format with no scopes" do
      stats = NPM.Dependency.Stats.compute(%{"lodash" => %{version: "4.17.21"}})
      formatted = NPM.Dependency.Stats.format(stats)
      assert formatted =~ "Top scopes: none"
    end
  end

  describe "PublishConfig edge cases" do
    test "non-string publishConfig ignored" do
      assert %{} = NPM.Package.PublishConfig.extract(%{"publishConfig" => "invalid"})
    end
  end

  describe "Corepack edge cases" do
    test "non-string packageManager" do
      assert nil == NPM.Corepack.get(%{"packageManager" => 123})
    end
  end

  describe "LockfileCheck edge cases" do
    test "format_results missing only" do
      result = %{valid: false, missing: ["a", "b"], extraneous: [], mismatched: []}
      formatted = NPM.Lockfile.Check.format_results(result)
      assert formatted =~ "Missing: a, b"
    end
  end

  describe "PackageFiles edge cases" do
    test "string exports in entry_points" do
      data = %{"exports" => "./dist/index.js"}
      entries = NPM.Package.Files.entry_points(data)
      assert "./dist/index.js" in entries
    end

    test "COPYING always included" do
      assert NPM.Package.Files.always_included?("COPYING")
    end
  end
end
