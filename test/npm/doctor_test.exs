defmodule NPM.DoctorTest do
  use ExUnit.Case, async: true

  describe "diagnose" do
    @tag :tmp_dir
    test "healthy project passes all checks", %{tmp_dir: dir} do
      File.write!(Path.join(dir, "package.json"), ~s({"name":"test","dependencies":{}}))
      File.write!(Path.join(dir, "npm.lock"), ~s({"lockfileVersion":1,"packages":{}}))
      File.mkdir_p!(Path.join(dir, "node_modules"))
      File.write!(Path.join(dir, ".gitignore"), "node_modules\n")

      results = NPM.Doctor.diagnose(dir)
      assert Enum.all?(results, &(&1.status == :ok))
    end

    @tag :tmp_dir
    test "missing package.json is an error", %{tmp_dir: dir} do
      results = NPM.Doctor.diagnose(dir)
      pkg_check = Enum.find(results, &(&1.name == "package.json"))
      assert pkg_check.status == :error
    end

    @tag :tmp_dir
    test "missing lockfile is a warning", %{tmp_dir: dir} do
      File.write!(Path.join(dir, "package.json"), ~s({"name":"test"}))
      results = NPM.Doctor.diagnose(dir)
      lock_check = Enum.find(results, &(&1.name == "lockfile"))
      assert lock_check.status == :warn
    end

    @tag :tmp_dir
    test "missing node_modules is a warning", %{tmp_dir: dir} do
      File.write!(Path.join(dir, "package.json"), ~s({"name":"test"}))
      results = NPM.Doctor.diagnose(dir)
      nm_check = Enum.find(results, &(&1.name == "node_modules"))
      assert nm_check.status == :warn
    end

    @tag :tmp_dir
    test "missing gitignore is a warning", %{tmp_dir: dir} do
      File.write!(Path.join(dir, "package.json"), ~s({"name":"test"}))
      results = NPM.Doctor.diagnose(dir)
      gi_check = Enum.find(results, &(&1.name == "gitignore"))
      assert gi_check.status == :warn
    end
  end

  describe "healthy?" do
    @tag :tmp_dir
    test "true for healthy project", %{tmp_dir: dir} do
      File.write!(Path.join(dir, "package.json"), ~s({"name":"test"}))
      File.write!(Path.join(dir, "npm.lock"), "{}")
      File.mkdir_p!(Path.join(dir, "node_modules"))
      File.write!(Path.join(dir, ".gitignore"), "node_modules")

      assert NPM.Doctor.healthy?(dir)
    end

    @tag :tmp_dir
    test "false when package.json missing", %{tmp_dir: dir} do
      refute NPM.Doctor.healthy?(dir)
    end
  end

  describe "summary" do
    test "counts by status" do
      results = [
        %{name: "a", status: :ok, message: "good"},
        %{name: "b", status: :ok, message: "good"},
        %{name: "c", status: :warn, message: "hmm"},
        %{name: "d", status: :error, message: "bad"}
      ]

      s = NPM.Doctor.summary(results)
      assert s.ok == 2
      assert s.warn == 1
      assert s.error == 1
    end
  end

  describe "format_results" do
    test "formats with status symbols" do
      results = [
        %{name: "pkg", status: :ok, message: "Found"},
        %{name: "lock", status: :warn, message: "Missing"},
        %{name: "nm", status: :error, message: "Broken"}
      ]

      formatted = NPM.Doctor.format_results(results)
      assert formatted =~ "✓"
      assert formatted =~ "⚠"
      assert formatted =~ "✗"
    end
  end
end
