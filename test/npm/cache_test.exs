defmodule NPM.CacheTest do
  use ExUnit.Case, async: false

  import NPM.TestHelpers

  describe "Cache" do
    test "cached? returns false for missing package" do
      refute NPM.Cache.cached?("nonexistent-pkg-xyz-#{System.unique_integer()}", "0.0.0")
    end

    test "package_dir returns consistent path" do
      path = NPM.Cache.package_dir("lodash", "4.17.21")
      assert String.ends_with?(path, "cache/lodash/4.17.21")
    end

    test "package_dir handles scoped packages" do
      path = NPM.Cache.package_dir("@types/node", "20.0.0")
      assert String.ends_with?(path, "cache/@types/node/20.0.0")
    end

    @tag :tmp_dir
    test "ensure caches and returns path", %{tmp_dir: dir} do
      cache_dir = Path.join(dir, "cache")
      System.put_env("NPM_EX_CACHE_DIR", cache_dir)

      pkg_tgz = create_test_tgz(%{"package/package.json" => ~s({"name":"test-pkg"})})

      {:ok, listen} = :gen_tcp.listen(0, [:binary, active: false, reuseaddr: true])
      {:ok, port} = :inet.port(listen)

      spawn(fn ->
        {:ok, conn} = :gen_tcp.accept(listen)
        {:ok, _data} = :gen_tcp.recv(conn, 0, 5000)

        response =
          "HTTP/1.1 200 OK\r\nContent-Length: #{byte_size(pkg_tgz)}\r\n\r\n" <> pkg_tgz

        :gen_tcp.send(conn, response)
        :gen_tcp.close(conn)
      end)

      url = "http://127.0.0.1:#{port}/test.tgz"
      System.put_env("NPM_EX_ALLOWED_REGISTRIES", "http://127.0.0.1:#{port}")
      assert {:ok, path} = NPM.Cache.ensure("test-pkg", "1.0.0", url, "")
      assert File.exists?(Path.join(path, "package.json"))

      :gen_tcp.close(listen)
      assert {:ok, ^path} = NPM.Cache.ensure("test-pkg", "1.0.0", url, "")

      System.delete_env("NPM_EX_CACHE_DIR")
      System.delete_env("NPM_EX_ALLOWED_REGISTRIES")
    end
  end

  describe "Cache edge cases" do
    test "package_dir uses correct separator" do
      path = NPM.Cache.package_dir("test-pkg", "1.0.0")
      assert path =~ "cache/test-pkg/1.0.0"
    end

    test "cached? returns false for nonexistent version" do
      refute NPM.Cache.cached?("lodash", "0.0.0-nonexistent")
    end

    @tag :tmp_dir
    test "dir respects NPM_EX_CACHE_DIR env var", %{tmp_dir: dir} do
      System.put_env("NPM_EX_CACHE_DIR", dir)
      assert NPM.Cache.dir() == dir
      System.delete_env("NPM_EX_CACHE_DIR")
    end

    test "dir defaults to home directory" do
      original = System.get_env("NPM_EX_CACHE_DIR")
      System.delete_env("NPM_EX_CACHE_DIR")

      cache_dir = NPM.Cache.dir()
      assert cache_dir =~ ".npm_ex"
      assert String.starts_with?(cache_dir, System.user_home!())

      if original, do: System.put_env("NPM_EX_CACHE_DIR", original)
    end
  end

  describe "Cache full flow with multiple packages" do
    @tag :tmp_dir
    test "caches multiple packages independently", %{tmp_dir: dir} do
      cache_dir = Path.join(dir, "cache")

      setup_cached_package(cache_dir, "alpha", "1.0.0", %{
        "package.json" => ~s({"name":"alpha"})
      })

      setup_cached_package(cache_dir, "beta", "2.0.0", %{
        "package.json" => ~s({"name":"beta"})
      })

      alpha_pkg = Path.join([cache_dir, "cache", "alpha", "1.0.0", "package.json"])
      beta_pkg = Path.join([cache_dir, "cache", "beta", "2.0.0", "package.json"])
      assert File.exists?(alpha_pkg)
      assert File.exists?(beta_pkg)
      refute File.exists?(Path.join([cache_dir, "cache", "alpha", "2.0.0", "package.json"]))
      refute File.exists?(Path.join([cache_dir, "cache", "gamma", "1.0.0", "package.json"]))

      System.delete_env("NPM_EX_CACHE_DIR")
    end
  end

  describe "Cache.package_dir patterns" do
    test "handles simple name" do
      path = NPM.Cache.package_dir("lodash", "4.17.21")
      assert String.ends_with?(path, "cache/lodash/4.17.21")
    end

    test "handles hyphenated name" do
      path = NPM.Cache.package_dir("is-number", "7.0.0")
      assert String.ends_with?(path, "cache/is-number/7.0.0")
    end

    test "handles scoped package" do
      path = NPM.Cache.package_dir("@babel/core", "7.24.0")
      assert String.ends_with?(path, "cache/@babel/core/7.24.0")
    end

    test "handles deeply scoped package" do
      path = NPM.Cache.package_dir("@angular/compiler-cli", "18.0.0")
      assert String.ends_with?(path, "cache/@angular/compiler-cli/18.0.0")
    end
  end

  describe "Cache.ensure skip download" do
    @tag :tmp_dir
    test "returns immediately for cached package", %{tmp_dir: dir} do
      cache_dir = Path.join(dir, "cache")
      System.put_env("NPM_EX_CACHE_DIR", cache_dir)

      setup_cached_package(cache_dir, "cached-pkg", "1.0.0", %{
        "package.json" => ~s({"name":"cached-pkg"})
      })

      {:ok, path} = NPM.Cache.ensure("cached-pkg", "1.0.0", "http://unused.example.com", "")
      assert String.ends_with?(path, "cached-pkg/1.0.0")

      System.delete_env("NPM_EX_CACHE_DIR")
    end
  end

  describe "Cache: cached? for non-cached package" do
    test "returns false for uncached package" do
      refute NPM.Cache.cached?("definitely-not-cached-#{:rand.uniform(999_999)}", "999.999.999")
    end
  end

  describe "Cache: dir defaults to ~/.npm_ex/cache" do
    test "default cache dir when env not set" do
      old = System.get_env("NPM_EX_CACHE_DIR")
      System.delete_env("NPM_EX_CACHE_DIR")

      dir = NPM.Cache.dir()
      assert String.contains?(dir, "npm_ex")

      if old, do: System.put_env("NPM_EX_CACHE_DIR", old)
    end
  end

  describe "Cache: package_dir structure" do
    test "package_dir path includes package name" do
      dir = NPM.Cache.package_dir("express", "4.21.2")
      assert String.contains?(dir, "express")
      assert String.contains?(dir, "4.21.2")
    end
  end

  describe "Cache: directory structure" do
    test "package_dir includes name and version" do
      dir = NPM.Cache.package_dir("lodash", "4.17.21")
      assert String.contains?(dir, "lodash")
      assert String.contains?(dir, "4.17.21")
    end

    test "package_dir for scoped packages" do
      dir = NPM.Cache.package_dir("@babel/core", "7.0.0")
      assert String.contains?(dir, "7.0.0")
    end

    test "cache dir is configurable via env" do
      old = System.get_env("NPM_EX_CACHE_DIR")
      System.put_env("NPM_EX_CACHE_DIR", "/tmp/custom_cache")

      dir = NPM.Cache.dir()
      assert dir == "/tmp/custom_cache"

      if old,
        do: System.put_env("NPM_EX_CACHE_DIR", old),
        else: System.delete_env("NPM_EX_CACHE_DIR")
    end
  end

  describe "Cache: ensure downloads and caches" do
    @tag :tmp_dir
    test "cached? returns true after setup", %{tmp_dir: dir} do
      cache_dir = Path.join(dir, "cache")
      System.put_env("NPM_EX_CACHE_DIR", cache_dir)

      setup_cached_package(cache_dir, "my-pkg", "1.0.0", %{
        "package.json" => ~s({"name":"my-pkg"})
      })

      assert NPM.Cache.cached?("my-pkg", "1.0.0")
      refute NPM.Cache.cached?("my-pkg", "2.0.0")

      System.delete_env("NPM_EX_CACHE_DIR")
    end

    @tag :tmp_dir
    test "package_dir returns correct path", %{tmp_dir: dir} do
      cache_dir = Path.join(dir, "cache")
      System.put_env("NPM_EX_CACHE_DIR", cache_dir)

      path = NPM.Cache.package_dir("my-pkg", "1.0.0")
      assert String.contains?(path, "my-pkg")
      assert String.ends_with?(path, "1.0.0")

      System.delete_env("NPM_EX_CACHE_DIR")
    end
  end

  describe "Cache: path structure matches npm convention" do
    test "package_dir uses name/version structure" do
      path = NPM.Cache.package_dir("lodash", "4.17.21")
      assert String.ends_with?(path, "lodash/4.17.21")
    end

    test "scoped package_dir uses scoped path" do
      path = NPM.Cache.package_dir("@types/node", "20.0.0")
      assert String.contains?(path, "@types/node")
      assert String.ends_with?(path, "20.0.0")
    end

    test "cached? returns false for non-cached package" do
      refute NPM.Cache.cached?("definitely-not-cached-pkg", "99.99.99")
    end
  end
end
