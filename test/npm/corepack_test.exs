defmodule NPM.CorepackTest do
  use ExUnit.Case, async: true

  @npm_pkg %{"packageManager" => "npm@10.2.0"}
  @pnpm_pkg %{"packageManager" => "pnpm@8.10.0"}
  @yarn_pkg %{"packageManager" => "yarn@4.0.0+sha256.abc123"}

  describe "get" do
    test "returns packageManager value" do
      assert "npm@10.2.0" = NPM.Corepack.get(@npm_pkg)
    end

    test "nil for no field" do
      assert nil == NPM.Corepack.get(%{})
    end
  end

  describe "manager_name" do
    test "npm" do
      assert "npm" = NPM.Corepack.manager_name(@npm_pkg)
    end

    test "pnpm" do
      assert "pnpm" = NPM.Corepack.manager_name(@pnpm_pkg)
    end

    test "yarn" do
      assert "yarn" = NPM.Corepack.manager_name(@yarn_pkg)
    end

    test "nil for no field" do
      assert nil == NPM.Corepack.manager_name(%{})
    end
  end

  describe "manager_version" do
    test "extracts version" do
      assert "10.2.0" = NPM.Corepack.manager_version(@npm_pkg)
    end

    test "strips hash from yarn" do
      assert "4.0.0" = NPM.Corepack.manager_version(@yarn_pkg)
    end

    test "nil for no field" do
      assert nil == NPM.Corepack.manager_version(%{})
    end
  end

  describe "manager predicates" do
    test "npm?" do
      assert NPM.Corepack.npm?(@npm_pkg)
      refute NPM.Corepack.npm?(@pnpm_pkg)
    end

    test "pnpm?" do
      assert NPM.Corepack.pnpm?(@pnpm_pkg)
      refute NPM.Corepack.pnpm?(@npm_pkg)
    end

    test "yarn?" do
      assert NPM.Corepack.yarn?(@yarn_pkg)
      refute NPM.Corepack.yarn?(@npm_pkg)
    end
  end

  describe "configured?" do
    test "true when set" do
      assert NPM.Corepack.configured?(@npm_pkg)
    end

    test "false when not set" do
      refute NPM.Corepack.configured?(%{})
    end
  end

  describe "format" do
    test "with package manager" do
      assert "Package manager: npm@10.2.0" = NPM.Corepack.format(@npm_pkg)
    end

    test "without package manager" do
      assert "No package manager configured" = NPM.Corepack.format(%{})
    end
  end
end
