defmodule NPM.FundingTest do
  use ExUnit.Case, async: true

  describe "extract" do
    test "string URL" do
      data = %{"funding" => "https://github.com/sponsors/user"}
      entries = NPM.Funding.extract(data)
      assert length(entries) == 1
      assert hd(entries)["url"] == "https://github.com/sponsors/user"
    end

    test "object with url and type" do
      data = %{
        "funding" => %{"url" => "https://opencollective.com/pkg", "type" => "opencollective"}
      }

      entries = NPM.Funding.extract(data)
      assert hd(entries)["type"] == "opencollective"
    end

    test "array of mixed funders" do
      data = %{
        "funding" => [
          "https://github.com/sponsors/user",
          %{"url" => "https://opencollective.com/pkg", "type" => "opencollective"}
        ]
      }

      entries = NPM.Funding.extract(data)
      assert length(entries) == 2
    end

    test "empty for no funding" do
      assert [] = NPM.Funding.extract(%{"name" => "pkg"})
    end
  end

  describe "urls" do
    test "extracts all URLs" do
      data = %{
        "funding" => [
          %{"url" => "https://a.com"},
          %{"url" => "https://b.com"}
        ]
      }

      urls = NPM.Funding.urls(data)
      assert length(urls) == 2
      assert "https://a.com" in urls
    end
  end

  describe "types" do
    test "extracts unique types" do
      data = %{
        "funding" => [
          %{"url" => "https://a.com", "type" => "github"},
          %{"url" => "https://b.com", "type" => "opencollective"},
          %{"url" => "https://c.com", "type" => "github"}
        ]
      }

      types = NPM.Funding.types(data)
      assert "github" in types
      assert "opencollective" in types
      assert length(types) == 2
    end
  end

  describe "has_funding?" do
    test "true with funding" do
      assert NPM.Funding.has_funding?(%{"funding" => "https://a.com"})
    end

    test "false without funding" do
      refute NPM.Funding.has_funding?(%{})
    end
  end

  describe "funding_stats" do
    test "computes stats across packages" do
      packages = [
        %{"funding" => %{"url" => "https://a.com", "type" => "github"}},
        %{"funding" => %{"url" => "https://b.com", "type" => "opencollective"}},
        %{"name" => "no-funding"}
      ]

      stats = NPM.Funding.funding_stats(packages)
      assert stats.total == 3
      assert stats.with_funding == 2
      assert stats.without_funding == 1
    end

    test "empty packages" do
      stats = NPM.Funding.funding_stats([])
      assert stats.total == 0
    end
  end
end
