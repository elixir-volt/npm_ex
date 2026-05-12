defmodule NPM.Package.RepositoryTest do
  use ExUnit.Case, async: true

  alias NPM.Package.Repository

  @github_pkg %{
    "repository" => %{
      "type" => "git",
      "url" => "git+https://github.com/lodash/lodash.git"
    }
  }

  @monorepo_pkg %{
    "repository" => %{
      "type" => "git",
      "url" => "https://github.com/babel/babel.git",
      "directory" => "packages/babel-core"
    }
  }

  describe "extract" do
    test "extracts object repository" do
      repo = Repository.extract(@github_pkg)
      assert repo.type == "git"
      assert repo.url == "https://github.com/lodash/lodash"
    end

    test "extracts string shorthand" do
      data = %{"repository" => "github:user/repo"}
      repo = Repository.extract(data)
      assert repo.url == "https://github.com/user/repo"
    end

    test "extracts bare user/repo" do
      data = %{"repository" => "user/repo"}
      repo = Repository.extract(data)
      assert repo.url == "https://github.com/user/repo"
    end

    test "extracts monorepo with directory" do
      repo = Repository.extract(@monorepo_pkg)
      assert repo.directory == "packages/babel-core"
    end

    test "nil for missing repository" do
      assert nil == Repository.extract(%{})
    end
  end

  describe "browse_url" do
    test "returns clean URL" do
      assert "https://github.com/lodash/lodash" = Repository.browse_url(@github_pkg)
    end

    test "includes directory for monorepo" do
      url = Repository.browse_url(@monorepo_pkg)
      assert url =~ "packages/babel-core"
    end

    test "nil for no repository" do
      assert nil == Repository.browse_url(%{})
    end
  end

  describe "clone_url" do
    test "returns URL with .git suffix" do
      url = Repository.clone_url(@github_pkg)
      assert String.ends_with?(url, ".git")
    end

    test "nil for no repository" do
      assert nil == Repository.clone_url(%{})
    end
  end

  describe "provider" do
    test "detects github" do
      assert :github = Repository.provider(@github_pkg)
    end

    test "detects gitlab" do
      data = %{"repository" => %{"type" => "git", "url" => "https://gitlab.com/user/repo"}}
      assert :gitlab = Repository.provider(data)
    end

    test "detects bitbucket" do
      data = %{"repository" => %{"type" => "git", "url" => "https://bitbucket.org/user/repo"}}
      assert :bitbucket = Repository.provider(data)
    end

    test "other for unknown host" do
      data = %{"repository" => %{"type" => "git", "url" => "https://custom.host/repo"}}
      assert :other = Repository.provider(data)
    end

    test "nil for no repository" do
      assert nil == Repository.provider(%{})
    end
  end

  describe "has_repository?" do
    test "true with repository" do
      assert Repository.has_repository?(@github_pkg)
    end

    test "false without repository" do
      refute Repository.has_repository?(%{})
    end
  end
end
