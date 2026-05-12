defmodule NPM.Dependency.DedupeReportTest do
  use ExUnit.Case, async: true

  alias NPM.Dependency.Dedupe

  describe "find" do
    test "finds no duplicates when all unique" do
      lockfile = %{
        "lodash" => %{version: "4.17.21"},
        "react" => %{version: "18.2.0"}
      }

      assert [] = Dedupe.find(lockfile)
    end

    test "empty lockfile" do
      assert [] = Dedupe.find(%{})
    end
  end

  describe "count" do
    test "zero when no duplicates" do
      assert 0 = Dedupe.count(%{"a" => %{version: "1.0.0"}})
    end

    test "zero for empty" do
      assert 0 = Dedupe.count(%{})
    end
  end

  describe "format_report" do
    test "formats duplicate list" do
      dupes = [%{name: "lodash", versions: ["4.17.20", "4.17.21"]}]
      formatted = Dedupe.format_report(dupes)
      assert formatted =~ "lodash"
      assert formatted =~ "4.17.20"
      assert formatted =~ "4.17.21"
    end

    test "empty message" do
      assert "No duplicate packages found." = Dedupe.format_report([])
    end
  end

  describe "potential_savings" do
    test "calculates extra copies" do
      dupes = [
        %{name: "a", versions: ["1.0", "2.0"]},
        %{name: "b", versions: ["1.0", "2.0", "3.0"]}
      ]

      assert 3 = Dedupe.potential_savings(dupes)
    end

    test "zero for no duplicates" do
      assert 0 = Dedupe.potential_savings([])
    end

    test "single duplicate" do
      dupes = [%{name: "a", versions: ["1.0", "2.0"]}]
      assert 1 = Dedupe.potential_savings(dupes)
    end
  end

  describe "format_report details" do
    test "shows count in header" do
      dupes = [
        %{name: "a", versions: ["1.0", "2.0"]},
        %{name: "b", versions: ["3.0", "4.0"]}
      ]

      formatted = Dedupe.format_report(dupes)
      assert formatted =~ "2"
    end

    test "includes all version numbers" do
      dupes = [%{name: "pkg", versions: ["1.0.0", "1.1.0", "2.0.0"]}]
      formatted = Dedupe.format_report(dupes)
      assert formatted =~ "1.0.0"
      assert formatted =~ "1.1.0"
      assert formatted =~ "2.0.0"
    end
  end
end
