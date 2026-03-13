defmodule NPM.WorkspaceTest do
  use ExUnit.Case, async: true

  describe "discover workspaces" do
    @tag :tmp_dir
    test "finds workspace packages from globs", %{tmp_dir: dir} do
      File.write!(
        Path.join(dir, "package.json"),
        ~s({"workspaces": ["packages/*"]})
      )

      pkg_a = Path.join([dir, "packages", "pkg-a"])
      pkg_b = Path.join([dir, "packages", "pkg-b"])
      File.mkdir_p!(pkg_a)
      File.mkdir_p!(pkg_b)

      File.write!(
        Path.join(pkg_a, "package.json"),
        ~s({"name": "@mono/pkg-a", "version": "1.0.0"})
      )

      File.write!(
        Path.join(pkg_b, "package.json"),
        ~s({"name": "@mono/pkg-b", "version": "2.0.0"})
      )

      {:ok, packages} = NPM.Workspace.discover(dir)
      names = Enum.map(packages, & &1.name) |> Enum.sort()
      assert "@mono/pkg-a" in names
      assert "@mono/pkg-b" in names
    end

    @tag :tmp_dir
    test "returns empty for no workspaces", %{tmp_dir: dir} do
      File.write!(Path.join(dir, "package.json"), ~s({"name": "no-ws"}))
      {:ok, packages} = NPM.Workspace.discover(dir)
      assert packages == []
    end

    @tag :tmp_dir
    test "skips directories without package.json", %{tmp_dir: dir} do
      File.write!(Path.join(dir, "package.json"), ~s({"workspaces": ["packages/*"]}))
      File.mkdir_p!(Path.join([dir, "packages", "no-pkg"]))

      {:ok, packages} = NPM.Workspace.discover(dir)
      assert packages == []
    end
  end

  describe "workspace names" do
    @tag :tmp_dir
    test "returns just the names", %{tmp_dir: dir} do
      File.write!(Path.join(dir, "package.json"), ~s({"workspaces": ["packages/*"]}))
      pkg = Path.join([dir, "packages", "my-lib"])
      File.mkdir_p!(pkg)
      File.write!(Path.join(pkg, "package.json"), ~s({"name": "my-lib"}))

      {:ok, names} = NPM.Workspace.names(dir)
      assert names == ["my-lib"]
    end
  end

  describe "workspace_root?" do
    @tag :tmp_dir
    test "true for directory with workspaces", %{tmp_dir: dir} do
      File.write!(Path.join(dir, "package.json"), ~s({"workspaces": ["packages/*"]}))
      assert NPM.Workspace.workspace_root?(dir)
    end

    @tag :tmp_dir
    test "false for regular package", %{tmp_dir: dir} do
      File.write!(Path.join(dir, "package.json"), ~s({"name": "regular"}))
      refute NPM.Workspace.workspace_root?(dir)
    end

    @tag :tmp_dir
    test "false for directory without package.json", %{tmp_dir: dir} do
      refute NPM.Workspace.workspace_root?(dir)
    end
  end

  describe "dep_graph inter-workspace dependencies" do
    test "finds internal dependencies" do
      packages = [
        %{
          name: "app",
          version: "1.0.0",
          path: "/app",
          dependencies: %{"shared" => "^1.0", "lodash" => "^4"}
        },
        %{name: "shared", version: "1.0.0", path: "/shared", dependencies: %{"utils" => "^1.0"}},
        %{name: "utils", version: "1.0.0", path: "/utils", dependencies: %{}}
      ]

      graph = NPM.Workspace.dep_graph(packages)
      assert graph["app"] == ["shared"]
      assert graph["shared"] == ["utils"]
      assert graph["utils"] == []
    end

    test "excludes external dependencies" do
      packages = [
        %{
          name: "my-pkg",
          version: "1.0.0",
          path: "/pkg",
          dependencies: %{"react" => "^18", "lodash" => "^4"}
        }
      ]

      graph = NPM.Workspace.dep_graph(packages)
      assert graph["my-pkg"] == []
    end
  end

  describe "build_order topological sort" do
    test "dependencies come before dependents" do
      packages = [
        %{name: "app", version: "1.0.0", path: "/app", dependencies: %{"shared" => "^1.0"}},
        %{name: "shared", version: "1.0.0", path: "/shared", dependencies: %{"utils" => "^1.0"}},
        %{name: "utils", version: "1.0.0", path: "/utils", dependencies: %{}}
      ]

      order = NPM.Workspace.build_order(packages)
      assert Enum.find_index(order, &(&1 == "utils")) < Enum.find_index(order, &(&1 == "shared"))
      assert Enum.find_index(order, &(&1 == "shared")) < Enum.find_index(order, &(&1 == "app"))
    end

    test "independent packages can be in any order" do
      packages = [
        %{name: "a", version: "1.0.0", path: "/a", dependencies: %{}},
        %{name: "b", version: "1.0.0", path: "/b", dependencies: %{}},
        %{name: "c", version: "1.0.0", path: "/c", dependencies: %{}}
      ]

      order = NPM.Workspace.build_order(packages)
      assert Enum.sort(order) == ["a", "b", "c"]
    end

    test "diamond dependency is handled" do
      packages = [
        %{
          name: "app",
          version: "1.0.0",
          path: "/app",
          dependencies: %{"left" => "^1", "right" => "^1"}
        },
        %{name: "left", version: "1.0.0", path: "/left", dependencies: %{"core" => "^1"}},
        %{name: "right", version: "1.0.0", path: "/right", dependencies: %{"core" => "^1"}},
        %{name: "core", version: "1.0.0", path: "/core", dependencies: %{}}
      ]

      order = NPM.Workspace.build_order(packages)
      core_idx = Enum.find_index(order, &(&1 == "core"))
      left_idx = Enum.find_index(order, &(&1 == "left"))
      right_idx = Enum.find_index(order, &(&1 == "right"))
      app_idx = Enum.find_index(order, &(&1 == "app"))

      assert core_idx < left_idx
      assert core_idx < right_idx
      assert left_idx < app_idx
      assert right_idx < app_idx
    end
  end

  describe "build_order single package" do
    test "single package returns just that name" do
      packages = [
        %{name: "solo", version: "1.0.0", path: "/solo", dependencies: %{}}
      ]

      assert ["solo"] = NPM.Workspace.build_order(packages)
    end
  end

  describe "dep_graph with no internal deps" do
    test "all packages have empty dependency lists" do
      packages = [
        %{name: "a", version: "1.0.0", path: "/a", dependencies: %{"lodash" => "^4"}},
        %{name: "b", version: "1.0.0", path: "/b", dependencies: %{"react" => "^18"}}
      ]

      graph = NPM.Workspace.dep_graph(packages)
      assert graph["a"] == []
      assert graph["b"] == []
    end
  end

  describe "workspace_root? with empty workspaces array" do
    @tag :tmp_dir
    test "false for empty workspaces array", %{tmp_dir: dir} do
      File.write!(Path.join(dir, "package.json"), ~s({"workspaces": []}))
      refute NPM.Workspace.workspace_root?(dir)
    end
  end
end
