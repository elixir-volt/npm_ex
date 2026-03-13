defmodule NPM.TreeTest do
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
    "react" => %{version: "18.2.0", integrity: "", tarball: "", dependencies: %{}}
  }

  @root_deps %{"express" => "^4.0.0", "react" => "^18.0.0"}

  describe "build" do
    test "builds tree from lockfile and root deps" do
      tree = NPM.Tree.build(@lockfile, @root_deps)
      assert Map.has_key?(tree, "express")
      assert Map.has_key?(tree, "react")
      assert tree["express"].version == "4.21.2"
      assert tree["react"].children == %{}
    end

    test "includes transitive dependencies" do
      tree = NPM.Tree.build(@lockfile, @root_deps)
      assert Map.has_key?(tree["express"].children, "ms")
      assert Map.has_key?(tree["express"].children, "debug")
    end

    test "handles missing packages" do
      root_deps = %{"ghost" => "^1.0.0"}
      tree = NPM.Tree.build(@lockfile, root_deps)
      assert tree["ghost"].version == "MISSING"
    end

    test "detects circular dependencies" do
      lockfile = %{
        "a" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{"b" => "^1.0"}},
        "b" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{"a" => "^1.0"}}
      }

      tree = NPM.Tree.build(lockfile, %{"a" => "^1.0"})
      b_child = tree["a"].children["b"]
      assert b_child.children["a"].version == "(circular)"
    end
  end

  describe "format" do
    test "formats simple tree" do
      tree = NPM.Tree.build(@lockfile, %{"react" => "^18.0.0"})
      formatted = NPM.Tree.format(tree)
      assert formatted =~ "react@18.2.0"
    end

    test "formats nested tree with indentation" do
      tree = NPM.Tree.build(@lockfile, %{"express" => "^4.0.0"})
      formatted = NPM.Tree.format(tree)
      assert formatted =~ "express@4.21.2"
      assert formatted =~ "  ms@2.1.3"
      assert formatted =~ "  debug@2.6.9"
    end

    test "empty tree" do
      assert "" = NPM.Tree.format(%{})
    end
  end

  describe "flatten" do
    test "returns all packages with depth" do
      tree = NPM.Tree.build(@lockfile, @root_deps)
      flat = NPM.Tree.flatten(tree)

      names = Enum.map(flat, &elem(&1, 0))
      assert "express" in names
      assert "react" in names
      assert "ms" in names
    end

    test "root deps at depth 0" do
      tree = NPM.Tree.build(@lockfile, @root_deps)
      flat = NPM.Tree.flatten(tree)

      root_entries = Enum.filter(flat, fn {_, _, depth} -> depth == 0 end)
      root_names = Enum.map(root_entries, &elem(&1, 0))
      assert "express" in root_names
      assert "react" in root_names
    end

    test "transitive deps at depth > 0" do
      tree = NPM.Tree.build(@lockfile, @root_deps)
      flat = NPM.Tree.flatten(tree)

      ms_entries = Enum.filter(flat, fn {name, _, _} -> name == "ms" end)
      assert Enum.all?(ms_entries, fn {_, _, depth} -> depth > 0 end)
    end
  end

  describe "max_depth" do
    test "empty tree has depth 0" do
      assert 0 = NPM.Tree.max_depth(%{})
    end

    test "flat deps have depth 1" do
      tree = NPM.Tree.build(@lockfile, %{"react" => "^18.0.0"})
      assert 1 = NPM.Tree.max_depth(tree)
    end

    test "nested deps increase depth" do
      tree = NPM.Tree.build(@lockfile, %{"express" => "^4.0.0"})
      assert NPM.Tree.max_depth(tree) >= 2
    end
  end

  describe "count" do
    test "counts all nodes including nested" do
      tree = NPM.Tree.build(@lockfile, %{"express" => "^4.0.0"})
      assert NPM.Tree.count(tree) >= 3
    end

    test "empty tree has 0 count" do
      assert 0 = NPM.Tree.count(%{})
    end

    test "single leaf package" do
      tree = NPM.Tree.build(@lockfile, %{"react" => "^18.0.0"})
      assert 1 = NPM.Tree.count(tree)
    end
  end

  describe "filter" do
    test "filters by package name pattern" do
      tree = NPM.Tree.build(@lockfile, @root_deps)
      filtered = NPM.Tree.filter(tree, "ms")
      assert Map.has_key?(filtered, "express")
      refute Map.has_key?(filtered, "react")
    end

    test "empty pattern matches everything" do
      tree = NPM.Tree.build(@lockfile, @root_deps)
      filtered = NPM.Tree.filter(tree, "")
      assert map_size(filtered) == map_size(tree)
    end

    test "no match returns empty" do
      tree = NPM.Tree.build(@lockfile, @root_deps)
      filtered = NPM.Tree.filter(tree, "zzz-nonexistent")
      assert map_size(filtered) == 0
    end
  end
end
