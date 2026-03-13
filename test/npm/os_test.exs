defmodule NPM.OsTest do
  use ExUnit.Case, async: true

  describe "current_os" do
    test "returns a known os string" do
      os = NPM.Os.current_os()
      assert os in ["darwin", "linux", "freebsd", "win32"] or is_binary(os)
    end
  end

  describe "current_cpu" do
    test "returns a known arch string" do
      cpu = NPM.Os.current_cpu()
      assert cpu in ["x64", "arm64", "arm", "ia32"] or is_binary(cpu)
    end
  end

  describe "os_compatible?" do
    test "compatible when os matches" do
      os = NPM.Os.current_os()
      assert NPM.Os.os_compatible?(%{"os" => [os]})
    end

    test "incompatible when os excluded" do
      os = NPM.Os.current_os()
      refute NPM.Os.os_compatible?(%{"os" => ["!#{os}"]})
    end

    test "incompatible when not in allow list" do
      refute NPM.Os.os_compatible?(%{"os" => ["nonexistent-os"]})
    end

    test "compatible when no os field" do
      assert NPM.Os.os_compatible?(%{"name" => "pkg"})
    end

    test "negation allows unlisted platforms" do
      assert NPM.Os.os_compatible?(%{"os" => ["!nonexistent-os"]})
    end
  end

  describe "cpu_compatible?" do
    test "compatible when cpu matches" do
      cpu = NPM.Os.current_cpu()
      assert NPM.Os.cpu_compatible?(%{"cpu" => [cpu]})
    end

    test "incompatible when cpu excluded" do
      cpu = NPM.Os.current_cpu()
      refute NPM.Os.cpu_compatible?(%{"cpu" => ["!#{cpu}"]})
    end

    test "compatible when no cpu field" do
      assert NPM.Os.cpu_compatible?(%{})
    end
  end

  describe "compatible?" do
    test "true when both match" do
      os = NPM.Os.current_os()
      cpu = NPM.Os.current_cpu()
      assert NPM.Os.compatible?(%{"os" => [os], "cpu" => [cpu]})
    end

    test "false when os incompatible" do
      cpu = NPM.Os.current_cpu()
      refute NPM.Os.compatible?(%{"os" => ["nonexistent"], "cpu" => [cpu]})
    end

    test "true when no restrictions" do
      assert NPM.Os.compatible?(%{})
    end
  end

  describe "check_all" do
    @tag :tmp_dir
    test "finds incompatible packages", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      pkg = Path.join(nm, "win-only")
      File.mkdir_p!(pkg)
      File.write!(Path.join(pkg, "package.json"), ~s({"name":"win-only","os":["win32"]}))

      if NPM.Os.current_os() != "win32" do
        issues = NPM.Os.check_all(nm)
        assert Enum.any?(issues, &(&1.name == "win-only"))
      end
    end

    @tag :tmp_dir
    test "no issues for compatible packages", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      pkg = Path.join(nm, "universal")
      File.mkdir_p!(pkg)
      File.write!(Path.join(pkg, "package.json"), ~s({"name":"universal"}))

      assert [] = NPM.Os.check_all(nm)
    end

    test "empty for nonexistent dir" do
      assert [] = NPM.Os.check_all("/tmp/nonexistent_#{System.unique_integer([:positive])}")
    end
  end
end
