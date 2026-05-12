defmodule NPM.Package.KeywordsTest do
  use ExUnit.Case, async: true

  @packages [
    %{"name" => "react", "keywords" => ["ui", "framework", "virtual-dom"]},
    %{"name" => "vue", "keywords" => ["ui", "framework", "reactive"]},
    %{"name" => "lodash", "keywords" => ["utility", "modules"]}
  ]

  describe "extract" do
    test "extracts keywords array" do
      assert ["ui", "framework"] =
               NPM.Package.Keywords.extract(%{"keywords" => ["ui", "framework"]})
    end

    test "empty for no keywords" do
      assert [] = NPM.Package.Keywords.extract(%{"name" => "pkg"})
    end

    test "empty for non-list keywords" do
      assert [] = NPM.Package.Keywords.extract(%{"keywords" => "not-a-list"})
    end
  end

  describe "most_common" do
    test "returns most frequent keywords" do
      common = NPM.Package.Keywords.most_common(@packages, 3)
      assert {"ui", 2} in common
      assert {"framework", 2} in common
    end

    test "empty for no packages" do
      assert [] = NPM.Package.Keywords.most_common([], 5)
    end
  end

  describe "search" do
    test "finds packages by keyword" do
      packages = [
        {"react", hd(@packages)},
        {"vue", Enum.at(@packages, 1)},
        {"lodash", Enum.at(@packages, 2)}
      ]

      result = NPM.Package.Keywords.search(packages, "ui")
      assert "react" in result
      assert "vue" in result
      refute "lodash" in result
    end

    test "case insensitive search" do
      packages = [{"react", %{"keywords" => ["UI"]}}]
      assert ["react"] = NPM.Package.Keywords.search(packages, "ui")
    end

    test "no matches" do
      packages = [{"react", hd(@packages)}]
      assert [] = NPM.Package.Keywords.search(packages, "nonexistent")
    end
  end

  describe "group_by_keyword" do
    test "groups packages" do
      packages = [
        {"react", %{"keywords" => ["ui"]}},
        {"vue", %{"keywords" => ["ui", "reactive"]}},
        {"rxjs", %{"keywords" => ["reactive"]}}
      ]

      groups = NPM.Package.Keywords.group_by_keyword(packages)
      assert length(groups["ui"]) == 2
      assert length(groups["reactive"]) == 2
    end
  end

  describe "unique_count" do
    test "counts unique keywords" do
      assert 6 = NPM.Package.Keywords.unique_count(@packages)
    end

    test "zero for no packages" do
      assert 0 = NPM.Package.Keywords.unique_count([])
    end
  end
end
