defmodule NPM.Security.CVETest do
  use ExUnit.Case, async: true

  alias NPM.Security.CVE

  @advisories [
    %{"severity" => "critical", "module_name" => "lodash", "cves" => ["CVE-2021-23337"]},
    %{"severity" => "high", "module_name" => "lodash", "cves" => ["CVE-2020-28500"]},
    %{"severity" => "moderate", "module_name" => "minimist", "cves" => ["CVE-2021-44906"]},
    %{"severity" => "low", "module_name" => "debug", "cves" => []}
  ]

  describe "extract_cves" do
    test "extracts from cves array" do
      assert ["CVE-2021-23337"] = CVE.extract_cves(%{"cves" => ["CVE-2021-23337"]})
    end

    test "extracts from cve string" do
      assert ["CVE-2021-23337"] = CVE.extract_cves(%{"cve" => "CVE-2021-23337"})
    end

    test "extracts from references text" do
      refs = "See https://nvd.nist.gov/vuln/detail/CVE-2021-23337 for details"
      assert ["CVE-2021-23337"] = CVE.extract_cves(%{"references" => refs})
    end

    test "empty when no CVEs" do
      assert [] = CVE.extract_cves(%{"title" => "advisory"})
    end
  end

  describe "compare_severity" do
    test "critical > high" do
      assert :gt = CVE.compare_severity("critical", "high")
    end

    test "low < moderate" do
      assert :lt = CVE.compare_severity("low", "moderate")
    end

    test "same severity" do
      assert :eq = CVE.compare_severity("high", "high")
    end
  end

  describe "max_severity" do
    test "returns highest severity" do
      assert "critical" = CVE.max_severity(@advisories)
    end

    test "none for empty list" do
      assert "none" = CVE.max_severity([])
    end

    test "single advisory" do
      assert "moderate" = CVE.max_severity([%{"severity" => "moderate"}])
    end
  end

  describe "group_by_package" do
    test "groups advisories by package" do
      grouped = CVE.group_by_package(@advisories)
      assert length(grouped["lodash"]) == 2
      assert length(grouped["minimist"]) == 1
    end
  end

  describe "severity_counts" do
    test "counts by severity" do
      counts = CVE.severity_counts(@advisories)
      assert counts["critical"] == 1
      assert counts["high"] == 1
      assert counts["moderate"] == 1
      assert counts["low"] == 1
    end

    test "empty list" do
      assert %{} = CVE.severity_counts([])
    end
  end

  describe "above_threshold?" do
    test "true when critical exists above moderate threshold" do
      assert CVE.above_threshold?(@advisories, "moderate")
    end

    test "false when all below threshold" do
      low_only = [%{"severity" => "low"}]
      refute CVE.above_threshold?(low_only, "high")
    end

    test "true for exact threshold match" do
      assert CVE.above_threshold?([%{"severity" => "high"}], "high")
    end
  end

  describe "format_summary" do
    test "formats vulnerability counts" do
      formatted = CVE.format_summary(@advisories)
      assert formatted =~ "4 vulnerabilities"
      assert formatted =~ "1 critical"
      assert formatted =~ "1 high"
    end

    test "no vulnerabilities message" do
      assert "No known vulnerabilities." = CVE.format_summary([])
    end
  end
end
