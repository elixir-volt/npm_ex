defmodule NPM.Dependency.TreeTest do
  use ExUnit.Case, async: true

  alias NPM.Dependency.Tree

  describe "DepTree.build" do
    test "builds simple tree" do
      lockfile = %{
        "a" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{"b" => "^1.0"}},
        "b" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      tree = Tree.build(lockfile, %{"a" => "^1.0"})
      assert length(tree) == 1
      assert hd(tree).name == "a"
      assert hd(tree).children |> hd() |> Map.get(:name) == "b"
    end

    test "handles circular deps" do
      lockfile = %{
        "a" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{"b" => "^1.0"}},
        "b" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{"a" => "^1.0"}}
      }

      tree = Tree.build(lockfile, %{"a" => "^1.0"})
      assert length(tree) == 1
    end

    test "handles missing dep" do
      lockfile = %{
        "a" => %{
          version: "1.0.0",
          integrity: "",
          tarball: "",
          dependencies: %{"missing" => "^1.0"}
        }
      }

      tree = Tree.build(lockfile, %{"a" => "^1.0"})
      assert hd(tree).children == []
    end
  end

  describe "DepTree.flatten" do
    test "flattens tree to unique names" do
      lockfile = %{
        "a" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{"b" => "^1.0"}},
        "b" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      tree = Tree.build(lockfile, %{"a" => "^1.0"})
      assert Tree.flatten(tree) == ["a", "b"]
    end
  end

  describe "DepTree.paths_to" do
    test "finds path to transitive dep" do
      lockfile = %{
        "a" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{"b" => "^1.0"}},
        "b" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{"c" => "^1.0"}},
        "c" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      tree = Tree.build(lockfile, %{"a" => "^1.0"})
      paths = Tree.paths_to(tree, "c")
      assert [["a", "b", "c"]] = paths
    end

    test "returns empty for non-existent target" do
      lockfile = %{
        "a" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      tree = Tree.build(lockfile, %{"a" => "^1.0"})
      assert [] = Tree.paths_to(tree, "z")
    end
  end

  describe "DepTree.depth" do
    test "root dep has depth 0" do
      lockfile = %{
        "a" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      tree = Tree.build(lockfile, %{"a" => "^1.0"})
      assert 0 = Tree.depth(tree, "a")
    end

    test "transitive dep has correct depth" do
      lockfile = %{
        "a" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{"b" => "^1.0"}},
        "b" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      tree = Tree.build(lockfile, %{"a" => "^1.0"})
      assert 1 = Tree.depth(tree, "b")
    end

    test "returns nil for missing" do
      tree = Tree.build(%{}, %{})
      assert nil == Tree.depth(tree, "z")
    end
  end

  describe "DepTree.count" do
    test "counts unique packages" do
      lockfile = %{
        "a" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{"b" => "^1.0"}},
        "b" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      tree = Tree.build(lockfile, %{"a" => "^1.0"})
      assert 2 = Tree.count(tree)
    end
  end

  describe "DepTree: edge cases" do
    test "empty lockfile produces empty tree" do
      tree = Tree.build(%{}, %{})
      all = Tree.flatten(tree)
      assert all == []
    end

    test "count returns total packages" do
      lockfile = %{
        "a" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{"b" => "^1.0"}},
        "b" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      tree = Tree.build(lockfile, %{"a" => "^1.0"})
      assert Tree.count(tree) == 2
    end
  end

  describe "DepTree: build with circular deps" do
    test "handles circular dependencies without infinite loop" do
      lockfile = %{
        "a" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{"b" => "^1.0"}},
        "b" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{"a" => "^1.0"}}
      }

      tree = Tree.build(lockfile, %{"a" => "^1.0"})
      all = Tree.flatten(tree)
      assert "a" in all
      assert "b" in all
    end
  end

  describe "DepTree: count with deep tree" do
    test "counts all transitive deps" do
      lockfile = %{
        "a" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{"b" => "^1"}},
        "b" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{"c" => "^1"}},
        "c" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{"d" => "^1"}},
        "d" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      tree = Tree.build(lockfile, %{"a" => "^1.0"})
      assert Tree.count(tree) == 4
    end
  end

  describe "DepTree: flatten uniqueness" do
    test "flatten returns unique package names" do
      lockfile = %{
        "a" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{"c" => "^1.0"}},
        "b" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{"c" => "^1.0"}},
        "c" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      tree = Tree.build(lockfile, %{"a" => "^1.0", "b" => "^1.0"})
      flat = Tree.flatten(tree)
      assert flat == Enum.uniq(flat)
    end
  end

  describe "DepTree: paths_to specific package" do
    test "finds path from root to target" do
      lockfile = %{
        "a" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{"b" => "^1.0"}},
        "b" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{"c" => "^1.0"}},
        "c" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      tree = Tree.build(lockfile, %{"a" => "^1.0"})
      paths = Tree.paths_to(tree, "c")
      assert paths != []
    end
  end

  describe "DepTree: real dependency graph traversal" do
    test "finds all transitive deps" do
      lockfile = %{
        "express" => %{
          version: "4.21.2",
          integrity: "",
          tarball: "",
          dependencies: %{"debug" => "2.6.9", "cookie" => "0.7.1"}
        },
        "debug" => %{version: "2.6.9", integrity: "", tarball: "", dependencies: %{}},
        "cookie" => %{version: "0.7.1", integrity: "", tarball: "", dependencies: %{}}
      }

      tree = Tree.build(lockfile, %{"express" => "^4.21.0"})
      all = Tree.flatten(tree)
      assert "express" in all
      assert "debug" in all
      assert "cookie" in all
    end

    test "depth is correct for deep chains" do
      lockfile = %{
        "a" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{"b" => "^1.0"}},
        "b" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{"c" => "^1.0"}},
        "c" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{"d" => "^1.0"}},
        "d" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      tree = Tree.build(lockfile, %{"a" => "^1.0"})
      assert 0 = Tree.depth(tree, "a")
      assert 1 = Tree.depth(tree, "b")
      assert 2 = Tree.depth(tree, "c")
      assert 3 = Tree.depth(tree, "d")
    end
  end

  describe "DepTree: depth of packages" do
    test "root dep has depth 1, transitive dep has depth 2" do
      lockfile = %{
        "a" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{"b" => "^1"}},
        "b" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      tree = Tree.build(lockfile, %{"a" => "^1.0"})
      assert Tree.depth(tree, "a") == 0
      assert Tree.depth(tree, "b") == 1
    end
  end

  describe "DepTree: paths_to finds all paths" do
    test "finds path through transitive deps" do
      lockfile = %{
        "a" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{"b" => "^1"}},
        "b" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{"c" => "^1"}},
        "c" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      tree = Tree.build(lockfile, %{"a" => "^1.0"})
      paths = Tree.paths_to(tree, "c")
      assert paths != []
    end
  end
end
