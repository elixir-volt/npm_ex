defmodule NPM.DiffTest do
  use ExUnit.Case, async: true

  describe "compare_files" do
    test "detects added files" do
      old = %{"a.js" => "hash1"}
      new = %{"a.js" => "hash1", "b.js" => "hash2"}

      changes = NPM.Diff.compare_files(old, new)
      assert Enum.any?(changes, &(&1.path == "b.js" and &1.type == :added))
    end

    test "detects removed files" do
      old = %{"a.js" => "hash1", "b.js" => "hash2"}
      new = %{"a.js" => "hash1"}

      changes = NPM.Diff.compare_files(old, new)
      assert Enum.any?(changes, &(&1.path == "b.js" and &1.type == :removed))
    end

    test "detects modified files" do
      old = %{"a.js" => "hash1"}
      new = %{"a.js" => "hash2"}

      changes = NPM.Diff.compare_files(old, new)
      assert Enum.any?(changes, &(&1.path == "a.js" and &1.type == :modified))
    end

    test "no changes for identical files" do
      files = %{"a.js" => "hash1", "b.js" => "hash2"}
      assert [] = NPM.Diff.compare_files(files, files)
    end

    test "empty to populated" do
      new = %{"a.js" => "h1", "b.js" => "h2"}
      changes = NPM.Diff.compare_files(%{}, new)
      assert length(changes) == 2
      assert Enum.all?(changes, &(&1.type == :added))
    end

    test "populated to empty" do
      old = %{"a.js" => "h1", "b.js" => "h2"}
      changes = NPM.Diff.compare_files(old, %{})
      assert length(changes) == 2
      assert Enum.all?(changes, &(&1.type == :removed))
    end

    test "results are sorted by path" do
      old = %{"z.js" => "h1"}
      new = %{"a.js" => "h2", "m.js" => "h3", "z.js" => "h1"}

      changes = NPM.Diff.compare_files(old, new)
      paths = Enum.map(changes, & &1.path)
      assert paths == Enum.sort(paths)
    end
  end

  describe "file_hashes" do
    @tag :tmp_dir
    test "hashes files in directory", %{tmp_dir: dir} do
      File.write!(Path.join(dir, "index.js"), "console.log('hello')")
      File.write!(Path.join(dir, "package.json"), ~s({"name":"test"}))

      hashes = NPM.Diff.file_hashes(dir)
      assert Map.has_key?(hashes, "index.js")
      assert Map.has_key?(hashes, "package.json")
      assert is_binary(hashes["index.js"])
    end

    @tag :tmp_dir
    test "includes nested files", %{tmp_dir: dir} do
      File.mkdir_p!(Path.join(dir, "lib"))
      File.write!(Path.join([dir, "lib", "util.js"]), "module.exports = {}")

      hashes = NPM.Diff.file_hashes(dir)
      assert Map.has_key?(hashes, "lib/util.js")
    end

    @tag :tmp_dir
    test "same content produces same hash", %{tmp_dir: dir} do
      content = "identical content"
      File.write!(Path.join(dir, "a.txt"), content)
      File.write!(Path.join(dir, "b.txt"), content)

      hashes = NPM.Diff.file_hashes(dir)
      assert hashes["a.txt"] == hashes["b.txt"]
    end

    @tag :tmp_dir
    test "different content produces different hash", %{tmp_dir: dir} do
      File.write!(Path.join(dir, "a.txt"), "content a")
      File.write!(Path.join(dir, "b.txt"), "content b")

      hashes = NPM.Diff.file_hashes(dir)
      assert hashes["a.txt"] != hashes["b.txt"]
    end

    @tag :tmp_dir
    test "empty directory returns empty map", %{tmp_dir: dir} do
      sub = Path.join(dir, "empty")
      File.mkdir_p!(sub)
      assert %{} = NPM.Diff.file_hashes(sub)
    end
  end

  describe "summary" do
    test "counts by type" do
      changes = [
        %{path: "a.js", type: :added},
        %{path: "b.js", type: :added},
        %{path: "c.js", type: :removed},
        %{path: "d.js", type: :modified}
      ]

      s = NPM.Diff.summary(changes)
      assert s.added == 2
      assert s.removed == 1
      assert s.modified == 1
      assert s.total == 4
    end

    test "empty changes" do
      s = NPM.Diff.summary([])
      assert s.total == 0
    end
  end

  describe "format_changes" do
    test "formats with +/-/~ prefixes" do
      changes = [
        %{path: "new.js", type: :added},
        %{path: "old.js", type: :removed},
        %{path: "changed.js", type: :modified}
      ]

      formatted = NPM.Diff.format_changes(changes)
      assert formatted =~ "+ new.js"
      assert formatted =~ "- old.js"
      assert formatted =~ "~ changed.js"
    end

    test "empty changes" do
      assert NPM.Diff.format_changes([]) =~ "No changes"
    end
  end

  describe "compare_files mixed changes" do
    test "simultaneous add, remove, and modify" do
      old = %{"keep.js" => "h1", "remove.js" => "h2", "modify.js" => "h3"}
      new = %{"keep.js" => "h1", "add.js" => "h4", "modify.js" => "h5"}

      changes = NPM.Diff.compare_files(old, new)
      types = Map.new(changes, &{&1.path, &1.type})
      assert types["add.js"] == :added
      assert types["remove.js"] == :removed
      assert types["modify.js"] == :modified
      refute Map.has_key?(types, "keep.js")
    end
  end

  describe "file_hashes deeply nested" do
    @tag :tmp_dir
    test "handles 3-level nesting", %{tmp_dir: dir} do
      File.mkdir_p!(Path.join([dir, "a", "b", "c"]))
      File.write!(Path.join([dir, "a", "b", "c", "deep.txt"]), "deep content")

      hashes = NPM.Diff.file_hashes(dir)
      assert Map.has_key?(hashes, "a/b/c/deep.txt")
    end
  end
end
