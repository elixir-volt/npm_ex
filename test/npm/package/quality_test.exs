defmodule NPM.Package.QualityTest do
  use ExUnit.Case, async: true

  @high_quality %{
    "name" => "good-pkg",
    "version" => "1.0.0",
    "description" => "A good package",
    "license" => "MIT",
    "repository" => "user/repo",
    "homepage" => "https://example.com",
    "bugs" => %{"url" => "https://example.com/issues"},
    "keywords" => ["test"],
    "engines" => %{"node" => ">=18"},
    "types" => "./dist/index.d.ts",
    "exports" => %{"." => "./dist/index.js"},
    "files" => ["dist/"],
    "author" => "Test Author"
  }

  @minimal %{"name" => "bare", "version" => "1.0.0"}

  describe "score" do
    test "high quality package scores well" do
      score = NPM.Package.Quality.score(@high_quality)
      assert score >= 90
    end

    test "minimal package scores low" do
      score = NPM.Package.Quality.score(@minimal)
      assert score < 30
    end
  end

  describe "grade" do
    test "A grade" do
      assert "A" = NPM.Package.Quality.grade(95)
    end

    test "B grade" do
      assert "B" = NPM.Package.Quality.grade(80)
    end

    test "F grade" do
      assert "F" = NPM.Package.Quality.grade(30)
    end
  end

  describe "missing_fields" do
    test "none for complete package" do
      assert [] = NPM.Package.Quality.missing_fields(@high_quality)
    end

    test "many for minimal package" do
      missing = NPM.Package.Quality.missing_fields(@minimal)
      assert "description" in missing
      assert "license" in missing
      assert "repository" in missing
    end
  end

  describe "rank" do
    test "ranks by score descending" do
      packages = [{"minimal", @minimal}, {"good", @high_quality}]
      ranked = NPM.Package.Quality.rank(packages)
      assert hd(ranked) |> elem(0) == "good"
    end
  end

  describe "average" do
    test "computes average score" do
      packages = [{"good", @high_quality}, {"minimal", @minimal}]
      avg = NPM.Package.Quality.average(packages)
      assert avg > 0
    end

    test "zero for empty" do
      assert 0.0 = NPM.Package.Quality.average([])
    end
  end
end
