defmodule NPM.OutdatedReportTest do
  use ExUnit.Case, async: true

  @packages [
    %{name: "lodash", current: "4.17.20", wanted: "4.17.21", latest: "4.17.21", type: :patch},
    %{name: "express", current: "3.0.0", wanted: "3.21.0", latest: "4.18.2", type: :major},
    %{name: "react", current: "17.0.2", wanted: "17.0.2", latest: "18.2.0", type: :major}
  ]

  describe "format_table" do
    test "formats header and rows" do
      output = NPM.OutdatedReport.format_table(@packages)
      assert output =~ "Package"
      assert output =~ "lodash"
      assert output =~ "express"
    end

    test "all up to date" do
      assert "All packages are up to date." = NPM.OutdatedReport.format_table([])
    end

    test "aligns columns" do
      output = NPM.OutdatedReport.format_table(@packages)
      lines = String.split(output, "\n")
      assert length(lines) == 4
    end
  end

  describe "categorize" do
    test "groups by severity" do
      cat = NPM.OutdatedReport.categorize(@packages)
      assert length(cat.major) == 2
      assert length(cat.patch) == 1
      assert cat.minor == []
    end
  end

  describe "summary" do
    test "generates summary" do
      sum = NPM.OutdatedReport.summary(@packages)
      assert sum =~ "3 outdated"
      assert sum =~ "2 major"
      assert sum =~ "1 patch"
    end

    test "all up to date" do
      assert "All packages are up to date." = NPM.OutdatedReport.summary([])
    end
  end

  describe "security_risk" do
    test "finds major version packages" do
      risks = NPM.OutdatedReport.security_risk(@packages)
      assert length(risks) == 2
      assert Enum.all?(risks, &(&1.type == :major))
    end

    test "empty when no majors" do
      packages = [%{name: "a", current: "1.0.0", latest: "1.0.1", type: :patch}]
      assert [] = NPM.OutdatedReport.security_risk(packages)
    end
  end
end
