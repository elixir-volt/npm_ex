defmodule NPM.CacheStatsTest do
  use ExUnit.Case, async: true

  describe "hit_miss" do
    test "empty lockfile" do
      stats = NPM.CacheStats.hit_miss(%{})
      assert stats.hits == 0
      assert stats.misses == 0
      assert stats.total == 0
    end

    test "all misses for non-cached packages" do
      lockfile = %{"nonexistent-pkg-xyz" => %{version: "99.99.99"}}
      stats = NPM.CacheStats.hit_miss(lockfile)
      assert stats.misses == 1
      assert stats.hits == 0
    end
  end

  describe "hit_rate" do
    test "100% for empty lockfile" do
      assert 100.0 = NPM.CacheStats.hit_rate(%{})
    end

    test "0% for all misses" do
      lockfile = %{"nonexistent-pkg-xyz" => %{version: "99.99.99"}}
      assert NPM.CacheStats.hit_rate(lockfile) == 0.0
    end
  end

  describe "format" do
    test "formats stats" do
      stats = %{hits: 8, misses: 2, total: 10}
      formatted = NPM.CacheStats.format(stats)
      assert formatted =~ "8/10 hits"
      assert formatted =~ "80.0%"
      assert formatted =~ "2 to fetch"
    end

    test "formats empty" do
      stats = %{hits: 0, misses: 0, total: 0}
      formatted = NPM.CacheStats.format(stats)
      assert formatted =~ "0/0 hits"
    end
  end

  describe "format_size" do
    test "bytes" do
      assert "500 B" = NPM.CacheStats.format_size(500)
    end

    test "kilobytes" do
      assert NPM.CacheStats.format_size(5120) =~ "KB"
    end

    test "megabytes" do
      assert NPM.CacheStats.format_size(5_242_880) =~ "MB"
    end
  end

  describe "disk_size" do
    test "returns integer" do
      size = NPM.CacheStats.disk_size()
      assert is_integer(size)
    end
  end

  describe "list_cached" do
    test "returns list" do
      cached = NPM.CacheStats.list_cached()
      assert is_list(cached)
    end
  end
end
