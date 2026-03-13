defmodule NPM.PublishTest do
  use ExUnit.Case, async: true

  @complete_pkg %{
    "name" => "my-pkg",
    "version" => "1.0.0",
    "description" => "A great package",
    "license" => "MIT",
    "repository" => %{"url" => "https://github.com/user/pkg"},
    "keywords" => ["utility"]
  }

  describe "check" do
    test "complete package is ok" do
      assert {:ok, []} = NPM.Publish.check(@complete_pkg)
    end

    test "missing name is an error" do
      pkg = Map.delete(@complete_pkg, "name")
      assert {:error, errors} = NPM.Publish.check(pkg)
      assert Enum.any?(errors, &String.contains?(&1, "name"))
    end

    test "missing version is an error" do
      pkg = Map.delete(@complete_pkg, "version")
      assert {:error, errors} = NPM.Publish.check(pkg)
      assert Enum.any?(errors, &String.contains?(&1, "version"))
    end

    test "missing description is a warning" do
      pkg = Map.delete(@complete_pkg, "description")
      assert {:ok, warnings} = NPM.Publish.check(pkg)
      assert Enum.any?(warnings, &String.contains?(&1, "description"))
    end

    test "empty name is an error" do
      pkg = Map.put(@complete_pkg, "name", "")
      assert {:error, _} = NPM.Publish.check(pkg)
    end
  end

  describe "check_required" do
    test "returns errors for missing fields" do
      errors = NPM.Publish.check_required(%{})
      assert length(errors) == 2
    end

    test "no errors for complete package" do
      assert [] = NPM.Publish.check_required(@complete_pkg)
    end
  end

  describe "check_recommended" do
    test "returns warnings for missing fields" do
      warnings = NPM.Publish.check_recommended(%{"name" => "pkg", "version" => "1.0.0"})
      assert Enum.any?(warnings, &String.contains?(&1, "description"))
      assert Enum.any?(warnings, &String.contains?(&1, "license"))
    end

    test "no warnings for complete package" do
      assert [] = NPM.Publish.check_recommended(@complete_pkg)
    end
  end

  describe "version_exists?" do
    test "true when version is in packument" do
      packument = %{versions: %{"1.0.0" => %{}, "1.1.0" => %{}}}
      assert NPM.Publish.version_exists?("pkg", "1.0.0", packument)
    end

    test "false for unpublished version" do
      packument = %{versions: %{"1.0.0" => %{}}}
      refute NPM.Publish.version_exists?("pkg", "2.0.0", packument)
    end

    test "false for empty packument" do
      refute NPM.Publish.version_exists?("pkg", "1.0.0", %{})
    end
  end

  describe "name_available?" do
    test "valid name is available" do
      assert NPM.Publish.name_available?("my-valid-pkg")
    end

    test "invalid name is not available" do
      refute NPM.Publish.name_available?("")
    end
  end

  describe "summary" do
    test "ready when no errors" do
      s = NPM.Publish.summary(@complete_pkg)
      assert s.ready
      assert s.errors == []
      assert s.name == "my-pkg"
      assert s.version == "1.0.0"
    end

    test "not ready with missing required fields" do
      s = NPM.Publish.summary(%{})
      refute s.ready
      assert s.errors != []
    end
  end
end
