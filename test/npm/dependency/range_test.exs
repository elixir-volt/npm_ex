defmodule NPM.Dependency.RangeTest do
  use ExUnit.Case, async: true

  @deps %{
    "lodash" => "^4.17.21",
    "react" => "~18.2.0",
    "express" => "4.18.2",
    "debug" => "*",
    "custom" => "git+https://github.com/user/repo.git",
    "local" => "file:../local-pkg",
    "alias" => "npm:other-pkg@^1.0",
    "ws" => "workspace:*"
  }

  describe "classify" do
    test "caret range" do
      assert :caret = NPM.Dependency.Range.classify("^4.17.21")
    end

    test "tilde range" do
      assert :tilde = NPM.Dependency.Range.classify("~18.2.0")
    end

    test "exact version" do
      assert :exact = NPM.Dependency.Range.classify("4.18.2")
    end

    test "star" do
      assert :star = NPM.Dependency.Range.classify("*")
    end

    test "latest" do
      assert :latest = NPM.Dependency.Range.classify("latest")
    end

    test "git URL" do
      assert :url = NPM.Dependency.Range.classify("git+https://github.com/user/repo.git")
    end

    test "file reference" do
      assert :file = NPM.Dependency.Range.classify("file:../local")
    end

    test "workspace protocol" do
      assert :workspace = NPM.Dependency.Range.classify("workspace:*")
    end

    test "npm alias" do
      assert :alias = NPM.Dependency.Range.classify("npm:other@^1.0")
    end

    test "or range" do
      assert :or_range = NPM.Dependency.Range.classify("^1.0 || ^2.0")
    end

    test "hyphen range" do
      assert :hyphen = NPM.Dependency.Range.classify("1.0.0 - 2.0.0")
    end
  end

  describe "analyze" do
    test "groups by range type" do
      result = NPM.Dependency.Range.analyze(@deps)
      assert "lodash" in result[:caret]
      assert "react" in result[:tilde]
      assert "express" in result[:exact]
    end
  end

  describe "summary" do
    test "computes breakdown" do
      sum = NPM.Dependency.Range.summary(@deps)
      assert sum.total == 8
      assert sum.pinned_count == 1
      assert sum.has_urls
      assert sum.has_files
    end

    test "empty deps" do
      sum = NPM.Dependency.Range.summary(%{})
      assert sum.total == 0
      assert sum.pinned_pct == 0.0
    end
  end

  describe "non_registry" do
    test "finds url and file deps" do
      result = NPM.Dependency.Range.non_registry(@deps)
      names = Enum.map(result, &elem(&1, 0))
      assert "custom" in names
      assert "local" in names
      refute "lodash" in names
    end

    test "empty for all registry deps" do
      assert [] = NPM.Dependency.Range.non_registry(%{"lodash" => "^4.17.21"})
    end
  end
end
