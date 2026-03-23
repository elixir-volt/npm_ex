defmodule NPM.LinkerOptionalRuntimeTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  @tag :tmp_dir
  test "populate_cache tolerates missing optional package tarballs when package is optional", %{tmp_dir: dir} do
    lockfile = %{
      "oxlint" => %{
        version: "1.56.0",
        integrity: "sha512-root",
        tarball: "https://example.com/oxlint.tgz",
        dependencies: %{},
        optional_dependencies: %{"@oxlint/binding-darwin-arm64" => "1.56.0"}
      },
      "@oxlint/binding-darwin-arm64" => %{
        version: "1.56.0",
        integrity: "sha512-optional",
        tarball: "https://example.com/missing.tgz",
        dependencies: %{},
        optional_dependencies: %{}
      }
    }

    cache_dir = Path.join(dir, "cache")
    File.mkdir_p!(cache_dir)

    original = Application.get_env(:npm, :cache_dir)
    Application.put_env(:npm, :cache_dir, cache_dir)

    try do
      log =
        capture_log(fn ->
          assert :ok = NPM.Linker.link(lockfile, Path.join(dir, "node_modules"), :copy)
        end)

      assert File.exists?(Path.join(dir, "node_modules/oxlint"))
      refute File.exists?(Path.join(dir, "node_modules/@oxlint/binding-darwin-arm64"))
      assert log == ""
    after
      if original do
        Application.put_env(:npm, :cache_dir, original)
      else
        Application.delete_env(:npm, :cache_dir)
      end
    end
  end
end
