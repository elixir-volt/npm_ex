defmodule NPM.Install.LinkerOptionalRuntimeTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog
  import NPM.TestHelpers

  alias NPM.Install.Linker

  @tag :tmp_dir
  test "populate_cache tolerates missing optional package tarballs when package is optional", %{
    tmp_dir: dir
  } do
    {:ok, listen} = :gen_tcp.listen(0, [:binary, active: false, reuseaddr: true])
    {:ok, port} = :inet.port(listen)

    spawn(fn ->
      {:ok, conn} = :gen_tcp.accept(listen)
      {:ok, _data} = :gen_tcp.recv(conn, 0, 5000)
      :gen_tcp.send(conn, "HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\n\r\n")
      :gen_tcp.close(conn)
    end)

    missing_url = "http://127.0.0.1:#{port}/missing.tgz"

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
        tarball: missing_url,
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

    System.put_env(
      "NPM_EX_ALLOWED_REGISTRIES",
      "https://example.com,https://registry.npmjs.org,http://127.0.0.1:#{port}"
    )

    NPM.PackumentCache.put("@oxlint/binding-darwin-arm64", %{
      name: "@oxlint/binding-darwin-arm64",
      versions: %{
        "1.56.0" => %{
          os: ["darwin"],
          cpu: ["arm64"],
          dist: %{tarball: missing_url, integrity: "sha512-optional"}
        }
      }
    })

    try do
      log =
        capture_log(fn ->
          assert :ok = Linker.link(lockfile, Path.join(dir, "node_modules"), :copy)
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

      :gen_tcp.close(listen)
    end
  end
end
