defmodule NPM.Lockfile.CheckTest do
  use ExUnit.Case, async: true

  @pkg %{
    "dependencies" => %{"lodash" => "^4.17.0", "express" => "^4.18.0"},
    "devDependencies" => %{"jest" => "^29.0.0"}
  }

  @lockfile %{
    "lodash" => %{version: "4.17.21", integrity: "", tarball: "", dependencies: %{}},
    "express" => %{version: "4.18.2", integrity: "", tarball: "", dependencies: %{}},
    "jest" => %{version: "29.7.0", integrity: "", tarball: "", dependencies: %{}}
  }

  describe "missing" do
    test "no missing when all present" do
      assert [] = NPM.Lockfile.Check.missing(@pkg, @lockfile)
    end

    test "detects missing packages" do
      lockfile = Map.delete(@lockfile, "jest")
      assert ["jest"] = NPM.Lockfile.Check.missing(@pkg, lockfile)
    end

    test "multiple missing" do
      result = NPM.Lockfile.Check.missing(@pkg, %{})
      assert length(result) == 3
    end
  end

  describe "extraneous" do
    test "no extraneous when exact match" do
      assert [] = NPM.Lockfile.Check.extraneous(@pkg, @lockfile)
    end

    test "detects extraneous packages" do
      lockfile = Map.put(@lockfile, "debug", %{version: "4.3.0"})
      extra = NPM.Lockfile.Check.extraneous(@pkg, lockfile)
      assert "debug" in extra
    end
  end

  describe "mismatched" do
    test "no mismatches when versions satisfy" do
      assert [] = NPM.Lockfile.Check.mismatched(@pkg, @lockfile)
    end

    test "detects version mismatch" do
      lockfile =
        Map.put(@lockfile, "lodash", %{
          version: "3.10.0",
          integrity: "",
          tarball: "",
          dependencies: %{}
        })

      mismatched = NPM.Lockfile.Check.mismatched(@pkg, lockfile)
      assert length(mismatched) == 1
      {name, range, version} = hd(mismatched)
      assert name == "lodash"
      assert range == "^4.17.0"
      assert version == "3.10.0"
    end
  end

  describe "check" do
    test "valid when consistent" do
      result = NPM.Lockfile.Check.check(@pkg, @lockfile)
      assert result.valid
      assert result.missing == []
      assert result.mismatched == []
    end

    test "invalid when missing deps" do
      result = NPM.Lockfile.Check.check(@pkg, %{})
      refute result.valid
      assert length(result.missing) == 3
    end
  end

  describe "format_results" do
    test "consistent message" do
      assert "Lockfile is consistent." =
               NPM.Lockfile.Check.format_results(%{valid: true, extraneous: []})
    end

    test "extraneous only message" do
      result = %{valid: true, extraneous: ["debug"]}
      assert NPM.Lockfile.Check.format_results(result) =~ "1 extraneous"
    end

    test "missing and mismatched" do
      result = %{
        valid: false,
        missing: ["jest"],
        extraneous: [],
        mismatched: [{"lodash", "^4.17.0", "3.10.0"}]
      }

      formatted = NPM.Lockfile.Check.format_results(result)
      assert formatted =~ "Missing: jest"
      assert formatted =~ "Mismatched: lodash"
    end
  end
end
