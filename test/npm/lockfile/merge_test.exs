defmodule NPM.Lockfile.MergeTest do
  use ExUnit.Case, async: true

  describe "LockMerge: diff with version changes" do
    test "diff detects only version changes, not identical entries" do
      base = %{
        "a" => %{version: "1.0.0", integrity: "sha-old", tarball: "url1", dependencies: %{}},
        "b" => %{version: "2.0.0", integrity: "sha-same", tarball: "url2", dependencies: %{}}
      }

      newer = %{
        "a" => %{version: "1.0.1", integrity: "sha-new", tarball: "url3", dependencies: %{}},
        "b" => %{version: "2.0.0", integrity: "sha-same", tarball: "url2", dependencies: %{}}
      }

      {added, removed, changed} = NPM.Lockfile.Merge.diff(base, newer)
      assert added == []
      assert removed == []
      assert changed == [{"a", "1.0.0", "1.0.1"}]
    end
  end

  describe "LockMerge: merge with multiple conflicts" do
    test "all newer entries win by default" do
      base = %{
        "a" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}},
        "b" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}},
        "c" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      newer = %{
        "a" => %{version: "2.0.0", integrity: "", tarball: "", dependencies: %{}},
        "b" => %{version: "3.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      result = NPM.Lockfile.Merge.merge(base, newer)
      assert result["a"].version == "2.0.0"
      assert result["b"].version == "3.0.0"
      assert result["c"].version == "1.0.0"
    end
  end

  describe "LockMerge: diff symmetry" do
    test "diff(a,b) added == diff(b,a) removed" do
      a = %{"only-a" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}}
      b = %{"only-b" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}}

      {added_ab, removed_ab, _} = NPM.Lockfile.Merge.diff(a, b)
      {added_ba, removed_ba, _} = NPM.Lockfile.Merge.diff(b, a)

      assert added_ab == removed_ba
      assert removed_ab == added_ba
    end
  end

  describe "LockMerge: edge cases" do
    test "merge empty base with populated newer" do
      newer = %{
        "a" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      result = NPM.Lockfile.Merge.merge(%{}, newer)
      assert result == newer
    end

    test "merge populated base with empty newer" do
      base = %{
        "a" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      result = NPM.Lockfile.Merge.merge(base, %{})
      assert result == base
    end
  end

  describe "LockMerge: lockfile merging" do
    test "merge prefers newer entries" do
      base = %{
        "lodash" => %{version: "4.17.20", integrity: "", tarball: "", dependencies: %{}},
        "react" => %{version: "18.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      newer = %{
        "lodash" => %{version: "4.17.21", integrity: "", tarball: "", dependencies: %{}},
        "vue" => %{version: "3.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      merged = NPM.Lockfile.Merge.merge(base, newer)
      assert merged["lodash"].version == "4.17.21"
      assert merged["react"].version == "18.0.0"
      assert merged["vue"].version == "3.0.0"
    end

    test "merge with custom resolver picks higher version" do
      base = %{
        "pkg" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      newer = %{
        "pkg" => %{version: "2.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      result =
        NPM.Lockfile.Merge.merge(base, newer, fn _name, b, n ->
          if NPM.VersionUtil.gt?(n.version, b.version), do: n, else: b
        end)

      assert result["pkg"].version == "2.0.0"
    end

    test "diff detects added, removed, and changed packages" do
      base = %{
        "lodash" => %{version: "4.17.20", integrity: "", tarball: "", dependencies: %{}},
        "removed-pkg" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      newer = %{
        "lodash" => %{version: "4.17.21", integrity: "", tarball: "", dependencies: %{}},
        "new-pkg" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      {added, removed, changed} = NPM.Lockfile.Merge.diff(base, newer)
      assert "new-pkg" in added
      assert "removed-pkg" in removed
      assert {"lodash", "4.17.20", "4.17.21"} in changed
    end

    test "diff returns empty when identical" do
      lockfile = %{
        "a" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      {added, removed, changed} = NPM.Lockfile.Merge.diff(lockfile, lockfile)
      assert added == []
      assert removed == []
      assert changed == []
    end
  end

  describe "LockMerge: diff with identical lockfiles" do
    test "no changes detected" do
      lockfile = %{
        "a" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      {added, removed, changed} = NPM.Lockfile.Merge.diff(lockfile, lockfile)
      assert added == []
      assert removed == []
      assert changed == []
    end
  end
end
