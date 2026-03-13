defmodule NPM.BundleDepsTest do
  use ExUnit.Case, async: true

  describe "extract" do
    test "extracts bundledDependencies array" do
      data = %{"bundledDependencies" => ["pkg-a", "pkg-b"]}
      assert ["pkg-a", "pkg-b"] = NPM.BundleDeps.extract(data)
    end

    test "extracts bundleDependencies (alternate spelling)" do
      data = %{"bundleDependencies" => ["pkg-a"]}
      assert ["pkg-a"] = NPM.BundleDeps.extract(data)
    end

    test "bundledDependencies: true includes all deps" do
      data = %{"bundledDependencies" => true, "dependencies" => %{"a" => "^1", "b" => "^2"}}
      result = NPM.BundleDeps.extract(data)
      assert "a" in result
      assert "b" in result
    end

    test "bundleDependencies: true includes all deps" do
      data = %{"bundleDependencies" => true, "dependencies" => %{"x" => "^1"}}
      assert ["x"] = NPM.BundleDeps.extract(data)
    end

    test "no bundled deps returns empty" do
      assert [] = NPM.BundleDeps.extract(%{"name" => "pkg"})
    end

    test "empty array" do
      assert [] = NPM.BundleDeps.extract(%{"bundledDependencies" => []})
    end
  end

  describe "bundled?" do
    test "true for bundled package" do
      data = %{"bundledDependencies" => ["lodash"]}
      assert NPM.BundleDeps.bundled?("lodash", data)
    end

    test "false for non-bundled package" do
      data = %{"bundledDependencies" => ["lodash"]}
      refute NPM.BundleDeps.bundled?("react", data)
    end
  end

  describe "validate" do
    test "ok when all bundled deps are declared" do
      data = %{
        "dependencies" => %{"a" => "^1", "b" => "^2"},
        "bundledDependencies" => ["a", "b"]
      }

      assert {:ok, ["a", "b"]} = NPM.BundleDeps.validate(data)
    end

    test "error for undeclared bundled dep" do
      data = %{
        "dependencies" => %{"a" => "^1"},
        "bundledDependencies" => ["a", "missing"]
      }

      assert {:error, errors} = NPM.BundleDeps.validate(data)
      assert Enum.any?(errors, &String.contains?(&1, "missing"))
    end

    test "ok for empty bundled deps" do
      data = %{"bundledDependencies" => []}
      assert {:ok, []} = NPM.BundleDeps.validate(data)
    end
  end

  describe "count" do
    test "counts bundled deps" do
      data = %{"bundledDependencies" => ["a", "b", "c"]}
      assert 3 = NPM.BundleDeps.count(data)
    end

    test "zero when none bundled" do
      assert 0 = NPM.BundleDeps.count(%{})
    end
  end
end
