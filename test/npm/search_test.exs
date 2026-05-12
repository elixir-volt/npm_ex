defmodule NPM.SearchTest do
  use ExUnit.Case, async: true

  describe "score" do
    test "exact name match scores 1.0" do
      pkg = %{name: "lodash", version: "4.17.21", description: "Utility lib", keywords: []}
      assert 1.0 = NPM.Search.score(pkg, "lodash")
    end

    test "prefix match scores 0.8" do
      pkg = %{name: "lodash", version: "4.17.21", description: nil, keywords: []}
      assert 0.8 = NPM.Search.score(pkg, "lod")
    end

    test "contains match scores 0.6" do
      pkg = %{name: "is-number", version: "7.0.0", description: nil, keywords: []}
      assert 0.6 = NPM.Search.score(pkg, "number")
    end

    test "keyword match scores 0.4" do
      pkg = %{name: "chalk", version: "5.0.0", description: nil, keywords: ["color", "terminal"]}
      assert 0.4 = NPM.Search.score(pkg, "color")
    end

    test "description match scores 0.2" do
      pkg = %{name: "pkg", version: "1.0.0", description: "A utility for color", keywords: []}
      assert 0.2 = NPM.Search.score(pkg, "color")
    end

    test "no match scores 0.0" do
      pkg = %{name: "react", version: "18.0.0", description: "UI library", keywords: []}
      assert NPM.Search.score(pkg, "zzz-nonexistent") == 0.0
    end

    test "case insensitive" do
      pkg = %{name: "React", version: "18.0.0", description: nil, keywords: []}
      assert 1.0 = NPM.Search.score(pkg, "react")
    end
  end

  describe "search node_modules" do
    @tag :tmp_dir
    test "finds matching packages", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      File.mkdir_p!(Path.join(nm, "lodash"))
      File.mkdir_p!(Path.join(nm, "react"))

      File.write!(
        Path.join([nm, "lodash", "package.json"]),
        ~s({"name":"lodash","version":"4.17.21","description":"Utility library","keywords":["util"]})
      )

      File.write!(
        Path.join([nm, "react", "package.json"]),
        ~s({"name":"react","version":"18.2.0","description":"UI framework"})
      )

      results = NPM.Search.search(nm, "lodash")
      assert length(results) == 1
      assert hd(results).name == "lodash"
    end

    @tag :tmp_dir
    test "returns empty for no matches", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      File.mkdir_p!(Path.join(nm, "react"))

      File.write!(
        Path.join([nm, "react", "package.json"]),
        ~s({"name":"react","version":"18.2.0"})
      )

      results = NPM.Search.search(nm, "zzz-nonexistent")
      assert results == []
    end

    @tag :tmp_dir
    test "matches by keyword", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      File.mkdir_p!(Path.join(nm, "chalk"))

      File.write!(
        Path.join([nm, "chalk", "package.json"]),
        ~s({"name":"chalk","version":"5.0.0","keywords":["color","terminal"]})
      )

      results = NPM.Search.search(nm, "color")
      assert length(results) == 1
    end

    test "nonexistent directory" do
      assert [] =
               NPM.Search.search("/tmp/nonexistent_#{System.unique_integer([:positive])}", "test")
    end
  end

  describe "filter_by_score" do
    test "filters below threshold" do
      results = [
        %{name: "a", version: "1.0.0", description: nil, keywords: [], score: 1.0},
        %{name: "b", version: "1.0.0", description: nil, keywords: [], score: 0.3},
        %{name: "c", version: "1.0.0", description: nil, keywords: [], score: 0.6}
      ]

      filtered = NPM.Search.filter_by_score(results, 0.5)
      assert length(filtered) == 2
      names = Enum.map(filtered, & &1.name)
      assert "a" in names
      assert "c" in names
    end
  end
end
