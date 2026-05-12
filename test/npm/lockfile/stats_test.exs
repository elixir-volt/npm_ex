defmodule NPM.Lockfile.StatsTest do
  use ExUnit.Case, async: true

  alias NPM.Lockfile.Stats

  @lockfile %{
    "express" => %{version: "4.18.2", integrity: "sha512-abc", dependencies: %{"debug" => "^4.0"}},
    "debug" => %{version: "4.3.4", integrity: "sha512-def", dependencies: %{}},
    "lodash" => %{version: "4.17.21", integrity: "", dependencies: %{}}
  }

  describe "compute" do
    @tag :tmp_dir
    test "reads file stats", %{tmp_dir: dir} do
      path = Path.join(dir, "test.lock")
      File.write!(path, "some content here")
      assert {:ok, stats} = Stats.compute(path)
      assert stats.size > 0
      assert is_binary(stats.size_human)
    end

    test "error for missing file" do
      assert {:error, :enoent} =
               Stats.compute("/tmp/nonexistent_lock_#{System.unique_integer([:positive])}")
    end
  end

  describe "content_stats" do
    test "computes package stats" do
      stats = Stats.content_stats(@lockfile)
      assert stats.total_packages == 3
      assert stats.with_integrity == 2
      assert stats.with_deps == 1
      assert stats.leaf_packages == 2
    end

    test "empty lockfile" do
      stats = Stats.content_stats(%{})
      assert stats.total_packages == 0
      assert stats.integrity_pct == 0.0
    end
  end

  describe "estimated_size" do
    test "estimates based on package count" do
      size = Stats.estimated_size(@lockfile)
      assert size == 150_000
    end
  end

  describe "format_size" do
    test "bytes" do
      assert "500 B" = Stats.format_size(500)
    end

    test "kilobytes" do
      assert "10.0 KB" = Stats.format_size(10_240)
    end

    test "megabytes" do
      assert "5.0 MB" = Stats.format_size(5_242_880)
    end
  end
end
