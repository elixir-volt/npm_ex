defmodule NPM.Dependency.GraphTest do
  use ExUnit.Case, async: true

  alias NPM.Dependency.Graph
  alias NPM.Dependency.Tree

  describe "DepGraph + DepTree integration" do
    test "graph leaves match tree leaves" do
      lockfile = %{
        "a" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{"b" => "^1.0"}},
        "b" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      adj = Graph.adjacency_list(lockfile)
      graph_leaves = Graph.leaves(adj)

      tree = Tree.build(lockfile, %{"a" => "^1.0"})

      tree_leaves =
        tree
        |> Tree.flatten()
        |> Enum.filter(fn name ->
          entry = lockfile[name]
          entry && entry.dependencies == %{}
        end)
        |> Enum.sort()

      assert graph_leaves == tree_leaves
    end
  end

  describe "DepGraph.adjacency_list" do
    test "builds adjacency list from lockfile" do
      lockfile = %{
        "a" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{"b" => "^1.0"}},
        "b" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      adj = Graph.adjacency_list(lockfile)
      assert adj["a"] == ["b"]
      assert adj["b"] == []
    end
  end

  describe "DepGraph.fan_out" do
    test "counts dependencies per package" do
      adj = %{"a" => ["b", "c"], "b" => ["c"], "c" => []}
      fout = Graph.fan_out(adj)
      assert fout["a"] == 2
      assert fout["b"] == 1
      assert fout["c"] == 0
    end
  end

  describe "DepGraph.fan_in" do
    test "counts dependents per package" do
      adj = %{"a" => ["b", "c"], "b" => ["c"], "c" => []}
      fin = Graph.fan_in(adj)
      assert fin["a"] == 0
      assert fin["b"] == 1
      assert fin["c"] == 2
    end
  end

  describe "DepGraph.leaves" do
    test "finds leaf packages" do
      adj = %{"a" => ["b"], "b" => [], "c" => []}
      assert Graph.leaves(adj) == ["b", "c"]
    end
  end

  describe "DepGraph.roots" do
    test "finds root packages" do
      adj = %{"a" => ["b"], "b" => ["c"], "c" => []}
      assert Graph.roots(adj) == ["a"]
    end

    test "multiple roots" do
      adj = %{"a" => ["c"], "b" => ["c"], "c" => []}
      assert Graph.roots(adj) == ["a", "b"]
    end
  end

  describe "DepGraph.cycles" do
    test "detects simple cycle" do
      adj = %{"a" => ["b"], "b" => ["a"]}
      cycles = Graph.cycles(adj)
      assert cycles != []
    end

    test "no cycles in dag" do
      adj = %{"a" => ["b"], "b" => ["c"], "c" => []}
      assert Graph.cycles(adj) == []
    end
  end

  describe "DepGraph: fan_out counting" do
    test "fan_out counts outgoing edges" do
      adj = %{"a" => ["b", "c"], "b" => ["c"], "c" => []}
      fan_out = Graph.fan_out(adj)
      assert fan_out["a"] == 2
      assert fan_out["b"] == 1
      assert fan_out["c"] == 0
    end
  end

  describe "DepGraph: complete graph analysis" do
    test "graph with diamond dependency" do
      lockfile = %{
        "app" => %{
          version: "1.0.0",
          integrity: "",
          tarball: "",
          dependencies: %{"a" => "^1", "b" => "^1"}
        },
        "a" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{"shared" => "^1"}},
        "b" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{"shared" => "^1"}},
        "shared" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      adj = Graph.adjacency_list(lockfile)
      fan_in = Graph.fan_in(adj)
      assert fan_in["shared"] == 2

      leaves = Graph.leaves(adj)
      assert "shared" in leaves
    end
  end

  describe "DepGraph: fan_out consistency" do
    test "total fan_out equals total edges" do
      adj = %{"a" => ["b", "c"], "b" => ["c"], "c" => []}
      fan_out = Graph.fan_out(adj)
      total = fan_out |> Map.values() |> Enum.sum()
      assert total == 3
    end
  end

  describe "DepGraph: isolates detection" do
    test "finds isolated nodes with no edges" do
      adj = %{"a" => ["b"], "b" => [], "c" => []}
      roots = Graph.roots(adj)
      leaves = Graph.leaves(adj)
      # c is both a root and a leaf (isolated)
      assert "c" in roots
      assert "c" in leaves
    end
  end

  describe "DepGraph: cycle detection with self-reference" do
    test "self-referencing package creates cycle" do
      adj = %{"a" => ["a"]}
      cycles = Graph.cycles(adj)
      assert cycles != []
    end
  end

  describe "DepGraph: roots in complex graph" do
    test "multiple roots detected" do
      adj = %{"a" => ["c"], "b" => ["c"], "c" => []}
      roots = Graph.roots(adj)
      assert "a" in roots
      assert "b" in roots
      refute "c" in roots
    end
  end

  describe "DepGraph: adjacency_list construction" do
    test "handles empty lockfile" do
      adj = Graph.adjacency_list(%{})
      assert adj == %{}
    end

    test "sorts dependency names" do
      lockfile = %{
        "a" => %{
          version: "1.0.0",
          integrity: "",
          tarball: "",
          dependencies: %{"z" => "^1.0", "m" => "^1.0", "a" => "^1.0"}
        }
      }

      adj = Graph.adjacency_list(lockfile)
      assert adj["a"] == ["a", "m", "z"]
    end
  end

  describe "DepGraph: adjacency list and analysis" do
    test "fan_in counts incoming edges" do
      lockfile = %{
        "a" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{"c" => "^1.0"}},
        "b" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{"c" => "^1.0"}},
        "c" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      adj = Graph.adjacency_list(lockfile)
      fan_in = Graph.fan_in(adj)
      assert fan_in["c"] == 2
      assert fan_in["a"] == 0
    end

    test "leaves are packages with no dependencies" do
      lockfile = %{
        "a" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{"b" => "^1.0"}},
        "b" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      adj = Graph.adjacency_list(lockfile)
      leaves = Graph.leaves(adj)
      assert "b" in leaves
      refute "a" in leaves
    end

    test "roots are packages not depended on" do
      lockfile = %{
        "a" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{"b" => "^1.0"}},
        "b" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      adj = Graph.adjacency_list(lockfile)
      roots = Graph.roots(adj)
      assert "a" in roots
      refute "b" in roots
    end

    test "cycles detected in circular deps" do
      adj = %{"a" => ["b"], "b" => ["c"], "c" => ["a"]}
      cycles = Graph.cycles(adj)
      assert cycles != []
    end

    test "no cycles in acyclic graph" do
      adj = %{"a" => ["b"], "b" => ["c"], "c" => []}
      cycles = Graph.cycles(adj)
      assert cycles == []
    end
  end

  describe "DepGraph: adjacency_list from lockfile" do
    test "builds adjacency list" do
      lockfile = %{
        "a" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{"b" => "^1"}},
        "b" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      adj = Graph.adjacency_list(lockfile)
      assert adj["a"] == ["b"]
      assert adj["b"] == []
    end
  end

  describe "DepGraph: fan_in reverse of fan_out" do
    test "leaf has zero fan_out, root has zero fan_in" do
      adj = %{"root" => ["child"], "child" => []}
      fan_out = Graph.fan_out(adj)
      fan_in = Graph.fan_in(adj)
      assert fan_out["root"] == 1
      assert fan_out["child"] == 0
      assert fan_in["root"] == 0
      assert fan_in["child"] == 1
    end
  end

  describe "DepGraph: leaves detection" do
    test "nodes with no dependencies are leaves" do
      adj = %{"a" => ["b", "c"], "b" => ["c"], "c" => []}
      leaves = Graph.leaves(adj)
      assert "c" in leaves
      refute "a" in leaves
      refute "b" in leaves
    end
  end
end
