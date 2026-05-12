defmodule NPM.Dependency.GraphAdvancedTest do
  use ExUnit.Case, async: true

  alias NPM.Dependency.Graph

  @adj %{
    "app" => ["express", "lodash"],
    "express" => ["body-parser", "lodash"],
    "body-parser" => ["raw-body"],
    "lodash" => [],
    "raw-body" => []
  }

  describe "transitive_deps" do
    test "finds all reachable packages" do
      deps = Graph.transitive_deps(@adj, "app")
      assert MapSet.member?(deps, "express")
      assert MapSet.member?(deps, "body-parser")
      assert MapSet.member?(deps, "raw-body")
      assert MapSet.member?(deps, "lodash")
    end

    test "leaf has no transitive deps" do
      deps = Graph.transitive_deps(@adj, "lodash")
      assert MapSet.size(deps) == 0
    end
  end

  describe "shortest_path" do
    test "finds direct path" do
      path = Graph.shortest_path(@adj, "app", "lodash")
      assert path == ["app", "lodash"]
    end

    test "finds indirect path" do
      path = Graph.shortest_path(@adj, "app", "raw-body")
      assert path == ["app", "express", "body-parser", "raw-body"]
    end

    test "nil for unreachable" do
      assert nil == Graph.shortest_path(@adj, "raw-body", "app")
    end

    test "same node path" do
      path = Graph.shortest_path(@adj, "app", "app")
      assert path == ["app"]
    end
  end

  describe "max_depth" do
    test "computes max depth from root" do
      assert 3 = Graph.max_depth(@adj, "app")
    end

    test "zero depth for leaf" do
      assert 0 = Graph.max_depth(@adj, "lodash")
    end
  end

  describe "impact" do
    test "lodash has high impact" do
      score = Graph.impact(@adj, "lodash")
      assert score >= 2
    end

    test "leaf with no dependents" do
      assert 0 = Graph.impact(@adj, "app")
    end
  end

  describe "leaves" do
    test "finds leaf packages" do
      leaves = Graph.leaves(@adj)
      assert "lodash" in leaves
      assert "raw-body" in leaves
    end
  end

  describe "roots" do
    test "finds root packages" do
      roots = Graph.roots(@adj)
      assert "app" in roots
    end
  end

  describe "reverse" do
    test "reverses edges" do
      rev = Graph.reverse(@adj)
      assert "app" in rev["express"]
      assert "express" in rev["body-parser"]
    end
  end
end
