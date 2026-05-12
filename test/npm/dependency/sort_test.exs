defmodule NPM.Dependency.SortTest do
  use ExUnit.Case, async: true

  @adj %{
    "app" => ["express", "lodash"],
    "express" => ["body-parser"],
    "body-parser" => ["raw-body"],
    "lodash" => [],
    "raw-body" => []
  }

  describe "sort" do
    test "topological order: roots come first" do
      {:ok, order} = NPM.Dependency.Sort.sort(@adj)
      assert Enum.find_index(order, &(&1 == "app")) < Enum.find_index(order, &(&1 == "lodash"))
    end

    test "contains all packages" do
      {:ok, order} = NPM.Dependency.Sort.sort(@adj)
      assert length(order) == 5
    end
  end

  describe "install_order" do
    test "leaves first for correct install" do
      order = NPM.Dependency.Sort.install_order(@adj)
      assert Enum.find_index(order, &(&1 == "lodash")) < Enum.find_index(order, &(&1 == "app"))
    end

    test "handles empty graph" do
      assert [] = NPM.Dependency.Sort.install_order(%{})
    end
  end

  describe "parallel_levels" do
    test "first level contains leaves" do
      levels = NPM.Dependency.Sort.parallel_levels(@adj)
      first = hd(levels)
      assert "lodash" in first
      assert "raw-body" in first
    end

    test "multiple levels" do
      levels = NPM.Dependency.Sort.parallel_levels(@adj)
      assert length(levels) >= 3
    end
  end

  describe "level_count" do
    test "counts levels" do
      count = NPM.Dependency.Sort.level_count(@adj)
      assert count >= 3
    end

    test "single level for independent packages" do
      adj = %{"a" => [], "b" => [], "c" => []}
      assert 1 = NPM.Dependency.Sort.level_count(adj)
    end
  end
end
