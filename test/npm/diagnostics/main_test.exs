defmodule NPM.DiagnosticsTest do
  use ExUnit.Case, async: true

  describe "run" do
    @tag :tmp_dir
    test "reports missing package.json", %{tmp_dir: dir} do
      issues = NPM.Diagnostics.run(dir)
      assert Enum.any?(issues, &(&1.check == "package.json"))
    end

    @tag :tmp_dir
    test "reports missing lockfile", %{tmp_dir: dir} do
      File.write!(Path.join(dir, "package.json"), "{}")
      issues = NPM.Diagnostics.run(dir)
      assert Enum.any?(issues, &(&1.check == "lockfile"))
    end

    @tag :tmp_dir
    test "reports missing node_modules", %{tmp_dir: dir} do
      File.write!(Path.join(dir, "package.json"), "{}")
      issues = NPM.Diagnostics.run(dir)
      assert Enum.any?(issues, &(&1.check == "node_modules"))
    end

    @tag :tmp_dir
    test "clean project with all files", %{tmp_dir: dir} do
      File.write!(Path.join(dir, "package.json"), "{}")
      File.write!(Path.join(dir, "npm.lock"), "")
      File.mkdir_p!(Path.join(dir, "node_modules"))
      issues = NPM.Diagnostics.run(dir)
      refute Enum.any?(issues, &(&1.level == :error))
    end

    @tag :tmp_dir
    test "warns about auth in npmrc", %{tmp_dir: dir} do
      File.write!(Path.join(dir, "package.json"), "{}")
      File.write!(Path.join(dir, "npm.lock"), "")
      File.mkdir_p!(Path.join(dir, "node_modules"))
      File.write!(Path.join(dir, ".npmrc"), "//registry.npmjs.org/:_authToken=secret\n")
      issues = NPM.Diagnostics.run(dir)
      assert Enum.any?(issues, &(&1.check == "npmrc"))
    end
  end

  describe "format" do
    test "all passed" do
      assert "All checks passed." = NPM.Diagnostics.format([])
    end

    test "formats issues" do
      issues = [
        %{level: :error, check: "package.json", message: "not found"},
        %{level: :warning, check: "lockfile", message: "missing"}
      ]

      formatted = NPM.Diagnostics.format(issues)
      assert formatted =~ "✗"
      assert formatted =~ "!"
    end
  end

  describe "counts" do
    test "counts by level" do
      issues = [
        %{level: :error, check: "a", message: "x"},
        %{level: :warning, check: "b", message: "y"},
        %{level: :warning, check: "c", message: "z"}
      ]

      counts = NPM.Diagnostics.counts(issues)
      assert counts.errors == 1
      assert counts.warnings == 2
      assert counts.total == 3
    end
  end
end
