defmodule NPM.VersionUtilTest do
  use ExUnit.Case, async: true

  describe "Integrity + VersionUtil integration" do
    test "integrity is stable across version bumps" do
      data = "payload"
      hash1 = NPM.Integrity.compute_sha256(data)
      hash2 = NPM.Integrity.compute_sha256(data)
      assert hash1 == hash2
      assert NPM.VersionUtil.gt?("2.0.0", "1.0.0")
    end
  end

  describe "VersionUtil.parse_triple" do
    test "parses standard version" do
      assert {:ok, {1, 2, 3}} = NPM.VersionUtil.parse_triple("1.2.3")
    end

    test "returns error for invalid" do
      assert :error = NPM.VersionUtil.parse_triple("nope")
    end
  end

  describe "VersionUtil.compare" do
    test "gt" do
      assert :gt = NPM.VersionUtil.compare("2.0.0", "1.0.0")
    end

    test "lt" do
      assert :lt = NPM.VersionUtil.compare("1.0.0", "2.0.0")
    end

    test "eq" do
      assert :eq = NPM.VersionUtil.compare("1.0.0", "1.0.0")
    end
  end

  describe "VersionUtil.gt?/lt?" do
    test "gt? true" do
      assert NPM.VersionUtil.gt?("2.0.0", "1.0.0")
    end

    test "gt? false" do
      refute NPM.VersionUtil.gt?("1.0.0", "2.0.0")
    end

    test "lt? true" do
      assert NPM.VersionUtil.lt?("1.0.0", "2.0.0")
    end
  end

  describe "VersionUtil.major/minor" do
    test "major" do
      assert 5 = NPM.VersionUtil.major("5.3.1")
    end

    test "minor" do
      assert 3 = NPM.VersionUtil.minor("5.3.1")
    end

    test "invalid" do
      assert :error = NPM.VersionUtil.major("bad")
    end
  end

  describe "VersionUtil.prerelease?" do
    test "detects prerelease" do
      assert NPM.VersionUtil.prerelease?("1.0.0-alpha.1")
    end

    test "stable is not prerelease" do
      refute NPM.VersionUtil.prerelease?("1.0.0")
    end

    test "invalid is not prerelease" do
      refute NPM.VersionUtil.prerelease?("nope")
    end
  end

  describe "VersionUtil.bump_*" do
    test "bump_patch" do
      assert "1.2.4" = NPM.VersionUtil.bump_patch("1.2.3")
    end

    test "bump_minor" do
      assert "1.3.0" = NPM.VersionUtil.bump_minor("1.2.3")
    end

    test "bump_major" do
      assert "2.0.0" = NPM.VersionUtil.bump_major("1.2.3")
    end

    test "bump invalid returns error" do
      assert :error = NPM.VersionUtil.bump_patch("bad")
    end
  end

  describe "VersionUtil.sort/latest" do
    test "sorts versions ascending" do
      assert ["1.0.0", "1.2.0", "2.0.0"] =
               NPM.VersionUtil.sort(["2.0.0", "1.0.0", "1.2.0"])
    end

    test "latest returns highest" do
      assert "3.0.0" = NPM.VersionUtil.latest(["1.0.0", "3.0.0", "2.0.0"])
    end

    test "latest of empty is nil" do
      assert nil == NPM.VersionUtil.latest([])
    end

    test "skips invalid versions" do
      assert ["1.0.0"] = NPM.VersionUtil.sort(["bad", "1.0.0", "nope"])
    end
  end

  describe "VersionUtil: npm version operations" do
    test "parse_triple splits version correctly" do
      assert {:ok, {1, 2, 3}} = NPM.VersionUtil.parse_triple("1.2.3")
    end

    test "compare follows semver ordering" do
      assert :lt = NPM.VersionUtil.compare("1.0.0", "2.0.0")
      assert :gt = NPM.VersionUtil.compare("2.0.0", "1.0.0")
      assert :eq = NPM.VersionUtil.compare("1.0.0", "1.0.0")
    end

    test "compare handles minor/patch differences" do
      assert :lt = NPM.VersionUtil.compare("1.0.0", "1.1.0")
      assert :lt = NPM.VersionUtil.compare("1.0.0", "1.0.1")
      assert :gt = NPM.VersionUtil.compare("1.0.1", "1.0.0")
    end

    test "bump operations follow npm semantics" do
      assert "2.0.0" = NPM.VersionUtil.bump_major("1.2.3")
      assert "1.3.0" = NPM.VersionUtil.bump_minor("1.2.3")
      assert "1.2.4" = NPM.VersionUtil.bump_patch("1.2.3")
    end

    test "sort orders versions correctly" do
      versions = ["2.0.0", "1.0.0", "1.5.0", "0.9.0", "1.0.1"]
      sorted = NPM.VersionUtil.sort(versions)
      assert sorted == ["0.9.0", "1.0.0", "1.0.1", "1.5.0", "2.0.0"]
    end

    test "latest returns highest version" do
      assert "3.0.0" = NPM.VersionUtil.latest(["1.0.0", "3.0.0", "2.0.0"])
    end

    test "prerelease? detects pre-release versions" do
      assert NPM.VersionUtil.prerelease?("1.0.0-alpha.1")
      assert NPM.VersionUtil.prerelease?("1.0.0-beta")
      refute NPM.VersionUtil.prerelease?("1.0.0")
    end

    test "major/minor accessors" do
      assert 1 = NPM.VersionUtil.major("1.2.3")
      assert 2 = NPM.VersionUtil.minor("1.2.3")
    end

    test "gt? and lt? comparison" do
      assert NPM.VersionUtil.gt?("2.0.0", "1.0.0")
      refute NPM.VersionUtil.gt?("1.0.0", "2.0.0")
      assert NPM.VersionUtil.lt?("1.0.0", "2.0.0")
      refute NPM.VersionUtil.lt?("2.0.0", "1.0.0")
    end
  end

  describe "VersionUtil: edge cases" do
    test "bump_major resets minor and patch" do
      assert "2.0.0" = NPM.VersionUtil.bump_major("1.5.3")
    end

    test "bump_minor resets patch" do
      assert "1.6.0" = NPM.VersionUtil.bump_minor("1.5.3")
    end

    test "sort with pre-release versions" do
      versions = ["1.0.0", "1.0.0-alpha", "1.0.0-beta"]
      sorted = NPM.VersionUtil.sort(versions)
      # Pre-release versions sort before release
      assert List.first(sorted) =~ "alpha"
    end

    test "compare with equal versions" do
      assert :eq = NPM.VersionUtil.compare("1.0.0", "1.0.0")
    end
  end

  describe "VersionUtil: major/minor for various versions" do
    test "major returns first component" do
      assert 0 = NPM.VersionUtil.major("0.1.0")
      assert 10 = NPM.VersionUtil.major("10.0.0")
    end

    test "minor returns second component" do
      assert 0 = NPM.VersionUtil.minor("1.0.0")
      assert 15 = NPM.VersionUtil.minor("1.15.3")
    end
  end

  describe "VersionUtil: sort empty list" do
    test "empty list returns empty" do
      assert [] = NPM.VersionUtil.sort([])
    end
  end

  describe "VersionUtil: parse_triple edge cases" do
    test "parse_triple with zero version" do
      assert {:ok, {0, 0, 0}} = NPM.VersionUtil.parse_triple("0.0.0")
    end

    test "parse_triple with large numbers" do
      assert {:ok, {100, 200, 300}} = NPM.VersionUtil.parse_triple("100.200.300")
    end
  end

  describe "VersionUtil: latest with single version" do
    test "returns the only version" do
      assert "1.0.0" = NPM.VersionUtil.latest(["1.0.0"])
    end
  end

  describe "VersionUtil: sort stability" do
    test "sort is stable for same versions" do
      result = NPM.VersionUtil.sort(["1.0.0", "1.0.0", "1.0.0"])
      assert result == ["1.0.0", "1.0.0", "1.0.0"]
    end

    test "sort with many versions" do
      versions = ["3.0.0", "1.0.0", "2.0.0", "1.5.0", "0.1.0", "2.1.0"]
      sorted = NPM.VersionUtil.sort(versions)
      assert List.first(sorted) == "0.1.0"
      assert sorted |> Enum.reverse() |> hd() == "3.0.0"
    end
  end

  describe "VersionUtil: gt?/lt? edge cases" do
    test "equal versions are neither gt nor lt" do
      refute NPM.VersionUtil.gt?("1.0.0", "1.0.0")
      refute NPM.VersionUtil.lt?("1.0.0", "1.0.0")
    end
  end

  describe "VersionUtil: bump functions" do
    test "bump_patch increments patch" do
      assert "1.0.1" = NPM.VersionUtil.bump_patch("1.0.0")
      assert "1.2.4" = NPM.VersionUtil.bump_patch("1.2.3")
    end

    test "bump_minor increments minor and resets patch" do
      assert "1.1.0" = NPM.VersionUtil.bump_minor("1.0.5")
      assert "2.1.0" = NPM.VersionUtil.bump_minor("2.0.3")
    end

    test "bump_major increments major and resets others" do
      assert "2.0.0" = NPM.VersionUtil.bump_major("1.5.3")
      assert "1.0.0" = NPM.VersionUtil.bump_major("0.9.9")
    end
  end

  describe "VersionUtil: comparison operators" do
    test "gt? returns true when first is greater" do
      assert NPM.VersionUtil.gt?("2.0.0", "1.0.0")
      assert NPM.VersionUtil.gt?("1.1.0", "1.0.0")
      assert NPM.VersionUtil.gt?("1.0.1", "1.0.0")
    end

    test "gt? returns false when equal or less" do
      refute NPM.VersionUtil.gt?("1.0.0", "1.0.0")
      refute NPM.VersionUtil.gt?("1.0.0", "2.0.0")
    end

    test "lt? returns true when first is less" do
      assert NPM.VersionUtil.lt?("1.0.0", "2.0.0")
      assert NPM.VersionUtil.lt?("1.0.0", "1.1.0")
    end

    test "lt? returns false when equal or greater" do
      refute NPM.VersionUtil.lt?("1.0.0", "1.0.0")
      refute NPM.VersionUtil.lt?("2.0.0", "1.0.0")
    end
  end

  describe "VersionUtil: compare edge cases" do
    test "compare identical versions" do
      assert :eq = NPM.VersionUtil.compare("5.5.5", "5.5.5")
    end

    test "compare with different major" do
      assert :gt = NPM.VersionUtil.compare("10.0.0", "9.0.0")
      assert :lt = NPM.VersionUtil.compare("9.0.0", "10.0.0")
    end
  end

  describe "VersionUtil: sort with duplicates" do
    test "preserves duplicate entries" do
      versions = ["1.0.0", "2.0.0", "1.0.0", "3.0.0"]
      sorted = NPM.VersionUtil.sort(versions)
      assert Enum.count(sorted, &(&1 == "1.0.0")) == 2
    end
  end

  describe "VersionUtil: prerelease? edge cases" do
    test "build metadata alone is not prerelease" do
      refute NPM.VersionUtil.prerelease?("1.0.0+build.123")
    end

    test "prerelease with build metadata" do
      assert NPM.VersionUtil.prerelease?("1.0.0-alpha+build")
    end
  end
end
