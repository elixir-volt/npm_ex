defmodule NPM.EdgeCases7Test do
  use ExUnit.Case, async: true

  alias NPM.Dependency.Conflict
  alias NPM.Dependency.Outdated
  alias NPM.Install.ScriptRunner
  alias NPM.Package.Manifest.Diff

  describe "ManifestDiff edge cases" do
    test "diff with nil scripts" do
      old = %{"dependencies" => %{"a" => "^1.0"}}
      new = %{"dependencies" => %{"a" => "^1.0"}}
      d = Diff.diff(old, new)
      assert d.scripts.added == []
    end

    test "diff detects name change" do
      old = %{"name" => "old-name"}
      new = %{"name" => "new-name"}
      d = Diff.diff(old, new)
      assert d.name_changed
    end

    test "diff top-level field changes" do
      old = %{"description" => "old"}
      new = %{"description" => "new", "license" => "MIT"}
      d = Diff.diff(old, new)
      assert "license" in d.fields.added
    end
  end

  describe "ScriptRunner edge cases" do
    test "eslint detection without lint script" do
      data = %{"scripts" => %{"check" => "eslint src/"}}
      patterns = ScriptRunner.detect_patterns(data)
      assert :has_lint in patterns
    end

    test "empty patterns for no scripts" do
      assert [] = ScriptRunner.detect_patterns(%{})
    end
  end

  describe "DepConflict edge cases" do
    test "peerDependencies conflict with dependencies" do
      data = %{
        "dependencies" => %{"react" => "^17.0"},
        "peerDependencies" => %{"react" => "^18.0"}
      }

      conflicts = Conflict.find(data)
      assert length(conflicts) == 1
    end

    test "empty package data" do
      assert [] = Conflict.find(%{})
      refute Conflict.conflicts?(%{})
    end
  end

  describe "PackageUpdate edge cases" do
    test "handles pre-release versions" do
      assert :current = Outdated.update_type("invalid", "also-invalid")
    end

    test "major jump from 0.x to 1.x" do
      assert :major = Outdated.update_type("0.9.0", "1.0.0")
    end
  end

  describe "ReleaseNotes edge cases" do
    test "handles bracket versions" do
      content = "## [2.0.0]\n\n- Changes\n\n## [1.0.0]\n\n- Initial"
      sects = NPM.ReleaseNotes.sections(content)
      assert length(sects) == 2
    end

    test "handles v-prefixed versions" do
      content = "## v1.5.0\n\n- Something"
      assert "1.5.0" = NPM.ReleaseNotes.latest_version(content)
    end
  end

  describe "IntegrityCheck + DepsOutput" do
    test "format results for multiple failures" do
      failures = [
        %{name: "a", reason: :not_installed},
        %{name: "b", reason: :version_mismatch},
        %{name: "c", reason: :not_installed}
      ]

      formatted = NPM.IntegrityCheck.format_results(failures)
      assert formatted =~ "not_installed"
      assert formatted =~ "version_mismatch"
    end
  end

  describe "Gitignore edge cases" do
    test "empty content" do
      missing = NPM.Gitignore.missing("")
      assert "node_modules/" in missing
    end

    test "covers with extra whitespace" do
      assert NPM.Gitignore.covers_node_modules?("  node_modules  \n")
    end
  end

  describe "DepsOutput edge cases" do
    test "single package lockfile" do
      lockfile = %{"only-pkg" => %{version: "1.0.0", integrity: ""}}
      output = NPM.DepsOutput.format_lockfile(lockfile)
      assert output =~ "* only-pkg 1.0.0"
    end

    test "diff both added and removed" do
      old = %{"removed" => %{version: "1.0.0"}}
      new = %{"added" => %{version: "2.0.0"}}
      diff = NPM.DepsOutput.format_diff(old, new)
      assert diff =~ "+ added"
      assert diff =~ "- removed"
    end
  end
end
