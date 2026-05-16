defmodule NPM.DiagnosticsCoreTest do
  use ExUnit.Case, async: true

  describe "run/1" do
    @tag :tmp_dir
    test "reports missing project files", %{tmp_dir: dir} do
      issues = NPM.Diagnostics.run(dir)

      assert Enum.any?(issues, &match?(%{level: :error, check: "package.json"}, &1))
      assert Enum.any?(issues, &match?(%{level: :warning, check: "lockfile"}, &1))
      assert Enum.any?(issues, &match?(%{level: :warning, check: "node_modules"}, &1))
    end

    @tag :tmp_dir
    test "passes when project files exist", %{tmp_dir: dir} do
      File.write!(Path.join(dir, "package.json"), ~s({"name":"app"}))
      File.write!(Path.join(dir, "npm.lock"), "{}")
      File.mkdir_p!(Path.join(dir, "node_modules"))

      assert NPM.Diagnostics.run(dir) == []
    end
  end

  describe "format/1 and counts/1" do
    test "formats and counts issues" do
      issues = [
        %{level: :error, check: "package.json", message: "package.json not found"},
        %{level: :warning, check: "lockfile", message: "No lockfile found"}
      ]

      assert NPM.Diagnostics.format([]) == "All checks passed."
      assert NPM.Diagnostics.format(issues) =~ "✗ [package.json] package.json not found"
      assert NPM.Diagnostics.counts(issues) == %{errors: 1, warnings: 1, total: 2}
    end
  end
end
