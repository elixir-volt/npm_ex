defmodule NPM.SizeTest do
  use ExUnit.Case, async: true

  describe "analyze" do
    @tag :tmp_dir
    test "returns size info per package", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      pkg = Path.join(nm, "my-pkg")
      File.mkdir_p!(pkg)
      File.write!(Path.join(pkg, "package.json"), ~s({"name":"my-pkg","version":"1.0.0"}))
      File.write!(Path.join(pkg, "index.js"), String.duplicate("x", 500))

      entries = NPM.Size.analyze(nm)
      assert length(entries) == 1
      assert hd(entries).name == "my-pkg"
      assert hd(entries).size > 0
      assert hd(entries).file_count == 2
    end

    @tag :tmp_dir
    test "sorted by size descending", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")

      small = Path.join(nm, "small")
      big = Path.join(nm, "big")
      File.mkdir_p!(small)
      File.mkdir_p!(big)
      File.write!(Path.join(small, "package.json"), ~s({"name":"small"}))
      File.write!(Path.join(big, "package.json"), ~s({"name":"big"}))
      File.write!(Path.join(big, "data.bin"), String.duplicate("x", 10_000))

      entries = NPM.Size.analyze(nm)
      assert hd(entries).name == "big"
    end

    @tag :tmp_dir
    test "handles scoped packages", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      scoped = Path.join([nm, "@scope", "pkg"])
      File.mkdir_p!(scoped)
      File.write!(Path.join(scoped, "package.json"), ~s({"name":"@scope/pkg","version":"2.0.0"}))

      entries = NPM.Size.analyze(nm)
      assert length(entries) == 1
      assert hd(entries).name == "@scope/pkg"
    end

    test "nonexistent directory returns empty" do
      assert [] = NPM.Size.analyze("/tmp/nonexistent_#{System.unique_integer([:positive])}")
    end
  end

  describe "top" do
    @tag :tmp_dir
    test "returns top N largest", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")

      for i <- 1..5 do
        pkg = Path.join(nm, "pkg-#{i}")
        File.mkdir_p!(pkg)
        File.write!(Path.join(pkg, "package.json"), ~s({"name":"pkg-#{i}"}))
        File.write!(Path.join(pkg, "data.bin"), String.duplicate("x", i * 100))
      end

      top3 = NPM.Size.top(nm, 3)
      assert length(top3) == 3
    end
  end

  describe "total_size" do
    test "sums all sizes" do
      entries = [
        %{name: "a", version: "1.0.0", size: 1000, file_count: 5},
        %{name: "b", version: "1.0.0", size: 2000, file_count: 10}
      ]

      assert 3000 = NPM.Size.total_size(entries)
    end

    test "empty returns 0" do
      assert 0 = NPM.Size.total_size([])
    end
  end

  describe "total_files" do
    test "sums all file counts" do
      entries = [
        %{name: "a", version: "1.0.0", size: 1000, file_count: 5},
        %{name: "b", version: "1.0.0", size: 2000, file_count: 10}
      ]

      assert 15 = NPM.Size.total_files(entries)
    end
  end

  describe "format_size" do
    test "bytes" do
      assert "100 B" = NPM.Size.format_size(100)
    end

    test "kilobytes" do
      assert NPM.Size.format_size(2048) =~ "KB"
    end

    test "megabytes" do
      assert NPM.Size.format_size(5_242_880) =~ "MB"
    end

    test "gigabytes" do
      assert NPM.Size.format_size(2_147_483_648) =~ "GB"
    end

    test "zero" do
      assert "0 B" = NPM.Size.format_size(0)
    end
  end

  describe "summary" do
    test "aggregates stats" do
      entries = [
        %{name: "a", version: "1.0.0", size: 1024, file_count: 5},
        %{name: "b", version: "1.0.0", size: 2048, file_count: 10}
      ]

      s = NPM.Size.summary(entries)
      assert s.package_count == 2
      assert s.total_size == 3072
      assert s.total_files == 15
      assert s.formatted_size =~ "KB"
    end
  end
end
