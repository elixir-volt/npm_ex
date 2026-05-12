defmodule NPM.StatsTest do
  use ExUnit.Case, async: true

  @lockfile %{
    "express" => %{
      version: "4.21.2",
      integrity: "",
      tarball: "",
      dependencies: %{"ms" => "^2.0.0", "debug" => "^2.6.9"}
    },
    "debug" => %{
      version: "2.6.9",
      integrity: "",
      tarball: "",
      dependencies: %{"ms" => "^2.0.0"}
    },
    "ms" => %{version: "2.1.3", integrity: "", tarball: "", dependencies: %{}},
    "react" => %{version: "18.2.0", integrity: "", tarball: "", dependencies: %{}},
    "@babel/core" => %{version: "7.24.0", integrity: "", tarball: "", dependencies: %{}}
  }

  @root_deps %{"express" => "^4.0.0", "react" => "^18.0.0", "@babel/core" => "^7.0.0"}

  describe "compute" do
    test "counts total packages" do
      stats = NPM.Stats.compute(@lockfile, @root_deps)
      assert stats.total_packages == 5
    end

    test "counts direct dependencies" do
      stats = NPM.Stats.compute(@lockfile, @root_deps)
      assert stats.direct_deps == 3
    end

    test "counts transitive dependencies" do
      stats = NPM.Stats.compute(@lockfile, @root_deps)
      assert stats.transitive_deps == 2
    end

    test "counts scoped packages" do
      stats = NPM.Stats.compute(@lockfile, @root_deps)
      assert stats.scoped_packages == 1
    end

    test "computes average dep count" do
      stats = NPM.Stats.compute(@lockfile, @root_deps)
      assert stats.avg_dep_count > 0
    end

    test "computes max dep chain" do
      stats = NPM.Stats.compute(@lockfile, @root_deps)
      assert stats.max_dep_chain >= 3
    end

    test "empty lockfile" do
      stats = NPM.Stats.compute(%{}, %{})
      assert stats.total_packages == 0
      assert stats.avg_dep_count == 0.0
    end
  end

  describe "version_distribution" do
    test "groups by major version" do
      dist = NPM.Stats.version_distribution(@lockfile)
      assert Map.has_key?(dist, "4.x") or Map.has_key?(dist, "2.x")
    end

    test "empty lockfile" do
      assert %{} = NPM.Stats.version_distribution(%{})
    end
  end

  describe "connectivity" do
    test "measures graph density" do
      conn = NPM.Stats.connectivity(@lockfile)
      assert conn > 0.0
    end

    test "zero for empty lockfile" do
      assert NPM.Stats.connectivity(%{}) == 0.0
    end

    test "zero for packages with no deps" do
      lockfile = %{
        "a" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}},
        "b" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      assert NPM.Stats.connectivity(lockfile) == 0.0
    end
  end

  describe "most_depended" do
    test "finds most referenced packages" do
      top = NPM.Stats.most_depended(@lockfile, 3)
      names = Enum.map(top, &elem(&1, 0))
      assert "ms" in names
    end

    test "empty lockfile" do
      assert [] = NPM.Stats.most_depended(%{})
    end

    test "ms has highest fan-in" do
      top = NPM.Stats.most_depended(@lockfile, 1)
      {name, count} = hd(top)
      assert name == "ms"
      assert count == 2
    end
  end
end
