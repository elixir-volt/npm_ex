defmodule NPM.EdgeCasesTest do
  use ExUnit.Case, async: true

  alias NPM.Diagnostics.EngineCheck
  alias NPM.Diagnostics.Health
  alias NPM.Security.Provenance

  describe "VersionRange edge cases" do
    test "compatible caret within same major" do
      assert NPM.VersionRange.compatible?("^1.0.0", ">=1.5.0")
    end

    test "incompatible across major versions" do
      refute NPM.VersionRange.compatible?("^1.0.0", ">=3.0.0")
    end

    test "describe hyphen range" do
      assert "between 1.0.0 - 2.0.0" = NPM.VersionRange.describe("1.0.0 - 2.0.0")
    end

    test "classify empty string as any" do
      assert :any = NPM.VersionRange.classify("")
    end
  end

  describe "Normalize edge cases" do
    test "normalize with all fields present" do
      data = %{
        "main" => "./dist.js",
        "repository" => %{"type" => "git", "url" => "https://github.com/x/y"},
        "bugs" => %{"url" => "https://x.com/bugs"},
        "homepage" => "https://x.com",
        "author" => %{"name" => "Alice"}
      }

      result = NPM.Normalize.normalize(data)
      assert result["main"] == "./dist.js"
      assert result["author"]["name"] == "Alice"
    end

    test "normalize empty map" do
      result = NPM.Normalize.normalize(%{})
      assert result["main"] == "index.js"
    end
  end

  describe "Changelog edge cases" do
    test "versions with v prefix" do
      content = "## v3.0.0\n\nstuff\n\n## v2.0.0\n\nthings"
      versions = NPM.Changelog.versions(content)
      assert "3.0.0" in versions
      assert "2.0.0" in versions
    end

    test "version_entry with prerelease" do
      content = "## 2.0.0-beta.1\n\n- Beta stuff\n\n## 1.0.0\n\n- Initial"
      entry = NPM.Changelog.version_entry(content, "2.0.0-beta.1")
      assert entry =~ "Beta stuff"
    end
  end

  describe "GitInfo edge cases" do
    test "git:// protocol" do
      data = %{"repository" => %{"url" => "git://github.com/user/repo.git"}}
      assert "https://github.com/user/repo" = NPM.GitInfo.repo_url(data)
    end

    test "bugs as string URL" do
      data = %{"bugs" => "https://example.com/bugs"}
      assert "https://example.com/bugs" = NPM.GitInfo.issues_url(data)
    end
  end

  describe "SBOM edge cases" do
    test "sha256 integrity" do
      lockfile = %{"pkg" => %{version: "1.0.0", integrity: "sha256-xyz123"}}
      sbom = NPM.SBOM.from_lockfile(lockfile)
      hashes = hd(sbom.components).hashes
      assert hd(hashes).alg == "SHA-256"
    end

    test "no integrity produces empty hashes" do
      lockfile = %{"pkg" => %{version: "1.0.0"}}
      sbom = NPM.SBOM.from_lockfile(lockfile)
      assert hd(sbom.components).hashes == []
    end
  end

  describe "Import edge cases" do
    @tag :tmp_dir
    test "detects bun lockfile", %{tmp_dir: dir} do
      File.write!(Path.join(dir, "bun.lockb"), <<0>>)
      assert :bun in NPM.Import.detect(dir)
    end
  end

  describe "Ignore edge cases" do
    test "root directory matching" do
      assert NPM.Ignore.ignored?("tests/helper.js", ["tests/"])
    end

    test "respects never-ignored for LICENSE" do
      refute NPM.Ignore.ignored?("LICENSE", ["*"])
    end
  end

  describe "Completion edge cases" do
    test "case insensitive matching" do
      results = NPM.Completion.complete("IN")
      assert "install" in results
      assert "init" in results
    end

    test "complete_scripts empty prefix" do
      scripts = %{"test" => "jest", "build" => "tsc"}
      results = NPM.Completion.complete_scripts("", scripts)
      assert length(results) == 2
    end
  end

  describe "EngineCheck edge cases" do
    test "multiple engines in one package" do
      data = %{
        "name" => "pkg",
        "engines" => %{"node" => ">=14", "npm" => ">=7"}
      }

      issues = EngineCheck.check_package(data, "20.0.0")
      assert length(issues) == 2
    end
  end

  describe "BundleDeps edge cases" do
    test "true with no deps but bundledDependencies: true" do
      data = %{"bundledDependencies" => true}
      assert [] = NPM.BundleDeps.extract(data)
    end
  end

  describe "DevDeps edge cases" do
    test "overlapping returns sorted list" do
      data = %{
        "dependencies" => %{"a" => "1", "b" => "1"},
        "devDependencies" => %{"b" => "2", "a" => "2"}
      }

      overlaps = NPM.DevDeps.overlapping(data)
      assert overlaps == ["a", "b"]
    end
  end

  describe "Provenance edge cases" do
    test "has_provenance with string key attestations" do
      assert Provenance.has_provenance?(%{"attestations" => []})
    end

    test "has_integrity with string key" do
      assert Provenance.has_integrity?(%{"integrity" => "sha512-abc"})
    end
  end

  describe "Health edge cases" do
    test "grade boundary at 90" do
      assert "A" = Health.grade(90)
    end

    test "grade boundary at 80" do
      assert "B" = Health.grade(80)
    end

    test "grade boundary at 0" do
      assert "F" = Health.grade(0)
    end
  end
end
