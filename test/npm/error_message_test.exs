defmodule NPM.ErrorMessageTest do
  use ExUnit.Case, async: true

  describe "format" do
    test "no package.json" do
      msg = NPM.ErrorMessage.format({:error, :no_package_json})
      assert msg =~ "package.json not found"
      assert msg =~ "mix npm.init"
    end

    test "no lockfile" do
      msg = NPM.ErrorMessage.format({:error, :no_lockfile})
      assert msg =~ "npm.lock not found"
    end

    test "frozen lockfile" do
      msg = NPM.ErrorMessage.format({:error, :frozen_lockfile})
      assert msg =~ "out of sync"
    end

    test "resolution failed" do
      msg = NPM.ErrorMessage.format({:error, :resolution_failed})
      assert msg =~ "resolution failed"
    end

    test "integrity mismatch with name" do
      msg = NPM.ErrorMessage.format({:error, :integrity_mismatch, "lodash"})
      assert msg =~ "lodash"
      assert msg =~ "cache"
    end

    test "network error" do
      msg = NPM.ErrorMessage.format({:error, :network_error})
      assert msg =~ "Network error"
    end

    test "package not found" do
      msg = NPM.ErrorMessage.format({:error, :package_not_found, "nonexistent"})
      assert msg =~ "nonexistent"
      assert msg =~ "typos"
    end

    test "unknown atom error" do
      msg = NPM.ErrorMessage.format({:error, :something_weird})
      assert msg =~ "something_weird"
    end
  end

  describe "suggestion" do
    test "returns suggestion for known errors" do
      assert "mix npm.init" = NPM.ErrorMessage.suggestion(:no_package_json)
      assert "mix npm.install" = NPM.ErrorMessage.suggestion(:no_lockfile)
    end

    test "nil for unknown errors" do
      assert nil == NPM.ErrorMessage.suggestion(:unknown)
    end
  end

  describe "retryable?" do
    test "network errors are retryable" do
      assert NPM.ErrorMessage.retryable?(:network_error)
      assert NPM.ErrorMessage.retryable?(:timeout)
    end

    test "logic errors are not retryable" do
      refute NPM.ErrorMessage.retryable?(:no_package_json)
      refute NPM.ErrorMessage.retryable?(:resolution_failed)
    end
  end
end
