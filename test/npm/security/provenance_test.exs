defmodule NPM.Security.ProvenanceTest do
  use ExUnit.Case, async: true

  alias NPM.Security.Provenance

  @lockfile %{
    "lodash" => %{version: "4.17.21", integrity: "sha512-abc", tarball: "", dependencies: %{}},
    "react" => %{version: "18.2.0", integrity: "", tarball: "", dependencies: %{}},
    "axios" => %{
      version: "1.6.0",
      integrity: "sha512-def",
      tarball: "",
      dependencies: %{},
      provenance: true
    }
  }

  describe "has_provenance?" do
    test "true with provenance field" do
      assert Provenance.has_provenance?(%{provenance: true})
    end

    test "true with attestations field" do
      assert Provenance.has_provenance?(%{attestations: []})
    end

    test "false without provenance" do
      refute Provenance.has_provenance?(%{version: "1.0.0"})
    end
  end

  describe "scan" do
    test "separates packages by provenance" do
      result = Provenance.scan(@lockfile)
      assert "axios" in result.with_provenance
      assert "lodash" in result.without
      assert "react" in result.without
    end

    test "empty lockfile" do
      result = Provenance.scan(%{})
      assert result.with_provenance == []
      assert result.without == []
    end
  end

  describe "trusted_registry?" do
    test "npmjs.org is trusted" do
      assert Provenance.trusted_registry?("https://registry.npmjs.org")
    end

    test "unknown registry is not trusted" do
      refute Provenance.trusted_registry?("https://evil.registry.com")
    end
  end

  describe "has_integrity?" do
    test "true with sha hash" do
      assert Provenance.has_integrity?(%{integrity: "sha512-abc"})
    end

    test "false with empty integrity" do
      refute Provenance.has_integrity?(%{integrity: ""})
    end

    test "false without integrity field" do
      refute Provenance.has_integrity?(%{version: "1.0.0"})
    end
  end

  describe "risk_summary" do
    test "computes summary stats" do
      summary = Provenance.risk_summary(@lockfile)
      assert summary.total == 3
      assert summary.with_integrity == 2
      assert summary.without_integrity == 1
      assert summary.with_provenance == 1
    end

    test "empty lockfile" do
      summary = Provenance.risk_summary(%{})
      assert summary.total == 0
      assert summary.integrity_pct == 0.0
    end
  end

  describe "format_summary" do
    test "formats readable output" do
      summary = Provenance.risk_summary(@lockfile)
      formatted = Provenance.format_summary(summary)
      assert formatted =~ "Total packages: 3"
      assert formatted =~ "With integrity"
    end
  end
end
