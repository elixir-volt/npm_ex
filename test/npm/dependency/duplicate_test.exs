defmodule NPM.Dependency.DuplicateTest do
  use ExUnit.Case, async: true

  describe "find" do
    test "finds no duplicates when all unique" do
      lockfile = %{
        "lodash" => %{version: "4.17.21"},
        "react" => %{version: "18.2.0"}
      }

      assert [] = NPM.Dependency.Duplicate.find(lockfile)
    end

    test "empty lockfile" do
      assert [] = NPM.Dependency.Duplicate.find(%{})
    end
  end

  describe "count" do
    test "zero when no duplicates" do
      assert 0 = NPM.Dependency.Duplicate.count(%{"a" => %{version: "1.0.0"}})
    end

    test "zero for empty" do
      assert 0 = NPM.Dependency.Duplicate.count(%{})
    end
  end

  describe "format_report" do
    test "formats duplicate list" do
      dupes = [%{name: "lodash", versions: ["4.17.20", "4.17.21"]}]
      formatted = NPM.Dependency.Duplicate.format_report(dupes)
      assert formatted =~ "lodash"
      assert formatted =~ "4.17.20"
      assert formatted =~ "4.17.21"
    end

    test "empty message" do
      assert "No duplicate packages found." = NPM.Dependency.Duplicate.format_report([])
    end
  end

  describe "potential_savings" do
    test "calculates extra copies" do
      dupes = [
        %{name: "a", versions: ["1.0", "2.0"]},
        %{name: "b", versions: ["1.0", "2.0", "3.0"]}
      ]

      assert 3 = NPM.Dependency.Duplicate.potential_savings(dupes)
    end

    test "zero for no duplicates" do
      assert 0 = NPM.Dependency.Duplicate.potential_savings([])
    end

    test "single duplicate" do
      dupes = [%{name: "a", versions: ["1.0", "2.0"]}]
      assert 1 = NPM.Dependency.Duplicate.potential_savings(dupes)
    end
  end

  describe "format_report details" do
    test "shows count in header" do
      dupes = [
        %{name: "a", versions: ["1.0", "2.0"]},
        %{name: "b", versions: ["3.0", "4.0"]}
      ]

      formatted = NPM.Dependency.Duplicate.format_report(dupes)
      assert formatted =~ "2"
    end

    test "includes all version numbers" do
      dupes = [%{name: "pkg", versions: ["1.0.0", "1.1.0", "2.0.0"]}]
      formatted = NPM.Dependency.Duplicate.format_report(dupes)
      assert formatted =~ "1.0.0"
      assert formatted =~ "1.1.0"
      assert formatted =~ "2.0.0"
    end
  end
end
