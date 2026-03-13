defmodule NPM.FundTest do
  use ExUnit.Case, async: true

  describe "extract funding from string" do
    test "string URL" do
      data = %{
        "name" => "pkg",
        "version" => "1.0.0",
        "funding" => "https://opencollective.com/pkg"
      }

      [entry] = NPM.Fund.extract(data)
      assert entry.package == "pkg"
      assert entry.url == "https://opencollective.com/pkg"
      assert entry.type == nil
    end
  end

  describe "extract funding from map" do
    test "map with type and url" do
      data = %{
        "name" => "express",
        "version" => "4.21.2",
        "funding" => %{"type" => "opencollective", "url" => "https://opencollective.com/express"}
      }

      [entry] = NPM.Fund.extract(data)
      assert entry.type == "opencollective"
      assert entry.url == "https://opencollective.com/express"
    end
  end

  describe "extract funding from list" do
    test "multiple funding sources" do
      data = %{
        "name" => "webpack",
        "version" => "5.0.0",
        "funding" => [
          %{"type" => "opencollective", "url" => "https://opencollective.com/webpack"},
          "https://github.com/sponsors/webpack"
        ]
      }

      entries = NPM.Fund.extract(data)
      assert length(entries) == 2
      urls = Enum.map(entries, & &1.url)
      assert "https://opencollective.com/webpack" in urls
      assert "https://github.com/sponsors/webpack" in urls
    end
  end

  describe "extract with no funding" do
    test "returns empty list" do
      assert [] = NPM.Fund.extract(%{"name" => "pkg", "version" => "1.0.0"})
    end

    test "returns empty for missing name" do
      assert [] = NPM.Fund.extract(%{})
    end
  end

  describe "collect from node_modules" do
    @tag :tmp_dir
    test "reads funding from packages", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      File.mkdir_p!(Path.join(nm, "funded-pkg"))

      File.write!(
        Path.join([nm, "funded-pkg", "package.json"]),
        ~s({"name":"funded-pkg","version":"1.0.0","funding":"https://example.com/fund"})
      )

      entries = NPM.Fund.collect(nm)
      assert length(entries) == 1
      assert hd(entries).url == "https://example.com/fund"
    end

    @tag :tmp_dir
    test "skips packages without funding", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      File.mkdir_p!(Path.join(nm, "no-fund"))

      File.write!(
        Path.join([nm, "no-fund", "package.json"]),
        ~s({"name":"no-fund","version":"1.0.0"})
      )

      assert [] = NPM.Fund.collect(nm)
    end

    test "returns empty for nonexistent directory" do
      assert [] = NPM.Fund.collect("/tmp/nonexistent_#{System.unique_integer([:positive])}")
    end
  end

  describe "group_by_url" do
    test "groups packages by funding URL" do
      entries = [
        %{package: "a", version: "1.0.0", type: nil, url: "https://opencollective.com/x"},
        %{package: "b", version: "1.0.0", type: nil, url: "https://opencollective.com/x"},
        %{package: "c", version: "1.0.0", type: nil, url: "https://github.com/sponsors/y"}
      ]

      grouped = NPM.Fund.group_by_url(entries)
      assert length(grouped["https://opencollective.com/x"]) == 2
      assert length(grouped["https://github.com/sponsors/y"]) == 1
    end
  end

  describe "summary" do
    test "counts packages, urls, and types" do
      entries = [
        %{package: "a", version: "1.0.0", type: "opencollective", url: "https://oc.com/a"},
        %{package: "b", version: "1.0.0", type: "github", url: "https://gh.com/b"},
        %{package: "c", version: "1.0.0", type: "opencollective", url: "https://oc.com/a"}
      ]

      s = NPM.Fund.summary(entries)
      assert s.packages_with_funding == 3
      assert s.unique_urls == 2
      assert s.types == ["github", "opencollective"]
    end

    test "empty list" do
      s = NPM.Fund.summary([])
      assert s.packages_with_funding == 0
      assert s.unique_urls == 0
    end
  end

  describe "extract invalid funding structure" do
    test "funding as number is ignored" do
      data = %{"name" => "pkg", "version" => "1.0.0", "funding" => 42}
      assert [] = NPM.Fund.extract(data)
    end

    test "list with mixed valid and invalid entries" do
      data = %{
        "name" => "pkg",
        "version" => "1.0.0",
        "funding" => [
          "https://valid.com",
          42,
          %{"url" => "https://also-valid.com", "type" => "github"}
        ]
      }

      entries = NPM.Fund.extract(data)
      assert length(entries) == 2
    end
  end

  describe "group_by_url empty list" do
    test "returns empty map" do
      assert %{} = NPM.Fund.group_by_url([])
    end
  end
end
