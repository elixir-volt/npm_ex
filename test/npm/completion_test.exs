defmodule NPM.CompletionTest do
  use ExUnit.Case, async: true

  describe "commands" do
    test "returns list of available commands" do
      cmds = NPM.Completion.commands()
      assert is_list(cmds)
      assert "install" in cmds
      assert "audit" in cmds
      assert "verify" in cmds
    end
  end

  describe "complete" do
    test "completes partial command" do
      results = NPM.Completion.complete("in")
      assert "install" in results
      assert "init" in results
      refute "audit" in results
    end

    test "empty prefix returns all commands" do
      results = NPM.Completion.complete("")
      assert results == NPM.Completion.commands() |> Enum.sort()
    end

    test "no match returns empty" do
      assert [] = NPM.Completion.complete("zzz")
    end

    test "exact match" do
      results = NPM.Completion.complete("audit")
      assert results == ["audit"]
    end
  end

  describe "complete_packages" do
    test "completes package names from lockfile" do
      lockfile = %{
        "lodash" => %{version: "4.17.21"},
        "lodash.clonedeep" => %{version: "4.5.0"},
        "react" => %{version: "18.2.0"}
      }

      results = NPM.Completion.complete_packages("lod", lockfile)
      assert "lodash" in results
      assert "lodash.clonedeep" in results
      refute "react" in results
    end

    test "empty prefix returns all packages" do
      lockfile = %{"a" => %{}, "b" => %{}}
      results = NPM.Completion.complete_packages("", lockfile)
      assert length(results) == 2
    end
  end

  describe "complete_scripts" do
    test "completes script names" do
      scripts = %{"build" => "tsc", "build:watch" => "tsc -w", "test" => "jest"}
      results = NPM.Completion.complete_scripts("build", scripts)
      assert "build" in results
      assert "build:watch" in results
      refute "test" in results
    end
  end

  describe "bash_completions" do
    test "generates valid bash script" do
      script = NPM.Completion.bash_completions()
      assert script =~ "complete"
      assert script =~ "COMPREPLY"
      assert script =~ "install"
    end
  end
end
