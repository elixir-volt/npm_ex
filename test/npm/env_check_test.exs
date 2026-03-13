defmodule NPM.EnvCheckTest do
  use ExUnit.Case, async: true

  describe "EnvCheck: summary structure" do
    test "summary includes current OS and CPU" do
      info = NPM.EnvCheck.summary()
      assert info.os in ["darwin", "linux", "freebsd", "win32"]
      assert info.cpu in ["x64", "arm64", "arm", "ia32"]
    end

    test "summary includes Elixir version" do
      info = NPM.EnvCheck.summary()
      assert String.contains?(info.elixir_version, ".")
    end
  end

  describe "EnvCheck: node_version format" do
    test "version starts with v when present" do
      case NPM.EnvCheck.node_version() do
        {:ok, version} -> assert String.starts_with?(version, "v")
        :not_found -> :ok
      end
    end
  end

  describe "EnvCheck: version_satisfies?" do
    test "check_engines with satisfied range" do
      case NPM.EnvCheck.node_version() do
        {:ok, "v" <> _version} ->
          result = NPM.EnvCheck.check_engines(%{"node" => ">= 0.0.1"})
          assert result == :ok

        :not_found ->
          :ok
      end
    end
  end

  describe "EnvCheck: engine checks" do
    test "check_engines with node requirement" do
      result = NPM.EnvCheck.check_engines(%{"node" => ">=14.0.0"})
      # Either :ok (if node is present and >= 14) or {:warn, _}
      assert result == :ok or match?({:warn, _}, result)
    end
  end

  describe "EnvCheck: environment detection" do
    test "summary returns all expected keys" do
      info = NPM.EnvCheck.summary()
      assert Map.has_key?(info, :elixir_version)
      assert Map.has_key?(info, :otp_version)
      assert Map.has_key?(info, :os)
      assert Map.has_key?(info, :cpu)
      assert Map.has_key?(info, :npm_ex_version)
    end

    test "check_engines returns :ok for empty engines" do
      assert :ok = NPM.EnvCheck.check_engines(%{})
    end

    test "check_engines warns for unknown engine" do
      assert {:warn, warnings} = NPM.EnvCheck.check_engines(%{"deno" => ">=1.0"})
      assert Enum.any?(warnings, &String.contains?(&1, "unknown engine"))
    end

    test "node_version returns {:ok, version} or :not_found" do
      result = NPM.EnvCheck.node_version()
      assert match?({:ok, "v" <> _}, result) or result == :not_found
    end
  end
end
