defmodule NPM.Diagnostics.HealthTest do
  use ExUnit.Case, async: true

  alias NPM.Diagnostics.Health

  @healthy_checks %{
    has_lockfile: true,
    has_package_json: true,
    integrity_pct: 100,
    vulnerability_count: 0,
    outdated_count: 0,
    has_license: true,
    no_deprecated: true
  }

  @unhealthy_checks %{
    has_lockfile: false,
    has_package_json: false,
    integrity_pct: 0,
    vulnerability_count: 5,
    outdated_count: 20,
    has_license: false,
    no_deprecated: false
  }

  describe "score" do
    test "healthy project scores high" do
      result = Health.score(@healthy_checks)
      assert result.score >= 90
    end

    test "unhealthy project scores low" do
      result = Health.score(@unhealthy_checks)
      assert result.score < 30
    end

    test "partial health gives middle score" do
      checks = %{
        has_lockfile: true,
        has_package_json: true,
        integrity_pct: 80,
        vulnerability_count: 2,
        outdated_count: 3,
        has_license: true,
        no_deprecated: false
      }

      result = Health.score(checks)
      assert result.score > 30 and result.score < 80
    end

    test "returns details breakdown" do
      result = Health.score(@healthy_checks)
      assert is_map(result.details)
      assert result.details[:has_lockfile] == 15
    end

    test "score capped at 100" do
      result = Health.score(@healthy_checks)
      assert result.score <= 100
    end
  end

  describe "grade" do
    test "A for 90+" do
      assert "A" = Health.grade(95)
    end

    test "B for 80-89" do
      assert "B" = Health.grade(85)
    end

    test "C for 70-79" do
      assert "C" = Health.grade(75)
    end

    test "D for 60-69" do
      assert "D" = Health.grade(65)
    end

    test "F for below 60" do
      assert "F" = Health.grade(50)
    end
  end

  describe "recommendations" do
    test "recommends lockfile creation" do
      recs = Health.recommendations(%{has_lockfile: false})
      assert Enum.any?(recs, &String.contains?(&1, "lockfile"))
    end

    test "recommends audit for vulns" do
      recs = Health.recommendations(%{vulnerability_count: 3})
      assert Enum.any?(recs, &String.contains?(&1, "audit"))
    end

    test "no recommendations for healthy project" do
      recs = Health.recommendations(@healthy_checks)
      assert recs == []
    end
  end

  describe "format_report" do
    test "includes score and grade" do
      result = Health.score(@healthy_checks)
      formatted = Health.format_report(result)
      assert formatted =~ "Health Score:"
      assert formatted =~ "/100"
    end
  end
end
