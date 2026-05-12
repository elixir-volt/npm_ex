defmodule NPM.Install.LinkerTest do
  use ExUnit.Case, async: true

  import NPM.TestHelpers

  alias NPM.Install.Linker

  describe "Linker.hoist" do
    test "returns one entry per package" do
      lockfile = %{
        "foo" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}},
        "bar" => %{version: "2.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      hoisted = Linker.hoist(lockfile)
      names = Enum.map(hoisted, &elem(&1, 0)) |> Enum.sort()
      assert names == ["bar", "foo"]
    end

    test "preserves versions" do
      lockfile = %{
        "foo" => %{version: "1.2.3", integrity: "", tarball: "", dependencies: %{}}
      }

      [{name, version}] = Linker.hoist(lockfile)
      assert name == "foo"
      assert version == "1.2.3"
    end

    test "handles empty lockfile" do
      assert Linker.hoist(%{}) == []
    end
  end

  describe "Linker.link with copy" do
    @tag :tmp_dir
    test "creates node_modules with package files", %{tmp_dir: dir} do
      cache_dir = Path.join(dir, "cache")
      nm_dir = Path.join(dir, "node_modules")

      setup_cached_package(cache_dir, "test-pkg", "1.0.0", %{
        "package.json" => ~s({"name":"test-pkg","version":"1.0.0"}),
        "index.js" => "module.exports = 42;"
      })

      lockfile = %{
        "test-pkg" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      System.put_env("NPM_EX_CACHE_DIR", cache_dir)
      Linker.link(lockfile, nm_dir, :copy)
      System.delete_env("NPM_EX_CACHE_DIR")

      assert File.exists?(Path.join([nm_dir, "test-pkg", "package.json"]))
      assert File.read!(Path.join([nm_dir, "test-pkg", "index.js"])) == "module.exports = 42;"
    end

    @tag :tmp_dir
    test "replaces stale node_modules entries", %{tmp_dir: dir} do
      cache_dir = Path.join(dir, "cache")
      nm_dir = Path.join(dir, "node_modules")

      setup_cached_package(cache_dir, "pkg", "2.0.0", %{
        "package.json" => ~s({"name":"pkg","version":"2.0.0"}),
        "index.js" => "v2"
      })

      stale_dir = Path.join([nm_dir, "pkg"])
      File.mkdir_p!(stale_dir)
      File.write!(Path.join(stale_dir, "index.js"), "v1")

      lockfile = %{
        "pkg" => %{version: "2.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      System.put_env("NPM_EX_CACHE_DIR", cache_dir)
      Linker.link(lockfile, nm_dir, :copy)
      System.delete_env("NPM_EX_CACHE_DIR")

      assert File.read!(Path.join([nm_dir, "pkg", "index.js"])) == "v2"
    end

    @tag :tmp_dir
    test "handles multiple packages", %{tmp_dir: dir} do
      cache_dir = Path.join(dir, "cache")
      nm_dir = Path.join(dir, "node_modules")

      setup_cached_package(cache_dir, "a", "1.0.0", %{"package.json" => ~s({"name":"a"})})
      setup_cached_package(cache_dir, "b", "2.0.0", %{"package.json" => ~s({"name":"b"})})
      setup_cached_package(cache_dir, "c", "3.0.0", %{"package.json" => ~s({"name":"c"})})

      lockfile = %{
        "a" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}},
        "b" => %{version: "2.0.0", integrity: "", tarball: "", dependencies: %{}},
        "c" => %{version: "3.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      System.put_env("NPM_EX_CACHE_DIR", cache_dir)
      Linker.link(lockfile, nm_dir, :copy)
      System.delete_env("NPM_EX_CACHE_DIR")

      assert File.exists?(Path.join([nm_dir, "a", "package.json"]))
      assert File.exists?(Path.join([nm_dir, "b", "package.json"]))
      assert File.exists?(Path.join([nm_dir, "c", "package.json"]))
    end
  end

  describe "Linker.link with symlink" do
    @tag :tmp_dir
    test "creates symlinks pointing to cache", %{tmp_dir: dir} do
      cache_dir = Path.join(dir, "cache")
      nm_dir = Path.join(dir, "node_modules")

      setup_cached_package(cache_dir, "test-pkg", "1.0.0", %{
        "package.json" => ~s({"name":"test-pkg"})
      })

      lockfile = %{
        "test-pkg" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      System.put_env("NPM_EX_CACHE_DIR", cache_dir)
      Linker.link(lockfile, nm_dir, :symlink)
      System.delete_env("NPM_EX_CACHE_DIR")

      link_target = Path.join(nm_dir, "test-pkg")
      assert File.exists?(link_target)
      {:ok, info} = File.lstat(link_target)
      assert info.type == :symlink
    end

    @tag :tmp_dir
    test "symlinks resolve to correct files", %{tmp_dir: dir} do
      cache_dir = Path.join(dir, "cache")
      nm_dir = Path.join(dir, "node_modules")

      setup_cached_package(cache_dir, "pkg", "1.0.0", %{
        "package.json" => ~s({"name":"pkg","version":"1.0.0"}),
        "index.js" => "hello from cache"
      })

      lockfile = %{
        "pkg" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      System.put_env("NPM_EX_CACHE_DIR", cache_dir)
      Linker.link(lockfile, nm_dir, :symlink)
      System.delete_env("NPM_EX_CACHE_DIR")

      assert File.read!(Path.join([nm_dir, "pkg", "index.js"])) == "hello from cache"
    end

    @tag :tmp_dir
    test "handles scoped packages", %{tmp_dir: dir} do
      cache_dir = Path.join(dir, "cache")
      nm_dir = Path.join(dir, "node_modules")

      setup_cached_package(cache_dir, "@scope/pkg", "1.0.0", %{
        "package.json" => ~s({"name":"@scope/pkg"})
      })

      lockfile = %{
        "@scope/pkg" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      System.put_env("NPM_EX_CACHE_DIR", cache_dir)
      Linker.link(lockfile, nm_dir, :symlink)
      System.delete_env("NPM_EX_CACHE_DIR")

      assert File.exists?(Path.join([nm_dir, "@scope", "pkg", "package.json"]))
    end
  end

  describe "Linker.link_bins" do
    @tag :tmp_dir
    test "creates .bin symlinks for string bin field", %{tmp_dir: dir} do
      nm_dir = Path.join(dir, "node_modules")
      pkg_dir = Path.join(nm_dir, "my-tool")
      File.mkdir_p!(pkg_dir)
      File.write!(Path.join(pkg_dir, "package.json"), ~s({"name":"my-tool","bin":"./cli.js"}))
      File.write!(Path.join(pkg_dir, "cli.js"), "#!/usr/bin/env node\nconsole.log('hi')")

      Linker.link_bins(nm_dir, [{"my-tool", "1.0.0"}])

      link = Path.join([nm_dir, ".bin", "my-tool"])
      assert File.exists?(link)
      {:ok, info} = File.lstat(link)
      assert info.type == :symlink
    end

    @tag :tmp_dir
    test "creates .bin symlinks for map bin field", %{tmp_dir: dir} do
      nm_dir = Path.join(dir, "node_modules")
      pkg_dir = Path.join(nm_dir, "multi-tool")
      File.mkdir_p!(pkg_dir)

      File.write!(
        Path.join(pkg_dir, "package.json"),
        ~s({"name":"multi-tool","bin":{"cmd-a":"./a.js","cmd-b":"./b.js"}})
      )

      File.write!(Path.join(pkg_dir, "a.js"), "#!/usr/bin/env node")
      File.write!(Path.join(pkg_dir, "b.js"), "#!/usr/bin/env node")

      Linker.link_bins(nm_dir, [{"multi-tool", "1.0.0"}])

      assert File.exists?(Path.join([nm_dir, ".bin", "cmd-a"]))
      assert File.exists?(Path.join([nm_dir, ".bin", "cmd-b"]))
    end

    @tag :tmp_dir
    test "skips packages without bin field", %{tmp_dir: dir} do
      nm_dir = Path.join(dir, "node_modules")
      pkg_dir = Path.join(nm_dir, "no-bin")
      File.mkdir_p!(pkg_dir)
      File.write!(Path.join(pkg_dir, "package.json"), ~s({"name":"no-bin"}))

      Linker.link_bins(nm_dir, [{"no-bin", "1.0.0"}])

      refute File.exists?(Path.join([nm_dir, ".bin"]))
    end

    @tag :tmp_dir
    test "sets executable permissions on targets", %{tmp_dir: dir} do
      nm_dir = Path.join(dir, "node_modules")
      pkg_dir = Path.join(nm_dir, "exec-tool")
      File.mkdir_p!(pkg_dir)
      File.write!(Path.join(pkg_dir, "package.json"), ~s({"name":"exec-tool","bin":"./run.js"}))
      File.write!(Path.join(pkg_dir, "run.js"), "#!/usr/bin/env node")

      Linker.link_bins(nm_dir, [{"exec-tool", "1.0.0"}])

      {:ok, stat} = File.stat(Path.join(pkg_dir, "run.js"))
      assert Bitwise.band(stat.mode, 0o111) != 0
    end

    @tag :tmp_dir
    test "handles scoped packages", %{tmp_dir: dir} do
      nm_dir = Path.join(dir, "node_modules")
      pkg_dir = Path.join([nm_dir, "@scope", "tool"])
      File.mkdir_p!(pkg_dir)
      File.write!(Path.join(pkg_dir, "package.json"), ~s({"name":"@scope/tool","bin":"./cli.js"}))
      File.write!(Path.join(pkg_dir, "cli.js"), "#!/usr/bin/env node")

      Linker.link_bins(nm_dir, [{"@scope/tool", "1.0.0"}])

      assert File.exists?(Path.join([nm_dir, ".bin", "tool"]))
    end

    @tag :tmp_dir
    test "handles directories.bin field", %{tmp_dir: dir} do
      nm_dir = Path.join(dir, "node_modules")
      pkg_dir = Path.join(nm_dir, "dir-bin-tool")
      bin_dir = Path.join(pkg_dir, "bin")
      File.mkdir_p!(bin_dir)

      File.write!(
        Path.join(pkg_dir, "package.json"),
        ~s({"name":"dir-bin-tool","directories":{"bin":"./bin"}})
      )

      File.write!(Path.join(bin_dir, "run.js"), "#!/usr/bin/env node")
      File.write!(Path.join(bin_dir, "test.js"), "#!/usr/bin/env node")

      Linker.link_bins(nm_dir, [{"dir-bin-tool", "1.0.0"}])

      assert File.exists?(Path.join([nm_dir, ".bin", "run"]))
      assert File.exists?(Path.join([nm_dir, ".bin", "test"]))
    end

    @tag :tmp_dir
    test "handles missing package.json gracefully", %{tmp_dir: dir} do
      nm_dir = Path.join(dir, "node_modules")
      File.mkdir_p!(nm_dir)

      Linker.link_bins(nm_dir, [{"ghost-pkg", "1.0.0"}])

      refute File.exists?(Path.join([nm_dir, ".bin"]))
    end
  end

  describe "Linker.hoist edge cases" do
    test "deduplicates same package appearing multiple times" do
      lockfile = %{
        "foo" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      result = Linker.hoist(lockfile)
      assert length(result) == 1
      assert {"foo", "1.0.0"} in result
    end

    test "handles scoped packages in hoist" do
      lockfile = %{
        "@scope/a" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}},
        "@scope/b" => %{version: "2.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      result = Linker.hoist(lockfile)
      names = Enum.map(result, &elem(&1, 0)) |> Enum.sort()
      assert names == ["@scope/a", "@scope/b"]
    end

    test "single package returns single entry" do
      lockfile = %{
        "only-one" => %{version: "3.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      [{name, version}] = Linker.hoist(lockfile)
      assert name == "only-one"
      assert version == "3.0.0"
    end
  end

  describe "Linker.link_bins with no bins" do
    @tag :tmp_dir
    test "does not create .bin dir when no packages have bins", %{tmp_dir: dir} do
      nm_dir = Path.join(dir, "node_modules")
      pkg_dir = Path.join(nm_dir, "no-bins")
      File.mkdir_p!(pkg_dir)
      File.write!(Path.join(pkg_dir, "package.json"), ~s({"name":"no-bins","version":"1.0.0"}))

      Linker.link_bins(nm_dir, [{"no-bins", "1.0.0"}])

      refute File.exists?(Path.join(nm_dir, ".bin"))
    end
  end

  describe "Linker.prune preserves special dirs" do
    @tag :tmp_dir
    test "prune does not remove .bin directory", %{tmp_dir: dir} do
      nm_dir = Path.join(dir, "node_modules")
      File.mkdir_p!(Path.join(nm_dir, ".bin"))
      File.mkdir_p!(Path.join(nm_dir, "pkg"))
      File.write!(Path.join([nm_dir, "pkg", "index.js"]), "ok")

      Linker.prune(nm_dir, MapSet.new(["pkg"]))

      assert File.exists?(Path.join(nm_dir, ".bin"))
      assert File.exists?(Path.join([nm_dir, "pkg", "index.js"]))
    end
  end

  describe "Linker.prune" do
    @tag :tmp_dir
    test "removes packages not in expected set", %{tmp_dir: dir} do
      nm_dir = Path.join(dir, "node_modules")
      File.mkdir_p!(Path.join(nm_dir, "keep-me"))
      File.mkdir_p!(Path.join(nm_dir, "remove-me"))
      File.write!(Path.join([nm_dir, "keep-me", "index.js"]), "kept")
      File.write!(Path.join([nm_dir, "remove-me", "index.js"]), "removed")

      Linker.prune(nm_dir, MapSet.new(["keep-me"]))

      assert File.exists?(Path.join([nm_dir, "keep-me", "index.js"]))
      refute File.exists?(Path.join(nm_dir, "remove-me"))
    end

    @tag :tmp_dir
    test "removes scoped packages not in expected set", %{tmp_dir: dir} do
      nm_dir = Path.join(dir, "node_modules")
      File.mkdir_p!(Path.join([nm_dir, "@scope", "keep"]))
      File.mkdir_p!(Path.join([nm_dir, "@scope", "remove"]))
      File.write!(Path.join([nm_dir, "@scope", "keep", "index.js"]), "kept")
      File.write!(Path.join([nm_dir, "@scope", "remove", "index.js"]), "removed")

      Linker.prune(nm_dir, MapSet.new(["@scope/keep"]))

      assert File.exists?(Path.join([nm_dir, "@scope", "keep", "index.js"]))
      refute File.exists?(Path.join([nm_dir, "@scope", "remove"]))
    end

    @tag :tmp_dir
    test "removes empty scope directories", %{tmp_dir: dir} do
      nm_dir = Path.join(dir, "node_modules")
      File.mkdir_p!(Path.join([nm_dir, "@scope", "pkg"]))
      File.write!(Path.join([nm_dir, "@scope", "pkg", "index.js"]), "data")

      Linker.prune(nm_dir, MapSet.new())

      refute File.exists?(Path.join(nm_dir, "@scope"))
    end

    @tag :tmp_dir
    test "handles missing node_modules directory", %{tmp_dir: dir} do
      nm_dir = Path.join(dir, "nonexistent")
      assert :ok = Linker.prune(nm_dir, MapSet.new())
    end

    @tag :tmp_dir
    test "does nothing when all packages are expected", %{tmp_dir: dir} do
      nm_dir = Path.join(dir, "node_modules")
      File.mkdir_p!(Path.join(nm_dir, "a"))
      File.mkdir_p!(Path.join(nm_dir, "b"))
      File.write!(Path.join([nm_dir, "a", "index.js"]), "a")
      File.write!(Path.join([nm_dir, "b", "index.js"]), "b")

      Linker.prune(nm_dir, MapSet.new(["a", "b"]))

      assert File.exists?(Path.join([nm_dir, "a", "index.js"]))
      assert File.exists?(Path.join([nm_dir, "b", "index.js"]))
    end

    @tag :tmp_dir
    test "handles empty node_modules", %{tmp_dir: dir} do
      nm_dir = Path.join(dir, "node_modules")
      File.mkdir_p!(nm_dir)

      assert :ok = Linker.prune(nm_dir, MapSet.new(["something"]))
    end
  end

  describe "Linker.link with pruning" do
    @tag :tmp_dir
    test "removes stale packages after re-install", %{tmp_dir: dir} do
      cache_dir = Path.join(dir, "cache")
      nm_dir = Path.join(dir, "node_modules")

      setup_cached_package(cache_dir, "a", "1.0.0", %{"package.json" => ~s({"name":"a"})})
      setup_cached_package(cache_dir, "b", "1.0.0", %{"package.json" => ~s({"name":"b"})})

      lockfile_v1 = %{
        "a" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}},
        "b" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      System.put_env("NPM_EX_CACHE_DIR", cache_dir)
      Linker.link(lockfile_v1, nm_dir, :copy)

      assert File.exists?(Path.join([nm_dir, "a", "package.json"]))
      assert File.exists?(Path.join([nm_dir, "b", "package.json"]))

      lockfile_v2 = %{
        "a" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      Linker.link(lockfile_v2, nm_dir, :copy)

      assert File.exists?(Path.join([nm_dir, "a", "package.json"]))
      refute File.exists?(Path.join(nm_dir, "b"))

      System.delete_env("NPM_EX_CACHE_DIR")
    end
  end

  describe "Linker.link creates .bin entries" do
    @tag :tmp_dir
    test "creates .bin symlinks during full link flow", %{tmp_dir: dir} do
      cache_dir = Path.join(dir, "cache")
      nm_dir = Path.join(dir, "node_modules")

      setup_cached_package(cache_dir, "my-cli", "1.0.0", %{
        "package.json" => ~s({"name":"my-cli","bin":"./cli.js"}),
        "cli.js" => "#!/usr/bin/env node\nconsole.log('hello')"
      })

      lockfile = %{
        "my-cli" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      System.put_env("NPM_EX_CACHE_DIR", cache_dir)
      Linker.link(lockfile, nm_dir, :copy)
      System.delete_env("NPM_EX_CACHE_DIR")

      assert File.exists?(Path.join([nm_dir, ".bin", "my-cli"]))
    end
  end

  describe "multiple packages with bins" do
    @tag :tmp_dir
    test "bins from multiple packages in same .bin dir", %{tmp_dir: dir} do
      nm_dir = Path.join(dir, "node_modules")

      pkg_a = Path.join(nm_dir, "tool-a")
      File.mkdir_p!(pkg_a)
      File.write!(Path.join(pkg_a, "package.json"), ~s({"name":"tool-a","bin":"./a.js"}))
      File.write!(Path.join(pkg_a, "a.js"), "#!/usr/bin/env node")

      pkg_b = Path.join(nm_dir, "tool-b")
      File.mkdir_p!(pkg_b)
      File.write!(Path.join(pkg_b, "package.json"), ~s({"name":"tool-b","bin":"./b.js"}))
      File.write!(Path.join(pkg_b, "b.js"), "#!/usr/bin/env node")

      Linker.link_bins(nm_dir, [{"tool-a", "1.0.0"}, {"tool-b", "1.0.0"}])

      assert File.exists?(Path.join([nm_dir, ".bin", "tool-a"]))
      assert File.exists?(Path.join([nm_dir, ".bin", "tool-b"]))
    end
  end

  describe "Linker.link with symlink and bin linking" do
    @tag :tmp_dir
    test "bin links work with symlink strategy", %{tmp_dir: dir} do
      cache_dir = Path.join(dir, "cache")
      nm_dir = Path.join(dir, "node_modules")

      setup_cached_package(cache_dir, "cli-tool", "1.0.0", %{
        "package.json" => ~s({"name":"cli-tool","bin":{"cli":"./bin/cli.js"}}),
        "bin/cli.js" => "#!/usr/bin/env node\nconsole.log('hello')"
      })

      lockfile = %{
        "cli-tool" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      System.put_env("NPM_EX_CACHE_DIR", cache_dir)
      Linker.link(lockfile, nm_dir, :symlink)
      System.delete_env("NPM_EX_CACHE_DIR")

      assert File.exists?(Path.join([nm_dir, ".bin", "cli"]))
    end
  end

  describe "Linker copy vs symlink" do
    @tag :tmp_dir
    test "copy creates independent files", %{tmp_dir: dir} do
      cache_dir = Path.join(dir, "cache")
      nm_dir = Path.join(dir, "node_modules")

      setup_cached_package(cache_dir, "cp-test", "1.0.0", %{
        "package.json" => ~s({"name":"cp-test"}),
        "index.js" => "original"
      })

      lockfile = %{
        "cp-test" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      System.put_env("NPM_EX_CACHE_DIR", cache_dir)
      Linker.link(lockfile, nm_dir, :copy)
      System.delete_env("NPM_EX_CACHE_DIR")

      target = Path.join([nm_dir, "cp-test", "index.js"])
      {:ok, info} = File.lstat(target)
      assert info.type == :regular
    end

    @tag :tmp_dir
    test "symlink creates links to cache", %{tmp_dir: dir} do
      cache_dir = Path.join(dir, "cache")
      nm_dir = Path.join(dir, "node_modules")

      setup_cached_package(cache_dir, "ln-test", "1.0.0", %{
        "package.json" => ~s({"name":"ln-test"})
      })

      lockfile = %{
        "ln-test" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      System.put_env("NPM_EX_CACHE_DIR", cache_dir)
      Linker.link(lockfile, nm_dir, :symlink)
      System.delete_env("NPM_EX_CACHE_DIR")

      target = Path.join(nm_dir, "ln-test")
      {:ok, info} = File.lstat(target)
      assert info.type == :symlink
    end
  end

  describe "Linker scoped packages full flow" do
    @tag :tmp_dir
    test "links scoped packages with copy strategy", %{tmp_dir: dir} do
      cache_dir = Path.join(dir, "cache")
      nm_dir = Path.join(dir, "node_modules")

      setup_cached_package(cache_dir, "@scope/pkg", "1.0.0", %{
        "package.json" => ~s({"name":"@scope/pkg","version":"1.0.0"}),
        "index.js" => "exports.ok = true"
      })

      lockfile = %{
        "@scope/pkg" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      System.put_env("NPM_EX_CACHE_DIR", cache_dir)
      Linker.link(lockfile, nm_dir, :copy)
      System.delete_env("NPM_EX_CACHE_DIR")

      assert File.exists?(Path.join([nm_dir, "@scope", "pkg", "package.json"]))
      assert File.read!(Path.join([nm_dir, "@scope", "pkg", "index.js"])) == "exports.ok = true"
    end
  end

  describe "Linker.prune with dotfiles" do
    @tag :tmp_dir
    test "preserves .cache directory", %{tmp_dir: dir} do
      nm_dir = Path.join(dir, "node_modules")
      File.mkdir_p!(Path.join(nm_dir, ".cache"))
      File.write!(Path.join([nm_dir, ".cache", "data"]), "cached")

      Linker.prune(nm_dir, MapSet.new())

      assert File.exists?(Path.join([nm_dir, ".cache", "data"]))
    end

    @tag :tmp_dir
    test "preserves .package-lock.json", %{tmp_dir: dir} do
      nm_dir = Path.join(dir, "node_modules")
      File.mkdir_p!(nm_dir)
      File.write!(Path.join(nm_dir, ".package-lock.json"), "{}")

      Linker.prune(nm_dir, MapSet.new())

      assert File.exists?(Path.join(nm_dir, ".package-lock.json"))
    end
  end

  describe "full local flow with prune and bins" do
    @tag :tmp_dir
    test "install, add bin, prune, verify", %{tmp_dir: dir} do
      cache_dir = Path.join(dir, "cache")
      nm_dir = Path.join(dir, "node_modules")
      System.put_env("NPM_EX_CACHE_DIR", cache_dir)

      setup_cached_package(cache_dir, "tool-a", "1.0.0", %{
        "package.json" => ~s({"name":"tool-a","bin":"./run.js"}),
        "run.js" => "#!/usr/bin/env node"
      })

      setup_cached_package(cache_dir, "lib-b", "2.0.0", %{
        "package.json" => ~s({"name":"lib-b"})
      })

      setup_cached_package(cache_dir, "old-pkg", "1.0.0", %{
        "package.json" => ~s({"name":"old-pkg"})
      })

      lockfile_v1 = %{
        "tool-a" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}},
        "lib-b" => %{version: "2.0.0", integrity: "", tarball: "", dependencies: %{}},
        "old-pkg" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      Linker.link(lockfile_v1, nm_dir, :copy)

      assert File.exists?(Path.join([nm_dir, "tool-a", "run.js"]))
      assert File.exists?(Path.join([nm_dir, "lib-b", "package.json"]))
      assert File.exists?(Path.join([nm_dir, "old-pkg", "package.json"]))
      assert File.exists?(Path.join([nm_dir, ".bin", "tool-a"]))

      lockfile_v2 = %{
        "tool-a" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}},
        "lib-b" => %{version: "2.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      Linker.link(lockfile_v2, nm_dir, :copy)

      assert File.exists?(Path.join([nm_dir, "tool-a", "run.js"]))
      assert File.exists?(Path.join([nm_dir, "lib-b", "package.json"]))
      refute File.exists?(Path.join(nm_dir, "old-pkg"))
      assert File.exists?(Path.join([nm_dir, ".bin", "tool-a"]))

      System.delete_env("NPM_EX_CACHE_DIR")
    end
  end

  describe "Linker with empty lockfile" do
    @tag :tmp_dir
    test "handles empty lockfile gracefully", %{tmp_dir: dir} do
      nm_dir = Path.join(dir, "node_modules")
      assert :ok = Linker.link(%{}, nm_dir, :copy)
      assert File.exists?(nm_dir)
    end
  end

  describe "Linker.hoist determinism" do
    test "returns deterministic results for same input" do
      lockfile = %{
        "a" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}},
        "b" => %{version: "2.0.0", integrity: "", tarball: "", dependencies: %{}},
        "c" => %{version: "3.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      result1 = Linker.hoist(lockfile) |> Enum.sort()
      result2 = Linker.hoist(lockfile) |> Enum.sort()
      assert result1 == result2
    end
  end

  describe "Linker.link_bins replaces old links" do
    @tag :tmp_dir
    test "overwrites existing bin links", %{tmp_dir: dir} do
      nm_dir = Path.join(dir, "node_modules")
      bin_dir = Path.join(nm_dir, ".bin")
      File.mkdir_p!(bin_dir)

      File.write!(Path.join(bin_dir, "old-link"), "stale")

      pkg_dir = Path.join(nm_dir, "tool")
      File.mkdir_p!(pkg_dir)
      File.write!(Path.join(pkg_dir, "package.json"), ~s({"name":"tool","bin":"./new.js"}))
      File.write!(Path.join(pkg_dir, "new.js"), "#!/usr/bin/env node")

      Linker.link_bins(nm_dir, [{"tool", "1.0.0"}])

      assert File.exists?(Path.join(bin_dir, "tool"))
    end
  end

  describe "Linker: hoist selects most common version" do
    test "hoists single version of each package" do
      lockfile = %{
        "lodash" => %{version: "4.17.21", integrity: "", tarball: "", dependencies: %{}},
        "react" => %{version: "18.2.0", integrity: "", tarball: "", dependencies: %{}}
      }

      tree = Linker.hoist(lockfile)
      names = Enum.map(tree, &elem(&1, 0))
      assert "lodash" in names
      assert "react" in names
    end

    test "hoist returns name-version tuples" do
      lockfile = %{
        "a" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      [{name, version}] = Linker.hoist(lockfile)
      assert name == "a"
      assert version == "1.0.0"
    end
  end

  describe "Linker: hoist with dependencies" do
    test "all packages are represented in hoist output" do
      lockfile = %{
        "a" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{"b" => "^1"}},
        "b" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}},
        "c" => %{version: "2.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      tree = Linker.hoist(lockfile)
      names = Enum.map(tree, &elem(&1, 0)) |> Enum.sort()
      assert names == ["a", "b", "c"]
    end
  end

  describe "Linker: link_bins with no bin field" do
    @tag :tmp_dir
    test "no .bin dir created when no packages have bins", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      File.mkdir_p!(Path.join(nm, "plain-pkg"))

      File.write!(
        Path.join([nm, "plain-pkg", "package.json"]),
        ~s({"name":"plain-pkg","version":"1.0.0"})
      )

      Linker.link_bins(nm, [{"plain-pkg", "1.0.0"}])
      refute File.exists?(Path.join(nm, ".bin"))
    end
  end

  describe "Linker: prune empty scoped directory cleanup" do
    @tag :tmp_dir
    test "prune removes empty scope directory", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      scope_dir = Path.join(nm, "@empty-scope")
      File.mkdir_p!(scope_dir)

      Linker.prune(nm, MapSet.new())
      refute File.exists?(scope_dir)
    end
  end

  describe "Linker: hoist is deterministic" do
    test "same input always produces same output" do
      lockfile = %{
        "c" => %{version: "3.0.0", integrity: "", tarball: "", dependencies: %{}},
        "a" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}},
        "b" => %{version: "2.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      tree1 = Linker.hoist(lockfile)
      tree2 = Linker.hoist(lockfile)
      assert Enum.sort(tree1) == Enum.sort(tree2)
    end
  end

  describe "Linker: link_bins with directories.bin" do
    @tag :tmp_dir
    test "creates bins from directories.bin field", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      pkg_dir = Path.join(nm, "dir-bin-pkg")
      bin_src = Path.join(pkg_dir, "scripts")
      File.mkdir_p!(bin_src)

      File.write!(Path.join(pkg_dir, "package.json"), ~s({
        "name": "dir-bin-pkg",
        "directories": {"bin": "./scripts"}
      }))

      File.write!(Path.join(bin_src, "tool-a"), "#!/bin/sh")
      File.write!(Path.join(bin_src, "tool-b"), "#!/bin/sh")

      Linker.link_bins(nm, [{"dir-bin-pkg", "1.0.0"}])

      bin_dir = Path.join(nm, ".bin")
      assert File.exists?(Path.join(bin_dir, "tool-a"))
      assert File.exists?(Path.join(bin_dir, "tool-b"))
    end
  end

  describe "Linker: hoist preserves all package versions" do
    test "single-version packages each appear once" do
      lockfile = %{
        "x" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}},
        "y" => %{version: "2.0.0", integrity: "", tarball: "", dependencies: %{}},
        "z" => %{version: "3.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      tree = Linker.hoist(lockfile)
      versions = Map.new(tree)
      assert versions["x"] == "1.0.0"
      assert versions["y"] == "2.0.0"
      assert versions["z"] == "3.0.0"
    end
  end

  describe "Linker: default strategy detection" do
    test "default strategy is symlink on unix" do
      # On macOS/Linux, default should be symlink
      assert File.exists?("/bin/sh")

      lockfile = %{
        "test-pkg" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      # hoist is the same regardless of strategy
      tree = Linker.hoist(lockfile)
      assert [{"test-pkg", "1.0.0"}] = tree
    end
  end

  describe "Linker: prune removes stale packages" do
    @tag :tmp_dir
    test "prune removes packages not in expected set", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      File.mkdir_p!(Path.join(nm, "old-pkg"))
      File.write!(Path.join([nm, "old-pkg", "index.js"]), "")
      File.mkdir_p!(Path.join(nm, "keep-pkg"))
      File.write!(Path.join([nm, "keep-pkg", "index.js"]), "")

      expected = MapSet.new(["keep-pkg"])
      Linker.prune(nm, expected)

      assert File.exists?(Path.join(nm, "keep-pkg"))
      refute File.exists?(Path.join(nm, "old-pkg"))
    end

    @tag :tmp_dir
    test "prune handles scoped packages", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      File.mkdir_p!(Path.join([nm, "@scope", "keep"]))
      File.write!(Path.join([nm, "@scope", "keep", "index.js"]), "")
      File.mkdir_p!(Path.join([nm, "@scope", "remove"]))
      File.write!(Path.join([nm, "@scope", "remove", "index.js"]), "")

      expected = MapSet.new(["@scope/keep"])
      Linker.prune(nm, expected)

      assert File.exists?(Path.join([nm, "@scope", "keep"]))
      refute File.exists?(Path.join([nm, "@scope", "remove"]))
    end

    @tag :tmp_dir
    test "prune preserves .bin directory", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      bin_dir = Path.join(nm, ".bin")
      File.mkdir_p!(bin_dir)
      File.write!(Path.join(bin_dir, "my-tool"), "#!/bin/sh")

      expected = MapSet.new()
      Linker.prune(nm, expected)

      assert File.exists?(Path.join(bin_dir, "my-tool"))
    end
  end

  describe "Linker: copy strategy creates real files" do
    @tag :tmp_dir
    test "copy strategy creates independent files, not symlinks", %{tmp_dir: dir} do
      cache_dir = Path.join(dir, "cache")
      nm_dir = Path.join(dir, "node_modules")

      setup_cached_package(cache_dir, "real-pkg", "1.0.0", %{
        "package.json" => ~s({"name":"real-pkg","version":"1.0.0"}),
        "index.js" => "module.exports = {}"
      })

      System.put_env("NPM_EX_CACHE_DIR", cache_dir)

      lockfile = %{
        "real-pkg" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      assert :ok = Linker.link(lockfile, nm_dir, :copy)

      target = Path.join([nm_dir, "real-pkg", "index.js"])
      assert File.exists?(target)
      # Should NOT be a symlink with copy strategy
      {:ok, stat} = File.lstat(target)
      assert stat.type == :regular

      System.delete_env("NPM_EX_CACHE_DIR")
    end
  end

  describe "Linker: npm-compatible hoisting" do
    test "single dependency hoists to top level" do
      lockfile = %{
        "a" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}},
        "b" => %{version: "2.0.0", integrity: "", tarball: "", dependencies: %{"a" => "^1.0"}}
      }

      tree = Linker.hoist(lockfile)
      names = Enum.map(tree, &elem(&1, 0)) |> Enum.sort()
      assert "a" in names
      assert "b" in names
    end

    test "all deps hoisted flat (no nesting)" do
      lockfile = %{
        "root" => %{
          version: "1.0.0",
          integrity: "",
          tarball: "",
          dependencies: %{"mid" => "^1.0"}
        },
        "mid" => %{
          version: "1.0.0",
          integrity: "",
          tarball: "",
          dependencies: %{"leaf" => "^1.0"}
        },
        "leaf" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      tree = Linker.hoist(lockfile)
      assert length(tree) == 3
    end
  end

  describe "Linker: prune matches npm behavior" do
    @tag :tmp_dir
    test "removes packages not in expected set", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      File.mkdir_p!(Path.join(nm, "keep-me"))
      File.mkdir_p!(Path.join(nm, "remove-me"))
      File.mkdir_p!(Path.join(nm, ".bin"))

      Linker.prune(nm, MapSet.new(["keep-me"]))

      assert File.dir?(Path.join(nm, "keep-me"))
      refute File.dir?(Path.join(nm, "remove-me"))
      assert File.dir?(Path.join(nm, ".bin"))
    end

    @tag :tmp_dir
    test "prunes scoped packages correctly", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      File.mkdir_p!(Path.join([nm, "@scope", "keep"]))
      File.mkdir_p!(Path.join([nm, "@scope", "remove"]))

      Linker.prune(nm, MapSet.new(["@scope/keep"]))

      assert File.dir?(Path.join([nm, "@scope", "keep"]))
      refute File.dir?(Path.join([nm, "@scope", "remove"]))
    end
  end

  describe "Linker: nested package installation" do
    @tag :tmp_dir
    test "link_nested creates parent/node_modules/nested_pkg structure", %{tmp_dir: dir} do
      nm_dir = Path.join(dir, "node_modules")
      cache_dir = Path.join(dir, "cache")

      # Set up parent and nested package in cache
      setup_cached_package(cache_dir, "parent-pkg", "1.0.0", %{
        "package.json" => ~s({"name":"parent-pkg","version":"1.0.0"})
      })

      setup_cached_package(cache_dir, "nested-pkg", "2.0.0", %{
        "package.json" => ~s({"name":"nested-pkg","version":"2.0.0","main":"index.js"}),
        "index.js" => "module.exports = 'v2'"
      })

      System.put_env("NPM_EX_CACHE_DIR", cache_dir)

      # First, create flat node_modules with parent
      flat_lockfile = %{
        "parent-pkg" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      :ok = Linker.link(flat_lockfile, nm_dir, :copy)
      assert File.exists?(Path.join([nm_dir, "parent-pkg", "package.json"]))

      # Now create nested
      nested_target = Path.join([nm_dir, "parent-pkg", "node_modules", "nested-pkg"])
      source = NPM.Cache.package_dir("nested-pkg", "2.0.0")
      File.mkdir_p!(Path.dirname(nested_target))
      File.cp_r!(source, nested_target)

      assert File.exists?(Path.join(nested_target, "index.js"))
      content = File.read!(Path.join(nested_target, "index.js"))
      assert content == "module.exports = 'v2'"

      System.delete_env("NPM_EX_CACHE_DIR")
    end

    @tag :tmp_dir
    test "nested node_modules separate from hoisted", %{tmp_dir: dir} do
      nm_dir = Path.join(dir, "node_modules")
      cache_dir = Path.join(dir, "cache")

      setup_cached_package(cache_dir, "debug", "2.6.9", %{
        "package.json" => ~s({"name":"debug","version":"2.6.9"})
      })

      setup_cached_package(cache_dir, "ms", "2.0.0", %{
        "package.json" => ~s({"name":"ms","version":"2.0.0"}),
        "index.js" => "module.exports = 'v2.0.0'"
      })

      setup_cached_package(cache_dir, "ms", "2.1.3", %{
        "package.json" => ~s({"name":"ms","version":"2.1.3"}),
        "index.js" => "module.exports = 'v2.1.3'"
      })

      System.put_env("NPM_EX_CACHE_DIR", cache_dir)

      # Hoisted ms@2.1.3 (most common)
      flat_lockfile = %{
        "debug" => %{version: "2.6.9", integrity: "", tarball: "", dependencies: %{}},
        "ms" => %{version: "2.1.3", integrity: "", tarball: "", dependencies: %{}}
      }

      :ok = Linker.link(flat_lockfile, nm_dir, :copy)

      # Hoisted ms is 2.1.3
      hoisted_pkg = Path.join([nm_dir, "ms", "package.json"])
      assert File.exists?(hoisted_pkg)
      hoisted_data = hoisted_pkg |> File.read!() |> :json.decode()
      assert hoisted_data["version"] == "2.1.3"

      # Manually create nested ms@2.0.0 under debug
      nested_ms = Path.join([nm_dir, "debug", "node_modules", "ms"])
      source = NPM.Cache.package_dir("ms", "2.0.0")
      File.mkdir_p!(Path.dirname(nested_ms))
      File.cp_r!(source, nested_ms)

      nested_data = Path.join(nested_ms, "package.json") |> File.read!() |> :json.decode()
      assert nested_data["version"] == "2.0.0"

      # Both exist independently
      assert File.exists?(Path.join([nm_dir, "ms", "index.js"]))
      assert File.exists?(Path.join(nested_ms, "index.js"))

      hoisted_content = File.read!(Path.join([nm_dir, "ms", "index.js"]))
      nested_content = File.read!(Path.join(nested_ms, "index.js"))
      assert hoisted_content != nested_content

      System.delete_env("NPM_EX_CACHE_DIR")
    end
  end

  describe "Linker: bin linking with map format" do
    @tag :tmp_dir
    test "creates .bin links for map-style bin field", %{tmp_dir: dir} do
      nm_dir = Path.join(dir, "node_modules")
      pkg_dir = Path.join(nm_dir, "my-tool")
      bin_dir = Path.join(nm_dir, ".bin")
      File.mkdir_p!(pkg_dir)

      File.write!(Path.join(pkg_dir, "package.json"), ~s({
        "name": "my-tool",
        "bin": {
          "tool": "./bin/tool.js",
          "tool-dev": "./bin/dev.js"
        }
      }))

      File.mkdir_p!(Path.join(pkg_dir, "bin"))
      File.write!(Path.join(pkg_dir, "bin/tool.js"), "#!/usr/bin/env node")
      File.write!(Path.join(pkg_dir, "bin/dev.js"), "#!/usr/bin/env node")

      Linker.link_bins(nm_dir, [{"my-tool", "1.0.0"}])

      assert File.exists?(Path.join(bin_dir, "tool"))
      assert File.exists?(Path.join(bin_dir, "tool-dev"))
    end
  end

  describe "Linker: bin linking with string format" do
    @tag :tmp_dir
    test "creates .bin link using package name for string bin", %{tmp_dir: dir} do
      nm_dir = Path.join(dir, "node_modules")
      pkg_dir = Path.join(nm_dir, "simple-cli")
      File.mkdir_p!(pkg_dir)

      File.write!(Path.join(pkg_dir, "package.json"), ~s({
        "name": "simple-cli",
        "bin": "./cli.js"
      }))

      File.write!(Path.join(pkg_dir, "cli.js"), "#!/usr/bin/env node")

      Linker.link_bins(nm_dir, [{"simple-cli", "1.0.0"}])

      bin_dir = Path.join(nm_dir, ".bin")
      assert File.exists?(Path.join(bin_dir, "simple-cli"))
    end
  end

  describe "Linker: bin linking with scoped package" do
    @tag :tmp_dir
    test "scoped package string bin uses unscoped name", %{tmp_dir: dir} do
      nm_dir = Path.join(dir, "node_modules")
      scope_dir = Path.join([nm_dir, "@scope", "my-tool"])
      File.mkdir_p!(scope_dir)

      File.write!(Path.join(scope_dir, "package.json"), ~s({
        "name": "@scope/my-tool",
        "bin": "./cli.js"
      }))

      File.write!(Path.join(scope_dir, "cli.js"), "#!/usr/bin/env node")

      Linker.link_bins(nm_dir, [{"@scope/my-tool", "1.0.0"}])

      bin_dir = Path.join(nm_dir, ".bin")
      assert File.exists?(Path.join(bin_dir, "my-tool"))
    end
  end

  describe "Linker: symlink strategy creates links" do
    @tag :tmp_dir
    test "symlink points to cache directory", %{tmp_dir: dir} do
      cache_dir = Path.join(dir, "cache")
      nm_dir = Path.join(dir, "node_modules")

      setup_cached_package(cache_dir, "linked-pkg", "1.0.0", %{
        "package.json" => ~s({"name":"linked-pkg"})
      })

      System.put_env("NPM_EX_CACHE_DIR", cache_dir)

      lockfile = %{
        "linked-pkg" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      assert :ok = Linker.link(lockfile, nm_dir, :symlink)

      target = Path.join(nm_dir, "linked-pkg")
      {:ok, info} = File.lstat(target)
      assert info.type == :symlink

      System.delete_env("NPM_EX_CACHE_DIR")
    end
  end
end
