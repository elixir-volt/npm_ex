defmodule NPM.WorkspacesTest do
  use ExUnit.Case, async: true

  describe "globs" do
    test "extracts array workspaces" do
      data = %{"workspaces" => ["packages/*", "apps/*"]}
      assert ["packages/*", "apps/*"] = NPM.Workspaces.globs(data)
    end

    test "extracts object workspaces" do
      data = %{"workspaces" => %{"packages" => ["packages/*"]}}
      assert ["packages/*"] = NPM.Workspaces.globs(data)
    end

    test "empty for no workspaces" do
      assert [] = NPM.Workspaces.globs(%{})
    end
  end

  describe "configured?" do
    test "true with workspaces" do
      assert NPM.Workspaces.configured?(%{"workspaces" => ["packages/*"]})
    end

    test "false without" do
      refute NPM.Workspaces.configured?(%{})
    end
  end

  describe "discover" do
    @tag :tmp_dir
    test "finds workspace packages", %{tmp_dir: dir} do
      pkg_dir = Path.join([dir, "packages", "my-pkg"])
      File.mkdir_p!(pkg_dir)
      File.write!(Path.join(pkg_dir, "package.json"), ~s({"name":"my-pkg","version":"1.0.0"}))

      result = NPM.Workspaces.discover(dir, ["packages/*"])
      assert length(result) == 1
      assert hd(result).name == "my-pkg"
    end

    @tag :tmp_dir
    test "empty for no matching dirs", %{tmp_dir: dir} do
      assert [] = NPM.Workspaces.discover(dir, ["packages/*"])
    end
  end

  describe "validate" do
    test "no issues for valid packages" do
      pkgs = [%{name: "a", version: "1.0.0", path: "/a", private: false}]
      assert [] = NPM.Workspaces.validate(pkgs)
    end

    test "detects missing name" do
      pkgs = [%{name: nil, version: "1.0.0", path: "/a", private: false}]
      issues = NPM.Workspaces.validate(pkgs)
      assert Enum.any?(issues, &(&1.issue =~ "missing name"))
    end

    test "detects missing version" do
      pkgs = [%{name: "a", version: nil, path: "/a", private: false}]
      issues = NPM.Workspaces.validate(pkgs)
      assert Enum.any?(issues, &(&1.issue =~ "missing version"))
    end

    test "detects duplicate names" do
      pkgs = [
        %{name: "a", version: "1.0.0", path: "/a1", private: false},
        %{name: "a", version: "2.0.0", path: "/a2", private: false}
      ]

      issues = NPM.Workspaces.validate(pkgs)
      assert Enum.any?(issues, &(&1.issue =~ "duplicate"))
    end
  end

  describe "count" do
    test "counts workspace globs" do
      data = %{"workspaces" => ["packages/*", "apps/*"]}
      assert 2 = NPM.Workspaces.count(data)
    end

    test "zero for no workspaces" do
      assert 0 = NPM.Workspaces.count(%{})
    end
  end
end
