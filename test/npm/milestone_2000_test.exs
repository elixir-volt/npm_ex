defmodule NPM.Milestone2000Test do
  use ExUnit.Case, async: true

  describe "Lockfile round-trip" do
    @tag :tmp_dir
    test "write then read preserves data", %{tmp_dir: dir} do
      path = Path.join(dir, "npm.lock")

      original = %{
        "lodash" => %{
          version: "4.17.21",
          integrity: "sha512-abc",
          tarball: "https://example.com/lodash.tgz",
          dependencies: %{"dep" => "^1.0"}
        }
      }

      NPM.Lockfile.write(original, path)
      {:ok, read_back} = NPM.Lockfile.read(path)
      assert read_back["lodash"].version == "4.17.21"
      assert read_back["lodash"].integrity == "sha512-abc"
    end

    @tag :tmp_dir
    test "write then read with multiple packages", %{tmp_dir: dir} do
      path = Path.join(dir, "npm.lock")

      original = %{
        "a" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}},
        "b" => %{version: "2.0.0", integrity: "", tarball: "", dependencies: %{"a" => "^1.0"}}
      }

      NPM.Lockfile.write(original, path)
      {:ok, read_back} = NPM.Lockfile.read(path)
      assert map_size(read_back) == 2
      assert read_back["b"].dependencies == %{"a" => "^1.0"}
    end
  end

  describe "Config round-trip" do
    test "parse and get" do
      content = "registry=https://custom.example.com\nsave-exact=true"
      config = NPM.Config.parse_npmrc(content)
      assert "true" = NPM.Config.get(config, "save-exact")
      assert "https://custom.example.com" = NPM.Config.get(config, "registry")
    end
  end

  describe "CI + Lockfile integration" do
    @tag :tmp_dir
    test "validate catches all missing deps", %{tmp_dir: dir} do
      File.write!(
        Path.join(dir, "package.json"),
        ~s({"dependencies":{"a":"^1","b":"^2","c":"^3"}})
      )

      NPM.Lockfile.write(%{}, Path.join(dir, "npm.lock"))

      {:error, errors} = NPM.CI.validate(dir)
      missing = Enum.filter(errors, &match?({:missing_dep, _}, &1))
      assert length(missing) == 3
    end
  end

  describe "Scope + Bin integration" do
    test "scoped package bin extraction" do
      data = %{"name" => "@myorg/cli", "bin" => %{"mycli" => "./dist/cli.js"}}
      assert NPM.Scope.scoped?(data["name"])
      assert NPM.Bin.has_bin?(data)
      assert ["mycli"] = NPM.Bin.commands(data)
    end
  end

  describe "Health + Provenance integration" do
    test "risk summary feeds health checks" do
      lockfile = %{
        "a" => %{version: "1.0", integrity: "sha512-x"},
        "b" => %{version: "2.0", integrity: "sha512-y"}
      }

      risk = NPM.Security.Provenance.risk_summary(lockfile)
      health_checks = %{integrity_pct: risk.integrity_pct, vulnerability_count: 0}
      result = NPM.Diagnostics.Health.score(health_checks)
      assert result.details[:integrity_coverage] == 15
    end
  end

  describe "Normalize + People integration" do
    test "normalized author can be extracted by People" do
      data = %{"author" => "John Doe <john@example.com> (https://john.dev)"}
      normalized = NPM.Normalize.normalize(data)
      author = NPM.Package.People.author(normalized)
      assert author["name"] == "John Doe"
      assert author["email"] == "john@example.com"
    end
  end

  describe "VersionRange + Resolutions integration" do
    test "resolution version satisfies original range" do
      range = "^1.0.0"
      resolution_version = "1.5.0"
      assert NPMSemver.matches?(resolution_version, range)
      assert NPM.VersionRange.exact?(resolution_version)
    end
  end

  describe "Exports + Manifest integration" do
    test "parse exports from manifest data" do
      data = %{
        "name" => "my-lib",
        "exports" => %{"." => "./dist/index.js", "./utils" => "./dist/utils.js"}
      }

      exports = NPM.Resolution.Exports.parse(data)
      assert NPM.Resolution.Exports.exported?("./utils", exports)
      paths = NPM.Resolution.Exports.subpaths(exports)
      assert length(paths) == 2
    end
  end

  describe "GitInfo + Repository consistency" do
    test "both extract same URL" do
      data = %{
        "repository" => %{"type" => "git", "url" => "git+https://github.com/user/repo.git"}
      }

      git_url = NPM.GitInfo.repo_url(data)
      repo_info = NPM.Package.Repository.extract(data)
      assert git_url == repo_info.url
    end
  end

  describe "SBOM + Scope analysis" do
    test "SBOM purl includes scope" do
      purl = NPM.SBOM.purl("@babel/core", "7.23.0")
      assert purl =~ "@babel/core"
      assert NPM.Scope.scoped?("@babel/core")
    end
  end

  describe "Report + Scope integration" do
    test "dependency summary reflects scoped packages" do
      lockfile = %{
        "@types/node" => %{version: "18.15.0"},
        "typescript" => %{version: "5.3.0"}
      }

      summary = NPM.Report.dependency_summary(lockfile)
      assert summary.scoped == 1
      assert summary.unscoped == 1
    end
  end

  describe "Dist + Provenance" do
    test "dist integrity feeds provenance check" do
      dist =
        NPM.Dist.extract(%{
          "dist" => %{"tarball" => "https://x.com/pkg.tgz", "integrity" => "sha512-abc"}
        })

      assert NPM.Dist.has_integrity?(dist)
      assert NPM.Security.Provenance.has_integrity?(dist)
    end
  end

  describe "Monorepo + Workspace" do
    @tag :tmp_dir
    test "monorepo with workspaces", %{tmp_dir: dir} do
      File.write!(Path.join(dir, "package.json"), ~s({"workspaces":["packages/*"]}))
      assert NPM.Monorepo.monorepo?(dir)
      assert :npm_workspaces in NPM.Monorepo.detect(dir)
    end
  end

  describe "Os + EngineCheck" do
    test "current os is valid string" do
      os = NPM.Os.current_os()
      assert is_binary(os)
      assert byte_size(os) > 0
    end
  end
end
