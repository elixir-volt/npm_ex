defmodule NPM.OutdatedTest do
  use ExUnit.Case, async: true

  describe "check outdated packages" do
    test "detects major update" do
      lockfile = %{
        "lodash" => %{version: "3.10.1", integrity: "", tarball: "", dependencies: %{}}
      }

      deps = %{"lodash" => "^3.0.0"}
      latest = %{"lodash" => "4.17.21"}

      [entry] = NPM.Outdated.check(lockfile, deps, latest)
      assert entry.name == "lodash"
      assert entry.current == "3.10.1"
      assert entry.latest == "4.17.21"
      assert entry.type == :major
    end

    test "detects minor update" do
      lockfile = %{
        "express" => %{version: "4.18.0", integrity: "", tarball: "", dependencies: %{}}
      }

      deps = %{"express" => "^4.0.0"}
      latest = %{"express" => "4.21.2"}

      [entry] = NPM.Outdated.check(lockfile, deps, latest)
      assert entry.type == :minor
    end

    test "detects patch update" do
      lockfile = %{
        "ms" => %{version: "2.1.2", integrity: "", tarball: "", dependencies: %{}}
      }

      deps = %{"ms" => "^2.1.0"}
      latest = %{"ms" => "2.1.3"}

      [entry] = NPM.Outdated.check(lockfile, deps, latest)
      assert entry.type == :patch
    end

    test "current version returns no entries" do
      lockfile = %{
        "react" => %{version: "18.2.0", integrity: "", tarball: "", dependencies: %{}}
      }

      deps = %{"react" => "^18.0.0"}
      latest = %{"react" => "18.2.0"}

      assert [] = NPM.Outdated.check(lockfile, deps, latest)
    end

    test "multiple packages" do
      lockfile = %{
        "a" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}},
        "b" => %{version: "2.0.0", integrity: "", tarball: "", dependencies: %{}},
        "c" => %{version: "3.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      deps = %{"a" => "^1.0.0", "b" => "^2.0.0", "c" => "^3.0.0"}
      latest = %{"a" => "2.0.0", "b" => "2.0.0", "c" => "4.0.0"}

      entries = NPM.Outdated.check(lockfile, deps, latest)
      names = Enum.map(entries, & &1.name)
      assert "a" in names
      assert "c" in names
      refute "b" in names
    end

    test "missing from lockfile is skipped" do
      lockfile = %{}
      deps = %{"ghost" => "^1.0.0"}
      latest = %{"ghost" => "2.0.0"}

      assert [] = NPM.Outdated.check(lockfile, deps, latest)
    end
  end

  describe "filter_by_type" do
    test "filters major updates" do
      entries = [
        %{name: "a", current: "1.0.0", wanted: "1.0.0", latest: "2.0.0", type: :major},
        %{name: "b", current: "1.0.0", wanted: "1.1.0", latest: "1.1.0", type: :minor},
        %{name: "c", current: "1.0.0", wanted: "1.0.1", latest: "1.0.1", type: :patch}
      ]

      major = NPM.Outdated.filter_by_type(entries, :major)
      assert length(major) == 1
      assert hd(major).name == "a"
    end
  end

  describe "format_entry" do
    test "formats entry with arrow notation" do
      entry = %{
        name: "lodash",
        current: "3.10.1",
        wanted: "3.10.2",
        latest: "4.17.21",
        type: :major
      }

      formatted = NPM.Outdated.format_entry(entry)
      assert formatted =~ "lodash"
      assert formatted =~ "3.10.1"
      assert formatted =~ "4.17.21"
      assert formatted =~ "→"
    end
  end

  describe "summary" do
    test "counts by type" do
      entries = [
        %{name: "a", current: "1.0.0", wanted: "1.0.0", latest: "2.0.0", type: :major},
        %{name: "b", current: "1.0.0", wanted: "1.0.0", latest: "2.0.0", type: :major},
        %{name: "c", current: "1.0.0", wanted: "1.1.0", latest: "1.1.0", type: :minor},
        %{name: "d", current: "1.0.0", wanted: "1.0.1", latest: "1.0.1", type: :patch}
      ]

      s = NPM.Outdated.summary(entries)
      assert s.total == 4
      assert s.major == 2
      assert s.minor == 1
      assert s.patch == 1
    end

    test "empty list" do
      s = NPM.Outdated.summary([])
      assert s.total == 0
      assert s.major == 0
    end
  end

  describe "check with scoped packages" do
    test "handles scoped package names" do
      lockfile = %{
        "@babel/core" => %{version: "7.23.0", integrity: "", tarball: "", dependencies: %{}}
      }

      deps = %{"@babel/core" => "^7.0.0"}
      latest = %{"@babel/core" => "7.24.5"}

      [entry] = NPM.Outdated.check(lockfile, deps, latest)
      assert entry.name == "@babel/core"
      assert entry.type == :minor
    end
  end

  describe "check with missing latest info" do
    test "treats missing latest as current" do
      lockfile = %{
        "internal-pkg" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      deps = %{"internal-pkg" => "^1.0.0"}
      latest = %{}

      assert [] = NPM.Outdated.check(lockfile, deps, latest)
    end
  end

  describe "filter_by_type minor and patch" do
    test "filters minor updates" do
      entries = [
        %{name: "a", current: "1.0.0", wanted: "1.1.0", latest: "1.1.0", type: :minor},
        %{name: "b", current: "1.0.0", wanted: "1.0.1", latest: "1.0.1", type: :patch}
      ]

      minor = NPM.Outdated.filter_by_type(entries, :minor)
      assert length(minor) == 1
      assert hd(minor).name == "a"
    end

    test "filters patch updates" do
      entries = [
        %{name: "a", current: "1.0.0", wanted: "1.0.0", latest: "2.0.0", type: :major},
        %{name: "b", current: "1.0.0", wanted: "1.0.1", latest: "1.0.1", type: :patch}
      ]

      patch = NPM.Outdated.filter_by_type(entries, :patch)
      assert length(patch) == 1
      assert hd(patch).name == "b"
    end
  end
end
