defmodule NPM.Dependency.StatsTest do
  use ExUnit.Case, async: true

  @lockfile %{
    "@babel/core" => %{version: "7.23.0", dependencies: %{"@babel/parser" => "^7.23"}},
    "@babel/parser" => %{version: "7.23.0", dependencies: %{}},
    "lodash" => %{version: "4.17.21", dependencies: %{}},
    "react" => %{version: "18.2.0", dependencies: %{}},
    "express" => %{version: "4.18.2", dependencies: %{"debug" => "^4.0"}}
  }

  describe "compute" do
    test "returns stats" do
      stats = NPM.Dependency.Stats.compute(@lockfile)
      assert stats.total == 5
      assert stats.scoped == 2
    end
  end

  describe "top_scopes" do
    test "finds most common scopes" do
      scopes = NPM.Dependency.Stats.top_scopes(@lockfile)
      assert {"babel", 2} in scopes
    end

    test "empty for no scoped packages" do
      assert [] = NPM.Dependency.Stats.top_scopes(%{"lodash" => %{version: "4.17.21"}})
    end
  end

  describe "avg_deps" do
    test "computes average" do
      avg = NPM.Dependency.Stats.avg_deps(@lockfile)
      assert avg > 0
    end

    test "zero for empty" do
      assert 0.0 = NPM.Dependency.Stats.avg_deps(%{})
    end
  end

  describe "format" do
    test "formats readable output" do
      stats = NPM.Dependency.Stats.compute(@lockfile)
      formatted = NPM.Dependency.Stats.format(stats)
      assert formatted =~ "Total packages: 5"
      assert formatted =~ "Scoped: 2"
      assert formatted =~ "@babel"
    end
  end
end
