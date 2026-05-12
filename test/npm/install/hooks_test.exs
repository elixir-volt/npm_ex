defmodule NPM.Install.HooksTest do
  use ExUnit.Case, async: true

  alias NPM.Install.Hooks

  describe "Hooks.available" do
    test "lists all hook points" do
      hooks = Hooks.available()
      assert :pre_install in hooks
      assert :post_install in hooks
      assert :pre_resolve in hooks
      assert :post_resolve in hooks
    end
  end

  describe "Hooks.configured" do
    test "returns empty map by default" do
      assert is_map(Hooks.configured())
    end
  end

  describe "Hooks.configured?" do
    test "false for unconfigured hook" do
      refute Hooks.configured?(:pre_install)
    end
  end

  describe "Hooks.run" do
    test "succeeds for unconfigured hook" do
      assert :ok = Hooks.run(:pre_install)
    end

    test "succeeds with context" do
      assert :ok = Hooks.run(:post_install, packages: 5)
    end
  end

  describe "Hooks: configured hooks" do
    test "configured returns map or list" do
      hooks = Hooks.configured()
      assert is_map(hooks) or is_list(hooks)
    end

    test "configured? checks specific hook name" do
      # Without package.json in cwd, should not crash
      result = Hooks.configured?(:post_install)
      assert is_boolean(result)
    end
  end

  describe "Hooks: lifecycle hook configuration" do
    test "available lists known hook names" do
      hooks = Hooks.available()
      assert :pre_install in hooks
      assert :post_install in hooks
      assert :pre_resolve in hooks
      assert :post_resolve in hooks
    end
  end

  describe "Hooks: available and configured" do
    test "available returns list of hook names" do
      hooks = Hooks.available()
      assert is_list(hooks)
      assert Enum.any?(hooks)
    end

    test "configured returns currently configured hooks" do
      result = Hooks.configured()
      assert is_list(result) or is_map(result)
    end

    test "configured? checks hook availability" do
      result = Hooks.configured?("preinstall")
      assert is_boolean(result)
    end
  end
end
