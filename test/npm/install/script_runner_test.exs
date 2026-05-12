defmodule NPM.Install.ScriptRunnerTest do
  use ExUnit.Case, async: true

  @pkg %{
    "scripts" => %{
      "build" => "tsc",
      "test" => "jest",
      "lint" => "eslint .",
      "dev" => "next dev",
      "preinstall" => "echo pre",
      "postinstall" => "echo post"
    }
  }

  describe "extract" do
    test "extracts scripts" do
      scripts = NPM.Install.ScriptRunner.extract(@pkg)
      assert scripts["build"] == "tsc"
    end

    test "empty for no scripts" do
      assert %{} = NPM.Install.ScriptRunner.extract(%{})
    end
  end

  describe "lifecycle" do
    test "returns only lifecycle scripts" do
      lc = NPM.Install.ScriptRunner.lifecycle(@pkg)
      assert Map.has_key?(lc, "preinstall")
      assert Map.has_key?(lc, "postinstall")
      refute Map.has_key?(lc, "build")
    end
  end

  describe "custom" do
    test "returns non-lifecycle scripts" do
      c = NPM.Install.ScriptRunner.custom(@pkg)
      assert Map.has_key?(c, "build")
      refute Map.has_key?(c, "preinstall")
    end
  end

  describe "has_script?" do
    test "true for existing script" do
      assert NPM.Install.ScriptRunner.has_script?(@pkg, "build")
    end

    test "false for missing script" do
      refute NPM.Install.ScriptRunner.has_script?(@pkg, "deploy")
    end
  end

  describe "detect_patterns" do
    test "detects common patterns" do
      patterns = NPM.Install.ScriptRunner.detect_patterns(@pkg)
      assert :has_test in patterns
      assert :has_build in patterns
      assert :has_lint in patterns
      assert :has_dev in patterns
    end

    test "detects typecheck via tsc" do
      data = %{"scripts" => %{"build" => "tsc --build"}}
      patterns = NPM.Install.ScriptRunner.detect_patterns(data)
      assert :has_typecheck in patterns
    end

    test "no test for default message" do
      data = %{"scripts" => %{"test" => ~s(echo "Error: no test specified" && exit 1)}}
      patterns = NPM.Install.ScriptRunner.detect_patterns(data)
      refute :has_test in patterns
    end
  end

  describe "names" do
    test "returns sorted names" do
      names = NPM.Install.ScriptRunner.names(@pkg)
      assert hd(names) == "build"
    end
  end

  describe "count" do
    test "counts scripts" do
      assert 6 = NPM.Install.ScriptRunner.count(@pkg)
    end

    test "zero for empty" do
      assert 0 = NPM.Install.ScriptRunner.count(%{})
    end
  end

  describe "missing_common" do
    test "lists missing common scripts" do
      missing = NPM.Install.ScriptRunner.missing_common(@pkg)
      assert "start" in missing
      assert "clean" in missing
      refute "test" in missing
      refute "build" in missing
    end
  end
end
