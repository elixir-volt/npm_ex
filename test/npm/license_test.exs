defmodule NPM.LicenseTest do
  use ExUnit.Case, async: true

  describe "extract license" do
    test "string license field" do
      assert "MIT" == NPM.License.extract(%{"license" => "MIT"})
    end

    test "object license field" do
      assert "Apache-2.0" == NPM.License.extract(%{"license" => %{"type" => "Apache-2.0"}})
    end

    test "legacy licenses array" do
      assert "ISC" == NPM.License.extract(%{"licenses" => [%{"type" => "ISC", "url" => "..."}]})
    end

    test "missing license" do
      assert nil == NPM.License.extract(%{"name" => "pkg"})
    end

    test "empty map" do
      assert nil == NPM.License.extract(%{})
    end
  end

  describe "permissive?" do
    test "MIT is permissive" do
      assert NPM.License.permissive?("MIT")
    end

    test "ISC is permissive" do
      assert NPM.License.permissive?("ISC")
    end

    test "BSD-3-Clause is permissive" do
      assert NPM.License.permissive?("BSD-3-Clause")
    end

    test "Apache-2.0 is permissive" do
      assert NPM.License.permissive?("Apache-2.0")
    end

    test "GPL-3.0 is not permissive" do
      refute NPM.License.permissive?("GPL-3.0")
    end

    test "nil is not permissive" do
      refute NPM.License.permissive?(nil)
    end

    test "LGPL-2.1 is not permissive" do
      refute NPM.License.permissive?("LGPL-2.1")
    end
  end

  describe "non_permissive" do
    test "filters out permissive licenses" do
      entries = [
        %{package: "a", version: "1.0.0", license: "MIT"},
        %{package: "b", version: "1.0.0", license: "GPL-3.0"},
        %{package: "c", version: "1.0.0", license: nil},
        %{package: "d", version: "1.0.0", license: "ISC"}
      ]

      result = NPM.License.non_permissive(entries)
      names = Enum.map(result, & &1.package)
      assert "b" in names
      assert "c" in names
      refute "a" in names
      refute "d" in names
    end
  end

  describe "group_by_license" do
    test "groups entries" do
      entries = [
        %{package: "a", version: "1.0.0", license: "MIT"},
        %{package: "b", version: "1.0.0", license: "MIT"},
        %{package: "c", version: "1.0.0", license: "ISC"},
        %{package: "d", version: "1.0.0", license: nil}
      ]

      grouped = NPM.License.group_by_license(entries)
      assert length(grouped["MIT"]) == 2
      assert length(grouped["ISC"]) == 1
      assert length(grouped["UNKNOWN"]) == 1
    end
  end

  describe "summary" do
    test "produces compliance summary" do
      entries = [
        %{package: "a", version: "1.0.0", license: "MIT"},
        %{package: "b", version: "1.0.0", license: "ISC"},
        %{package: "c", version: "1.0.0", license: "GPL-3.0"},
        %{package: "d", version: "1.0.0", license: nil}
      ]

      s = NPM.License.summary(entries)
      assert s.total == 4
      assert s.permissive == 2
      assert s.non_permissive == 1
      assert s.unknown == 1
      assert "MIT" in s.unique_licenses
      assert "GPL-3.0" in s.unique_licenses
    end

    test "empty entries" do
      s = NPM.License.summary([])
      assert s.total == 0
    end
  end

  describe "check_policy" do
    test "returns violations" do
      entries = [
        %{package: "a", version: "1.0.0", license: "MIT"},
        %{package: "b", version: "1.0.0", license: "GPL-3.0"},
        %{package: "c", version: "1.0.0", license: "ISC"},
        %{package: "d", version: "1.0.0", license: nil}
      ]

      violations = NPM.License.check_policy(entries, ["MIT", "ISC"])
      names = Enum.map(violations, & &1.package)
      assert "b" in names
      assert "d" in names
      refute "a" in names
    end

    test "no violations with broad policy" do
      entries = [
        %{package: "a", version: "1.0.0", license: "MIT"}
      ]

      assert [] = NPM.License.check_policy(entries, ["MIT"])
    end
  end

  describe "scan node_modules" do
    @tag :tmp_dir
    test "reads licenses from packages", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      File.mkdir_p!(Path.join(nm, "my-pkg"))

      File.write!(
        Path.join([nm, "my-pkg", "package.json"]),
        ~s({"name":"my-pkg","version":"2.0.0","license":"MIT"})
      )

      entries = NPM.License.scan(nm)
      assert length(entries) == 1
      assert hd(entries).license == "MIT"
    end

    @tag :tmp_dir
    test "handles packages without license", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      File.mkdir_p!(Path.join(nm, "no-lic"))

      File.write!(
        Path.join([nm, "no-lic", "package.json"]),
        ~s({"name":"no-lic","version":"1.0.0"})
      )

      [entry] = NPM.License.scan(nm)
      assert entry.license == nil
    end

    test "returns empty for nonexistent directory" do
      assert [] = NPM.License.scan("/tmp/nonexistent_#{System.unique_integer([:positive])}")
    end
  end

  describe "extract number license" do
    test "license as number is nil" do
      assert nil == NPM.License.extract(%{"license" => 42})
    end
  end

  describe "check_policy with empty policy" do
    test "everything violates empty allowed list" do
      entries = [%{package: "a", version: "1.0.0", license: "MIT"}]
      violations = NPM.License.check_policy(entries, [])
      assert length(violations) == 1
    end
  end

  describe "more permissive licenses" do
    test "0BSD is permissive" do
      assert NPM.License.permissive?("0BSD")
    end

    test "CC0-1.0 is permissive" do
      assert NPM.License.permissive?("CC0-1.0")
    end

    test "Unlicense is permissive" do
      assert NPM.License.permissive?("Unlicense")
    end

    test "AGPL-3.0 is not permissive" do
      refute NPM.License.permissive?("AGPL-3.0")
    end
  end
end
