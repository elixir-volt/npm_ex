defmodule NPM.SupplyChainTest do
  use ExUnit.Case, async: true

  @pkg %{"dependencies" => %{"express" => "^4.18", "lodash" => "^4.17"}}
  @lockfile %{
    "express" => %{version: "4.18.2", integrity: "sha512-abc"},
    "lodash" => %{version: "4.17.21", integrity: "sha512-xyz"},
    "debug" => %{version: "4.3.4", integrity: "sha512-def"}
  }

  describe "assess" do
    test "computes assessment" do
      result = NPM.SupplyChain.assess(@pkg, @lockfile)
      assert result.total_packages == 3
      assert result.phantom_deps == 1
      assert result.integrity_coverage == 100.0
    end

    test "empty lockfile" do
      result = NPM.SupplyChain.assess(@pkg, %{})
      assert result.total_packages == 0
      assert result.integrity_coverage == 0.0
    end

    test "low risk with full integrity and no phantoms" do
      pkg = %{"dependencies" => %{"a" => "^1.0", "b" => "^2.0"}}

      lockfile = %{
        "a" => %{version: "1.0.0", integrity: "sha512-x"},
        "b" => %{version: "2.0.0", integrity: "sha512-y"}
      }

      result = NPM.SupplyChain.assess(pkg, lockfile)
      assert result.risk_level == :low
    end

    test "high risk without integrity" do
      pkg = %{"dependencies" => %{"a" => "^1.0"}}
      lockfile = %{"a" => %{version: "1.0.0"}, "phantom1" => %{version: "1.0"}}
      result = NPM.SupplyChain.assess(pkg, lockfile)
      assert result.risk_level == :high
    end
  end

  describe "risk_score" do
    test "low score for good integrity" do
      assessment = %{integrity_coverage: 100.0, phantom_deps: 0, total_packages: 10}
      assert NPM.SupplyChain.risk_score(assessment) == 0
    end

    test "higher score for poor integrity" do
      assessment = %{integrity_coverage: 0.0, phantom_deps: 10, total_packages: 20}
      score = NPM.SupplyChain.risk_score(assessment)
      assert score > 50
    end
  end

  describe "format" do
    test "formats assessment" do
      assessment = %{
        risk_level: :medium,
        total_packages: 50,
        integrity_coverage: 75.0,
        phantom_deps: 3
      }

      formatted = NPM.SupplyChain.format(assessment)
      assert formatted =~ "medium"
      assert formatted =~ "75.0%"
    end
  end
end
