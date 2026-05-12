defmodule NPM.SBOMTest do
  use ExUnit.Case, async: true

  @lockfile %{
    "lodash" => %{version: "4.17.21", integrity: "sha512-abc123", tarball: "", dependencies: %{}},
    "react" => %{version: "18.2.0", integrity: "sha512-def456", tarball: "", dependencies: %{}}
  }

  describe "from_lockfile" do
    test "generates valid SBOM structure" do
      sbom = NPM.SBOM.from_lockfile(@lockfile)
      assert sbom.bom_format == "CycloneDX"
      assert sbom.spec_version == "1.4"
      assert length(sbom.components) == 2
    end

    test "components have required fields" do
      sbom = NPM.SBOM.from_lockfile(@lockfile)
      lodash = Enum.find(sbom.components, &(&1.name == "lodash"))
      assert lodash.type == "library"
      assert lodash.version == "4.17.21"
      assert lodash.purl == "pkg:npm/lodash@4.17.21"
    end

    test "includes integrity hashes" do
      sbom = NPM.SBOM.from_lockfile(@lockfile)
      lodash = Enum.find(sbom.components, &(&1.name == "lodash"))
      assert length(lodash.hashes) == 1
      assert hd(lodash.hashes).alg == "SHA-512"
    end

    test "empty lockfile" do
      sbom = NPM.SBOM.from_lockfile(%{})
      assert sbom.components == []
    end
  end

  describe "generate" do
    @tag :tmp_dir
    test "includes license from package.json", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      pkg = Path.join(nm, "lodash")
      File.mkdir_p!(pkg)
      File.write!(Path.join(pkg, "package.json"), ~s({"name":"lodash","license":"MIT"}))

      lockfile = %{
        "lodash" => %{version: "4.17.21", integrity: "", tarball: "", dependencies: %{}}
      }

      sbom = NPM.SBOM.generate(lockfile, nm)
      lodash = Enum.find(sbom.components, &(&1.name == "lodash"))
      assert lodash.license == "MIT"
    end

    test "includes metadata" do
      sbom = NPM.SBOM.generate(@lockfile)
      assert [_ | _] = sbom.metadata.tools
    end
  end

  describe "component_count" do
    test "counts components" do
      sbom = NPM.SBOM.from_lockfile(@lockfile)
      assert 2 = NPM.SBOM.component_count(sbom)
    end

    test "zero for empty" do
      assert 0 = NPM.SBOM.component_count(%{})
    end
  end

  describe "purl" do
    test "generates valid purl" do
      assert "pkg:npm/lodash@4.17.21" = NPM.SBOM.purl("lodash", "4.17.21")
    end

    test "encodes scoped package" do
      purl = NPM.SBOM.purl("@babel/core", "7.23.0")
      assert purl == "pkg:npm/@babel/core@7.23.0"
    end
  end

  describe "filter" do
    test "filters components" do
      sbom = NPM.SBOM.from_lockfile(@lockfile)
      filtered = NPM.SBOM.filter(sbom, &(&1.name == "lodash"))
      assert length(filtered.components) == 1
      assert hd(filtered.components).name == "lodash"
    end
  end
end
