defmodule NPM.Diagnostics.EngineCheckTest do
  use ExUnit.Case, async: true

  describe "check_package" do
    test "checks node engine requirement" do
      data = %{"name" => "my-pkg", "engines" => %{"node" => ">=14.0.0"}}
      issues = NPM.Diagnostics.EngineCheck.check_package(data, "20.0.0")
      assert length(issues) == 1
      assert hd(issues).satisfied
    end

    test "detects unsatisfied node requirement" do
      data = %{"name" => "strict-pkg", "engines" => %{"node" => ">=20.0.0"}}
      issues = NPM.Diagnostics.EngineCheck.check_package(data, "18.0.0")
      assert length(issues) == 1
      refute hd(issues).satisfied
    end

    test "no engines means no issues" do
      data = %{"name" => "no-engines"}
      assert [] = NPM.Diagnostics.EngineCheck.check_package(data, "20.0.0")
    end

    test "nil node version is satisfied" do
      data = %{"name" => "pkg", "engines" => %{"node" => ">=14"}}
      issues = NPM.Diagnostics.EngineCheck.check_package(data, nil)
      assert hd(issues).satisfied
    end

    test "non-node engines are marked satisfied" do
      data = %{"name" => "pkg", "engines" => %{"npm" => ">=8"}}
      issues = NPM.Diagnostics.EngineCheck.check_package(data, "20.0.0")
      assert hd(issues).satisfied
      assert hd(issues).actual == nil
    end
  end

  describe "unsatisfied" do
    test "filters to only unsatisfied" do
      issues = [
        %{package: "a", engine: "node", required: ">=14", actual: "20.0.0", satisfied: true},
        %{package: "b", engine: "node", required: ">=22", actual: "20.0.0", satisfied: false}
      ]

      result = NPM.Diagnostics.EngineCheck.unsatisfied(issues)
      assert length(result) == 1
      assert hd(result).package == "b"
    end

    test "empty when all satisfied" do
      issues = [
        %{package: "a", engine: "node", required: ">=14", actual: "20.0.0", satisfied: true}
      ]

      assert [] = NPM.Diagnostics.EngineCheck.unsatisfied(issues)
    end
  end

  describe "format_issues" do
    test "formats issues with status" do
      issues = [
        %{package: "a", engine: "node", required: ">=14", actual: "20.0.0", satisfied: true},
        %{package: "b", engine: "node", required: ">=22", actual: "18.0.0", satisfied: false}
      ]

      formatted = NPM.Diagnostics.EngineCheck.format_issues(issues)
      assert formatted =~ "✓"
      assert formatted =~ "✗"
    end

    test "formats nil actual" do
      issues = [
        %{package: "a", engine: "npm", required: ">=8", actual: nil, satisfied: true}
      ]

      formatted = NPM.Diagnostics.EngineCheck.format_issues(issues)
      assert formatted =~ "not installed"
    end

    test "empty list message" do
      assert "All engine requirements satisfied." = NPM.Diagnostics.EngineCheck.format_issues([])
    end
  end

  describe "check_all" do
    @tag :tmp_dir
    test "scans node_modules for engines", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      pkg = Path.join(nm, "engine-pkg")
      File.mkdir_p!(pkg)

      File.write!(
        Path.join(pkg, "package.json"),
        ~s({"name":"engine-pkg","engines":{"node":">=14"}})
      )

      issues = NPM.Diagnostics.EngineCheck.check_all(nm)
      assert Enum.any?(issues, &(&1.package == "engine-pkg"))
    end

    @tag :tmp_dir
    test "skips packages without engines", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      pkg = Path.join(nm, "no-engine")
      File.mkdir_p!(pkg)
      File.write!(Path.join(pkg, "package.json"), ~s({"name":"no-engine"}))

      assert [] = NPM.Diagnostics.EngineCheck.check_all(nm)
    end

    test "empty for nonexistent directory" do
      assert [] =
               NPM.Diagnostics.EngineCheck.check_all(
                 "/tmp/nonexistent_#{System.unique_integer([:positive])}"
               )
    end
  end
end
