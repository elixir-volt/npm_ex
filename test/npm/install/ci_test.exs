defmodule NPM.Install.CITest do
  use ExUnit.Case, async: true

  alias NPM.Install.CI

  describe "validate" do
    @tag :tmp_dir
    test "ok when lockfile matches package.json", %{tmp_dir: dir} do
      File.write!(Path.join(dir, "package.json"), ~s({"dependencies":{"lodash":"^4.0.0"}}))

      lockfile = %{
        "lodash" => %{version: "4.17.21", integrity: "", tarball: "", dependencies: %{}}
      }

      NPM.Lockfile.write(lockfile, Path.join(dir, "npm.lock"))
      assert :ok = CI.validate(dir)
    end

    @tag :tmp_dir
    test "error when dep missing from lockfile", %{tmp_dir: dir} do
      File.write!(Path.join(dir, "package.json"), ~s({"dependencies":{"react":"^18.0.0"}}))
      NPM.Lockfile.write(%{}, Path.join(dir, "npm.lock"))

      assert {:error, errors} = CI.validate(dir)
      assert Enum.any?(errors, &match?({:missing_dep, "react"}, &1))
    end

    @tag :tmp_dir
    test "error when package.json missing", %{tmp_dir: dir} do
      assert {:error, [:package_json_missing]} = CI.validate(dir)
    end

    @tag :tmp_dir
    test "error when lockfile missing", %{tmp_dir: dir} do
      File.write!(Path.join(dir, "package.json"), ~s({"name":"test"}))
      assert {:error, [:lockfile_missing]} = CI.validate(dir)
    end
  end

  describe "preflight" do
    @tag :tmp_dir
    test "ok when both files exist", %{tmp_dir: dir} do
      File.write!(Path.join(dir, "package.json"), "{}")
      File.write!(Path.join(dir, "npm.lock"), "{}")
      assert :ok = CI.preflight(dir)
    end

    @tag :tmp_dir
    test "error when package.json missing", %{tmp_dir: dir} do
      File.write!(Path.join(dir, "npm.lock"), "{}")
      assert {:error, issues} = CI.preflight(dir)
      assert Enum.any?(issues, &String.contains?(&1, "package.json"))
    end

    @tag :tmp_dir
    test "error when lockfile missing", %{tmp_dir: dir} do
      File.write!(Path.join(dir, "package.json"), "{}")
      assert {:error, issues} = CI.preflight(dir)
      assert Enum.any?(issues, &String.contains?(&1, "npm.lock"))
    end
  end

  describe "needs_clean?" do
    @tag :tmp_dir
    test "true when node_modules exists", %{tmp_dir: dir} do
      File.mkdir_p!(Path.join(dir, "node_modules"))
      assert CI.needs_clean?(dir)
    end

    @tag :tmp_dir
    test "false when node_modules missing", %{tmp_dir: dir} do
      refute CI.needs_clean?(dir)
    end
  end

  describe "format_errors" do
    test "formats all error types" do
      errors = [:lockfile_missing, {:missing_dep, "react"}, {:extra_dep, "old-pkg"}]
      formatted = CI.format_errors(errors)
      assert formatted =~ "npm.lock is missing"
      assert formatted =~ "react"
      assert formatted =~ "old-pkg"
    end

    test "formats single error" do
      assert "npm.lock is missing" = CI.format_errors([:lockfile_missing])
    end

    test "formats package.json missing" do
      assert "package.json is missing" = CI.format_errors([:package_json_missing])
    end
  end

  describe "validate with devDependencies" do
    @tag :tmp_dir
    test "validates devDependencies too", %{tmp_dir: dir} do
      File.write!(Path.join(dir, "package.json"), ~s({"devDependencies":{"jest":"^29.0.0"}}))
      NPM.Lockfile.write(%{}, Path.join(dir, "npm.lock"))

      assert {:error, errors} = CI.validate(dir)
      assert Enum.any?(errors, &match?({:missing_dep, "jest"}, &1))
    end

    @tag :tmp_dir
    test "ok when devDeps in lockfile", %{tmp_dir: dir} do
      File.write!(Path.join(dir, "package.json"), ~s({"devDependencies":{"jest":"^29.0.0"}}))

      lockfile = %{
        "jest" => %{version: "29.7.0", integrity: "", tarball: "", dependencies: %{}}
      }

      NPM.Lockfile.write(lockfile, Path.join(dir, "npm.lock"))
      assert :ok = CI.validate(dir)
    end
  end

  describe "preflight both missing" do
    @tag :tmp_dir
    test "reports both issues", %{tmp_dir: dir} do
      assert {:error, issues} = CI.preflight(dir)
      assert length(issues) == 2
    end
  end
end
