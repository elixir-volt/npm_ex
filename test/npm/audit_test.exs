defmodule NPM.AuditTest do
  use ExUnit.Case, async: true

  @sample_advisory %{
    id: 1234,
    title: "Prototype Pollution",
    severity: :high,
    vulnerable_versions: "<4.17.20",
    patched_versions: ">=4.17.20",
    url: "https://npmjs.com/advisories/1234"
  }

  @critical_advisory %{
    id: 5678,
    title: "Remote Code Execution",
    severity: :critical,
    vulnerable_versions: "<2.0.0",
    patched_versions: ">=2.0.0",
    url: nil
  }

  @no_patch_advisory %{
    id: 9999,
    title: "Information Disclosure",
    severity: :low,
    vulnerable_versions: ">=1.0.0",
    patched_versions: nil,
    url: nil
  }

  describe "check finds vulnerable packages" do
    test "matches package in vulnerable range" do
      lockfile = %{
        "lodash" => %{version: "4.17.19", integrity: "", tarball: "", dependencies: %{}}
      }

      findings = NPM.Audit.check(lockfile, [@sample_advisory])
      assert length(findings) == 1
      assert hd(findings).package == "lodash"
      assert hd(findings).installed_version == "4.17.19"
    end

    test "skips package outside vulnerable range" do
      lockfile = %{
        "lodash" => %{version: "4.17.21", integrity: "", tarball: "", dependencies: %{}}
      }

      findings = NPM.Audit.check(lockfile, [@sample_advisory])
      assert findings == []
    end

    test "empty lockfile returns no findings" do
      assert [] = NPM.Audit.check(%{}, [@sample_advisory])
    end

    test "empty advisories returns no findings" do
      lockfile = %{
        "lodash" => %{version: "3.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      assert [] = NPM.Audit.check(lockfile, [])
    end
  end

  describe "check sorts by severity" do
    test "critical comes before high" do
      lockfile = %{
        "low-pkg" => %{version: "4.17.19", integrity: "", tarball: "", dependencies: %{}},
        "high-pkg" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      findings = NPM.Audit.check(lockfile, [@sample_advisory, @critical_advisory])
      severities = Enum.map(findings, & &1.advisory.severity)
      crit_idx = Enum.find_index(severities, &(&1 == :critical))
      high_idx = Enum.find_index(severities, &(&1 == :high))

      if crit_idx && high_idx do
        assert crit_idx < high_idx
      end
    end
  end

  describe "fixable?" do
    test "true when patched_versions is set" do
      finding = %{package: "a", installed_version: "1.0.0", advisory: @sample_advisory}
      assert NPM.Audit.fixable?(finding)
    end

    test "false when patched_versions is nil" do
      finding = %{package: "a", installed_version: "1.0.0", advisory: @no_patch_advisory}
      refute NPM.Audit.fixable?(finding)
    end

    test "false when patched_versions is empty string" do
      advisory = %{@sample_advisory | patched_versions: ""}
      finding = %{package: "a", installed_version: "1.0.0", advisory: advisory}
      refute NPM.Audit.fixable?(finding)
    end
  end

  describe "filter_by_severity" do
    test "filters to high and above" do
      findings = [
        %{
          package: "a",
          installed_version: "1.0.0",
          advisory: %{@sample_advisory | severity: :critical}
        },
        %{
          package: "b",
          installed_version: "1.0.0",
          advisory: %{@sample_advisory | severity: :high}
        },
        %{
          package: "c",
          installed_version: "1.0.0",
          advisory: %{@sample_advisory | severity: :moderate}
        },
        %{
          package: "d",
          installed_version: "1.0.0",
          advisory: %{@sample_advisory | severity: :low}
        }
      ]

      high_plus = NPM.Audit.filter_by_severity(findings, :high)
      assert length(high_plus) == 2
      severities = Enum.map(high_plus, & &1.advisory.severity)
      assert :critical in severities
      assert :high in severities
    end

    test "critical only" do
      findings = [
        %{
          package: "a",
          installed_version: "1.0.0",
          advisory: %{@sample_advisory | severity: :critical}
        },
        %{
          package: "b",
          installed_version: "1.0.0",
          advisory: %{@sample_advisory | severity: :high}
        }
      ]

      critical = NPM.Audit.filter_by_severity(findings, :critical)
      assert length(critical) == 1
    end
  end

  describe "summary" do
    test "counts by severity and fixability" do
      findings = [
        %{package: "a", installed_version: "1.0.0", advisory: @critical_advisory},
        %{package: "b", installed_version: "1.0.0", advisory: @sample_advisory},
        %{package: "c", installed_version: "1.0.0", advisory: @no_patch_advisory}
      ]

      s = NPM.Audit.summary(findings)
      assert s.total == 3
      assert s.critical == 1
      assert s.high == 1
      assert s.low == 1
      assert s.fixable == 2
    end

    test "empty findings" do
      s = NPM.Audit.summary([])
      assert s.total == 0
      assert s.critical == 0
    end
  end

  describe "format_finding" do
    test "includes severity and package info" do
      finding = %{package: "lodash", installed_version: "4.17.19", advisory: @sample_advisory}
      formatted = NPM.Audit.format_finding(finding)
      assert formatted =~ "HIGH"
      assert formatted =~ "Prototype Pollution"
      assert formatted =~ "lodash@4.17.19"
    end
  end

  describe "compare_severity" do
    test "critical is higher than high" do
      assert :gt = NPM.Audit.compare_severity(:critical, :high)
    end

    test "low is lower than moderate" do
      assert :lt = NPM.Audit.compare_severity(:low, :moderate)
    end

    test "same severity is equal" do
      assert :eq = NPM.Audit.compare_severity(:high, :high)
    end
  end
end
