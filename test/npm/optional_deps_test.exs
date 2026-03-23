defmodule NPM.OptionalDepsTest do
  use ExUnit.Case, async: true

  @pkg_data %{
    "dependencies" => %{"react" => "^18.0.0"},
    "optionalDependencies" => %{
      "fsevents" => "~2.3.2",
      "@esbuild/darwin-arm64" => "0.19.0",
      "bufferutil" => "^4.0.1"
    }
  }

  describe "extract" do
    test "extracts optional deps" do
      deps = NPM.OptionalDeps.extract(@pkg_data)
      assert map_size(deps) == 3
      assert deps["fsevents"] == "~2.3.2"
    end

    test "empty when no optional deps" do
      assert %{} = NPM.OptionalDeps.extract(%{"dependencies" => %{}})
    end

    test "empty for missing field" do
      assert %{} = NPM.OptionalDeps.extract(%{})
    end
  end

  describe "optional?" do
    test "true for optional dependency" do
      assert NPM.OptionalDeps.optional?("fsevents", @pkg_data)
    end

    test "false for regular dependency" do
      refute NPM.OptionalDeps.optional?("react", @pkg_data)
    end

    test "false for unknown package" do
      refute NPM.OptionalDeps.optional?("unknown", @pkg_data)
    end
  end

  describe "check_installed" do
    test "separates installed from missing" do
      lockfile = %{
        "fsevents" => %{
          version: "2.3.3",
          integrity: "",
          tarball: "",
          dependencies: %{},
          optional_dependencies: %{}
        },
        "react" => %{
          version: "18.2.0",
          integrity: "",
          tarball: "",
          dependencies: %{},
          optional_dependencies: %{}
        }
      }

      result = NPM.OptionalDeps.check_installed(@pkg_data, lockfile)
      assert "fsevents" in result.installed
      assert "bufferutil" in result.missing
      assert "@esbuild/darwin-arm64" in result.missing
    end

    test "all missing when lockfile is empty" do
      result = NPM.OptionalDeps.check_installed(@pkg_data, %{})
      assert length(result.missing) == 3
      assert result.installed == []
    end

    test "all installed" do
      lockfile = %{
        "fsevents" => %{
          version: "2.3.3",
          integrity: "",
          tarball: "",
          dependencies: %{},
          optional_dependencies: %{}
        },
        "@esbuild/darwin-arm64" => %{
          version: "0.19.0",
          integrity: "",
          tarball: "",
          dependencies: %{},
          optional_dependencies: %{}
        },
        "bufferutil" => %{
          version: "4.0.8",
          integrity: "",
          tarball: "",
          dependencies: %{},
          optional_dependencies: %{}
        }
      }

      result = NPM.OptionalDeps.check_installed(@pkg_data, lockfile)
      assert length(result.installed) == 3
      assert result.missing == []
    end
  end

  describe "summary" do
    test "returns count and names" do
      s = NPM.OptionalDeps.summary(@pkg_data)
      assert s.total == 3
      assert "fsevents" in s.names
    end

    test "empty when no optional deps" do
      s = NPM.OptionalDeps.summary(%{})
      assert s.total == 0
      assert s.names == []
    end
  end

  describe "for_platform" do
    test "returns deps for platform" do
      result = NPM.OptionalDeps.for_platform(@pkg_data, "darwin", "arm64")
      assert map_size(result) > 0
    end
  end
end
