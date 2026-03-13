defmodule NPM.WhyTest do
  use ExUnit.Case, async: true

  @lockfile %{
    "express" => %{
      version: "4.21.2",
      integrity: "",
      tarball: "",
      dependencies: %{"ms" => "^2.0.0", "debug" => "^2.6.9"}
    },
    "debug" => %{
      version: "2.6.9",
      integrity: "",
      tarball: "",
      dependencies: %{"ms" => "^2.0.0"}
    },
    "ms" => %{version: "2.1.3", integrity: "", tarball: "", dependencies: %{}},
    "react" => %{version: "18.2.0", integrity: "", tarball: "", dependencies: %{}}
  }

  @root_deps %{"express" => "^4.0.0", "react" => "^18.0.0"}

  describe "explain direct dependency" do
    test "returns direct reason" do
      reasons = NPM.Why.explain("react", @lockfile, @root_deps)
      assert Enum.any?(reasons, & &1.direct)
      direct = Enum.find(reasons, & &1.direct)
      assert direct.path == ["react"]
      assert direct.range == "^18.0.0"
    end

    test "express is both direct and referenced" do
      reasons = NPM.Why.explain("express", @lockfile, @root_deps)
      assert Enum.any?(reasons, & &1.direct)
    end
  end

  describe "explain transitive dependency" do
    test "ms is required by express and debug" do
      reasons = NPM.Why.explain("ms", @lockfile, @root_deps)
      paths = Enum.map(reasons, & &1.path)

      assert Enum.any?(paths, fn path ->
               "express" in path and "ms" in path
             end)
    end

    test "debug is required by express" do
      reasons = NPM.Why.explain("debug", @lockfile, @root_deps)
      refute Enum.empty?(reasons)

      transitive = Enum.reject(reasons, & &1.direct)

      assert Enum.any?(transitive, fn r ->
               "express" in r.path
             end)
    end
  end

  describe "explain missing package" do
    test "returns empty for unknown package" do
      reasons = NPM.Why.explain("nonexistent", @lockfile, @root_deps)
      assert reasons == []
    end
  end

  describe "direct?" do
    test "true for root deps" do
      assert NPM.Why.direct?("express", @root_deps)
      assert NPM.Why.direct?("react", @root_deps)
    end

    test "false for transitive deps" do
      refute NPM.Why.direct?("ms", @root_deps)
      refute NPM.Why.direct?("debug", @root_deps)
    end
  end

  describe "dependents" do
    test "finds packages that depend on ms" do
      deps = NPM.Why.dependents("ms", @lockfile)
      assert "express" in deps
      assert "debug" in deps
    end

    test "no dependents for react" do
      assert [] = NPM.Why.dependents("react", @lockfile)
    end

    test "express depends on debug" do
      deps = NPM.Why.dependents("debug", @lockfile)
      assert "express" in deps
    end
  end

  describe "format_reasons" do
    test "formats direct dependency" do
      reasons = [%{path: ["react"], range: "^18.0.0", direct: true}]
      formatted = NPM.Why.format_reasons(reasons)
      assert formatted =~ "react"
      assert formatted =~ "direct dependency"
    end

    test "formats transitive dependency" do
      reasons = [%{path: ["express", "ms"], range: "^2.0.0", direct: false}]
      formatted = NPM.Why.format_reasons(reasons)
      assert formatted =~ "express → ms"
    end

    test "formats empty list" do
      assert NPM.Why.format_reasons([]) =~ "not installed"
    end
  end
end
