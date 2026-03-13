defmodule NPM.ResolutionsTest do
  use ExUnit.Case, async: true

  describe "parse" do
    test "parses resolutions map" do
      data = %{"resolutions" => %{"lodash" => "4.17.21", "ms" => "3.0.0"}}
      resolutions = NPM.Resolutions.parse(data)
      assert length(resolutions) == 2
      lodash = Enum.find(resolutions, &(&1.pattern == "lodash"))
      assert lodash.version == "4.17.21"
    end

    test "returns empty for no resolutions" do
      assert [] = NPM.Resolutions.parse(%{"name" => "pkg"})
    end

    test "returns empty for empty resolutions" do
      assert [] = NPM.Resolutions.parse(%{"resolutions" => %{}})
    end
  end

  describe "matches?" do
    test "exact name match" do
      assert NPM.Resolutions.matches?("lodash", "lodash")
    end

    test "glob pattern match" do
      assert NPM.Resolutions.matches?("ms", "**/ms")
    end

    test "no match" do
      refute NPM.Resolutions.matches?("react", "lodash")
    end

    test "scoped package exact match" do
      assert NPM.Resolutions.matches?("@babel/core", "@babel/core")
    end
  end

  describe "resolve" do
    test "finds matching resolution" do
      resolutions = [
        %{pattern: "lodash", version: "4.17.21"},
        %{pattern: "**/ms", version: "3.0.0"}
      ]

      assert "4.17.21" = NPM.Resolutions.resolve("lodash", resolutions)
      assert "3.0.0" = NPM.Resolutions.resolve("ms", resolutions)
    end

    test "returns nil for unmatched package" do
      resolutions = [%{pattern: "lodash", version: "4.17.21"}]
      assert nil == NPM.Resolutions.resolve("react", resolutions)
    end

    test "empty resolutions" do
      assert nil == NPM.Resolutions.resolve("anything", [])
    end
  end

  describe "apply_resolutions" do
    test "replaces matching versions" do
      lockfile = %{
        "lodash" => %{version: "4.17.20", integrity: "", tarball: "", dependencies: %{}},
        "react" => %{version: "18.2.0", integrity: "", tarball: "", dependencies: %{}}
      }

      resolutions = [%{pattern: "lodash", version: "4.17.21"}]
      {new_lf, count} = NPM.Resolutions.apply_resolutions(lockfile, resolutions)
      assert new_lf["lodash"].version == "4.17.21"
      assert new_lf["react"].version == "18.2.0"
      assert count == 1
    end

    test "no matches means no changes" do
      lockfile = %{
        "react" => %{version: "18.2.0", integrity: "", tarball: "", dependencies: %{}}
      }

      resolutions = [%{pattern: "lodash", version: "4.17.21"}]
      {new_lf, count} = NPM.Resolutions.apply_resolutions(lockfile, resolutions)
      assert new_lf == lockfile
      assert count == 0
    end

    test "empty lockfile" do
      {result, count} = NPM.Resolutions.apply_resolutions(%{}, [%{pattern: "x", version: "1.0"}])
      assert result == %{}
      assert count == 0
    end
  end
end
