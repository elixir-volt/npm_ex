defmodule NPM.EdgeCases2Test do
  use ExUnit.Case, async: true

  describe "Scope edge cases" do
    test "extract from double-scoped-looking name" do
      assert "types" = NPM.Scope.extract("@types/babel__core")
    end

    test "valid_name with hyphen" do
      assert NPM.Scope.valid_name?("my-package")
    end

    test "invalid name with space" do
      refute NPM.Scope.valid_name?("my package")
    end

    test "group_by_scope with all unscoped" do
      groups = NPM.Scope.group_by_scope(["a", "b", "c"])
      assert length(groups[nil]) == 3
    end
  end

  describe "Dist edge cases" do
    test "extract with npm-signature" do
      entry = %{
        "dist" => %{
          "tarball" => "https://example.com/pkg.tgz",
          "npm-signature" => "sig123"
        }
      }

      dist = NPM.Dist.extract(entry)
      assert dist.npm_signature == "sig123"
    end

    test "default_tarball_url trims trailing slash" do
      url = NPM.Dist.default_tarball_url("https://registry.npmjs.org/", "pkg", "1.0.0")
      refute String.contains?(url, "//pkg")
    end
  end

  describe "Os edge cases" do
    test "compatible with empty os list handled by Platform" do
      assert NPM.Os.os_compatible?(%{})
    end

    test "compatible with no cpu field" do
      assert NPM.Os.cpu_compatible?(%{"name" => "pkg"})
    end
  end

  describe "Monorepo edge cases" do
    @tag :tmp_dir
    test "detects rush", %{tmp_dir: dir} do
      File.write!(Path.join(dir, "rush.json"), "{}")
      assert :rush in NPM.Monorepo.detect(dir)
    end

    @tag :tmp_dir
    test "detects pnpm workspaces", %{tmp_dir: dir} do
      File.write!(Path.join(dir, "pnpm-workspace.yaml"), "packages:\n  - packages/*")
      assert :pnpm_workspaces in NPM.Monorepo.detect(dir)
    end
  end

  describe "PackageLock edge cases" do
    test "version 2 detected" do
      assert 2 = NPM.PackageLock.version(%{"lockfileVersion" => 2})
    end

    test "invalid version number" do
      assert nil == NPM.PackageLock.version(%{"lockfileVersion" => 99})
    end

    test "requires_npm7 for v2" do
      assert NPM.PackageLock.requires_npm7?(%{"lockfileVersion" => 2})
    end
  end

  describe "Cve edge cases" do
    test "extract multiple CVEs from references" do
      refs = "CVE-2021-23337 and CVE-2020-28500 are related"
      cves = NPM.Cve.extract_cves(%{"references" => refs})
      assert length(cves) == 2
    end

    test "severity_counts with all same severity" do
      advs = [%{"severity" => "high"}, %{"severity" => "high"}]
      counts = NPM.Cve.severity_counts(advs)
      assert counts["high"] == 2
    end

    test "above_threshold with empty list" do
      refute NPM.Cve.above_threshold?([], "high")
    end
  end

  describe "Health edge cases" do
    test "integrity 50% gives 5 points" do
      checks = %{integrity_pct: 50}
      result = NPM.Health.score(checks)
      assert result.details[:integrity_coverage] == 5
    end

    test "integrity below 50% gives 0" do
      checks = %{integrity_pct: 20}
      result = NPM.Health.score(checks)
      assert result.details[:integrity_coverage] == 0
    end

    test "few outdated gives partial points" do
      checks = %{outdated_count: 3}
      result = NPM.Health.score(checks)
      assert result.details[:up_to_date] == 5
    end

    test "many outdated gives 0 points" do
      checks = %{outdated_count: 10}
      result = NPM.Health.score(checks)
      assert result.details[:up_to_date] == 0
    end
  end

  describe "Patch edge cases" do
    test "filename preserves scope with +" do
      assert "@types+node+18.0.0.patch" = NPM.Patch.filename("@types/node", "18.0.0")
    end

    test "extract_package_name handles no version suffix" do
      assert "lodash" = NPM.Patch.extract_package_name("lodash.patch")
    end
  end

  describe "FileSize edge cases" do
    test "format_size zero bytes" do
      assert "0 B" = NPM.FileSize.format_size(0)
    end

    test "format_size exactly 1 KB" do
      assert "1.0 KB" = NPM.FileSize.format_size(1024)
    end

    test "format_size exactly 1 MB" do
      assert "1.0 MB" = NPM.FileSize.format_size(1_048_576)
    end
  end

  describe "Resolutions edge cases" do
    test "parse empty map" do
      assert [] = NPM.Resolutions.parse(%{"resolutions" => %{}})
    end

    test "resolve first match wins" do
      resolutions = [
        %{pattern: "lodash", version: "4.17.20"},
        %{pattern: "lodash", version: "4.17.21"}
      ]

      assert "4.17.20" = NPM.Resolutions.resolve("lodash", resolutions)
    end
  end

  describe "Import edge cases" do
    @tag :tmp_dir
    test "from_package_lock handles empty packages", %{tmp_dir: dir} do
      path = Path.join(dir, "package-lock.json")
      File.write!(path, ~s({"lockfileVersion":3,"packages":{}}))
      assert {:ok, %{}} = NPM.Import.from_package_lock(path)
    end
  end

  describe "CI edge cases" do
    test "format_errors with multiple missing deps" do
      errors = [{:missing_dep, "a"}, {:missing_dep, "b"}]
      formatted = NPM.CI.format_errors(errors)
      assert formatted =~ "a"
      assert formatted =~ "b"
    end
  end
end
