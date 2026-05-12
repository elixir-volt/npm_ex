defmodule NPM.Install.LinkerOptionalRuntimeTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog
  import NPM.TestHelpers

  @tag :tmp_dir
  test "populate_cache tolerates missing optional package tarballs when package is optional", %{
    tmp_dir: dir
  } do
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

    setup_cached_package(cache_dir, "oxlint", "1.56.0", %{
      "package.json" => ~s({"name":"oxlint","version":"1.56.0"})
    })

    original = System.get_env("NPM_EX_CACHE_DIR")
    original_allowed = System.get_env("NPM_EX_ALLOWED_REGISTRIES")
    System.put_env("NPM_EX_CACHE_DIR", cache_dir)
    System.put_env("NPM_EX_ALLOWED_REGISTRIES", "https://example.com,https://registry.npmjs.org")

    try do
      log =
        capture_log(fn ->
          assert :ok = NPM.Install.Linker.link(lockfile, Path.join(dir, "node_modules"), :copy)
        end)

      assert File.exists?(Path.join(dir, "node_modules/oxlint"))
      refute File.exists?(Path.join(dir, "node_modules/@oxlint/binding-darwin-arm64"))
      assert log == ""
    after
      if original do
        System.put_env("NPM_EX_CACHE_DIR", original)
      else
        System.delete_env("NPM_EX_CACHE_DIR")
      end

      if original_allowed do
        System.put_env("NPM_EX_ALLOWED_REGISTRIES", original_allowed)
      else
        System.delete_env("NPM_EX_ALLOWED_REGISTRIES")
      end
    end
  end
end
