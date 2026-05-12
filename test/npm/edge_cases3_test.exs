defmodule NPM.EdgeCases3Test do
  use ExUnit.Case, async: true

  describe "Bin edge cases" do
    test "string bin without name falls back to empty" do
      assert %{} = NPM.Node.Bin.extract(%{"bin" => "./index.js"})
    end

    test "count for string bin" do
      assert 1 = NPM.Node.Bin.count(%{"name" => "pkg", "bin" => "./cli.js"})
    end
  end

  describe "People edge cases" do
    test "contributors with mixed formats" do
      data = %{
        "contributors" => [
          "Alice <alice@test.com>",
          %{"name" => "Bob", "email" => "bob@test.com"}
        ]
      }

      result = NPM.Package.People.contributors(data)
      assert length(result) == 2
      assert hd(result)["name"] == "Alice"
    end

    test "all with only contributors" do
      data = %{"contributors" => [%{"name" => "Solo"}]}
      assert length(NPM.Package.People.all(data)) == 1
    end
  end

  describe "Repository edge cases" do
    test "ssh protocol cleaned" do
      data = %{"repository" => %{"type" => "git", "url" => "ssh://git@github.com/user/repo.git"}}
      repo = NPM.Package.Repository.extract(data)
      assert repo.url == "https://github.com/user/repo"
    end

    test "clone_url adds .git" do
      data = %{"repository" => "user/repo"}
      url = NPM.Package.Repository.clone_url(data)
      assert String.ends_with?(url, ".git")
    end
  end

  describe "Keywords edge cases" do
    test "most_common limits results" do
      packages = [
        %{"keywords" => ["a", "b", "c"]},
        %{"keywords" => ["a", "b"]},
        %{"keywords" => ["a"]}
      ]

      result = NPM.Package.Keywords.most_common(packages, 1)
      assert length(result) == 1
      assert elem(hd(result), 0) == "a"
    end

    test "group_by_keyword empty" do
      assert %{} = NPM.Package.Keywords.group_by_keyword([])
    end
  end

  describe "Scope edge cases" do
    test "full_name constructs correctly" do
      assert "@types/node" = NPM.Scope.full_name("types", "node")
    end

    test "valid_scope with numbers" do
      assert NPM.Scope.valid_scope?("my2org")
    end

    test "extract from unscoped returns nil" do
      assert nil == NPM.Scope.extract("react")
    end
  end

  describe "Report edge cases" do
    test "version_summary with string version map" do
      lockfile = %{"pkg" => %{"version" => "2.0.0"}}
      summary = NPM.Report.version_summary(lockfile)
      assert summary.total == 1
    end

    test "dependency_summary scoped percentage" do
      lockfile = %{
        "@a/b" => %{version: "1.0"},
        "@c/d" => %{version: "1.0"}
      }

      summary = NPM.Report.dependency_summary(lockfile)
      assert summary.scoped_pct == 100.0
    end
  end

  describe "Normalize more edge cases" do
    test "parse_person name only" do
      result = NPM.Normalize.parse_person("SingleName")
      assert result["name"] == "SingleName"
      refute Map.has_key?(result, "email")
      refute Map.has_key?(result, "url")
    end

    test "normalize_bugs keeps map" do
      data = %{"bugs" => %{"url" => "https://x.com", "email" => "bug@x.com"}}
      assert data == NPM.Normalize.normalize_bugs(data)
    end
  end

  describe "Changelog more edge cases" do
    test "versions from h1 headers" do
      content = "# 1.0.0\n\nStuff"
      versions = NPM.Changelog.versions(content)
      assert "1.0.0" in versions
    end

    test "empty string content" do
      assert [] = NPM.Changelog.versions("")
    end
  end

  describe "Provenance more edge cases" do
    test "scan all with provenance" do
      lockfile = %{
        "a" => %{version: "1.0", provenance: true},
        "b" => %{version: "2.0", attestations: []}
      }

      result = NPM.Security.Provenance.scan(lockfile)
      assert length(result.with_provenance) == 2
      assert result.without == []
    end
  end

  describe "VersionRange more edge cases" do
    test "max_satisfying with empty list" do
      assert nil == NPM.VersionRange.max_satisfying([], "^1.0.0")
    end

    test "min_satisfying with single version" do
      assert "2.0.0" = NPM.VersionRange.min_satisfying(["2.0.0"], "^2.0.0")
    end

    test "describe or_range" do
      assert "one of ^1 || ^2" = NPM.VersionRange.describe("^1 || ^2")
    end

    test "major from tilde range" do
      assert 3 = NPM.VersionRange.major("~3.5.0")
    end
  end

  describe "SBOM more edge cases" do
    test "filter preserves metadata" do
      sbom = %{
        bom_format: "CycloneDX",
        spec_version: "1.4",
        version: 1,
        components: [%{name: "a"}, %{name: "b"}]
      }

      filtered = NPM.SBOM.filter(sbom, &(&1.name == "a"))
      assert filtered.bom_format == "CycloneDX"
      assert length(filtered.components) == 1
    end
  end

  describe "TypesResolution more edge cases" do
    test "types_package for simple name" do
      assert "@types/react" = NPM.TypesResolution.types_package("react")
    end

    test "installed_types empty lockfile" do
      assert [] = NPM.TypesResolution.installed_types(%{})
    end
  end
end
