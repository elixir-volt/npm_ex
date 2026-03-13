defmodule NPM.BundleAnalysisTest do
  use ExUnit.Case, async: true

  @perfect_pkg %{
    "type" => "module",
    "sideEffects" => false,
    "exports" => %{"." => "./dist/index.mjs"},
    "module" => "./dist/index.mjs",
    "files" => ["dist/"]
  }

  @basic_pkg %{"main" => "./index.js"}

  describe "score" do
    test "perfect package scores 100" do
      assert 100 = NPM.BundleAnalysis.score(@perfect_pkg)
    end

    test "basic package scores low" do
      score = NPM.BundleAnalysis.score(@basic_pkg)
      assert score < 20
    end

    test "partial ESM package" do
      data = %{"type" => "module", "exports" => %{"." => "./index.js"}}
      score = NPM.BundleAnalysis.score(data)
      assert score >= 45
    end
  end

  describe "grade" do
    test "excellent for 80+" do
      assert "excellent" = NPM.BundleAnalysis.grade(85)
    end

    test "good for 60-79" do
      assert "good" = NPM.BundleAnalysis.grade(65)
    end

    test "fair for 40-59" do
      assert "fair" = NPM.BundleAnalysis.grade(45)
    end

    test "poor for 20-39" do
      assert "poor" = NPM.BundleAnalysis.grade(25)
    end

    test "minimal for <20" do
      assert "minimal" = NPM.BundleAnalysis.grade(10)
    end
  end

  describe "recommendations" do
    test "no recommendations for perfect package" do
      assert [] = NPM.BundleAnalysis.recommendations(@perfect_pkg)
    end

    test "recommendations for basic package" do
      recs = NPM.BundleAnalysis.recommendations(@basic_pkg)
      assert length(recs) >= 3
    end

    test "includes ESM recommendation" do
      recs = NPM.BundleAnalysis.recommendations(@basic_pkg)
      assert Enum.any?(recs, &String.contains?(&1, "module"))
    end
  end

  describe "analyze" do
    test "analyzes packages" do
      packages = [
        {"perfect", @perfect_pkg},
        {"basic", @basic_pkg}
      ]

      result = NPM.BundleAnalysis.analyze(packages)
      assert result.average_score > 0
      assert is_binary(result.grade)
    end

    test "empty packages" do
      result = NPM.BundleAnalysis.analyze([])
      assert result.average_score == 0
    end
  end
end
