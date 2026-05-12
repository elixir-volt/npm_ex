defmodule NPM.Package.PeopleTest do
  use ExUnit.Case, async: true

  describe "author" do
    test "parses string author" do
      data = %{"author" => "John Doe <john@example.com>"}
      result = NPM.Package.People.author(data)
      assert result["name"] == "John Doe"
      assert result["email"] == "john@example.com"
    end

    test "returns map author as-is" do
      data = %{"author" => %{"name" => "Jane", "email" => "jane@test.com"}}
      result = NPM.Package.People.author(data)
      assert result["name"] == "Jane"
    end

    test "nil for no author" do
      assert nil == NPM.Package.People.author(%{})
    end
  end

  describe "contributors" do
    test "parses contributors list" do
      data = %{"contributors" => ["Alice <a@test.com>", "Bob <b@test.com>"]}
      result = NPM.Package.People.contributors(data)
      assert length(result) == 2
      assert hd(result)["name"] == "Alice"
    end

    test "handles map contributors" do
      data = %{"contributors" => [%{"name" => "Alice"}]}
      result = NPM.Package.People.contributors(data)
      assert hd(result)["name"] == "Alice"
    end

    test "falls back to maintainers" do
      data = %{"maintainers" => [%{"name" => "Eve"}]}
      result = NPM.Package.People.contributors(data)
      assert hd(result)["name"] == "Eve"
    end

    test "empty for no contributors" do
      assert [] = NPM.Package.People.contributors(%{})
    end
  end

  describe "all" do
    test "combines author and contributors" do
      data = %{
        "author" => "John <john@test.com>",
        "contributors" => ["Alice <a@test.com>"]
      }

      result = NPM.Package.People.all(data)
      assert length(result) == 2
    end

    test "just author when no contributors" do
      data = %{"author" => %{"name" => "Solo"}}
      result = NPM.Package.People.all(data)
      assert length(result) == 1
    end

    test "empty for no people" do
      assert [] = NPM.Package.People.all(%{})
    end
  end

  describe "unique_authors" do
    test "deduplicates authors" do
      packages = [
        %{"author" => %{"name" => "John"}},
        %{"author" => %{"name" => "John"}},
        %{"author" => %{"name" => "Jane"}}
      ]

      result = NPM.Package.People.unique_authors(packages)
      assert result == ["Jane", "John"]
    end

    test "empty when no authors" do
      assert [] = NPM.Package.People.unique_authors([%{}, %{}])
    end
  end

  describe "has_author?" do
    test "true with author" do
      assert NPM.Package.People.has_author?(%{"author" => "John"})
    end

    test "false without author" do
      refute NPM.Package.People.has_author?(%{})
    end
  end
end
