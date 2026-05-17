defmodule NPM.FrozenInstallTest do
  @moduledoc """
  Regression tests for frozen lockfile install behavior.
  """

  use ExUnit.Case, async: true

  describe "frozen install: lockfile_matches?" do
    @tag :tmp_dir
    test "matching lockfile and package.json succeeds", %{tmp_dir: dir} do
      pkg_path = Path.join(dir, "package.json")
      lock_path = Path.join(dir, "npm.lock")

      File.write!(pkg_path, ~s({"dependencies": {"is-number": "^7.0.0"}}))

      lockfile = %{
        "is-number" => %{
          version: "7.0.0",
          integrity: "sha512-test",
          tarball: "https://registry.npmjs.org/is-number/-/is-number-7.0.0.tgz",
          dependencies: %{}
        }
      }

      NPM.Lockfile.write(lockfile, lock_path)
      {:ok, loaded} = NPM.Lockfile.read(lock_path)
      assert loaded["is-number"].version == "7.0.0"
    end

    @tag :tmp_dir
    test "lockfile with extra transitive deps is valid", %{tmp_dir: dir} do
      lock_path = Path.join(dir, "npm.lock")

      lockfile = %{
        "express" => %{
          version: "4.21.2",
          integrity: "sha512-a",
          tarball: "url",
          dependencies: %{"ms" => "^2.1"}
        },
        "ms" => %{
          version: "2.1.3",
          integrity: "sha512-b",
          tarball: "url2",
          dependencies: %{}
        }
      }

      NPM.Lockfile.write(lockfile, lock_path)
      {:ok, loaded} = NPM.Lockfile.read(lock_path)

      deps = %{"express" => "^4.0.0"}

      all_present =
        Enum.all?(deps, fn {name, _} -> Map.has_key?(loaded, name) end)

      assert all_present
    end
  end

  describe "frozen install: lockfile out of date" do
    @tag :tmp_dir
    test "detects missing package from lockfile", %{tmp_dir: dir} do
      lock_path = Path.join(dir, "npm.lock")

      NPM.Lockfile.write(%{}, lock_path)
      {:ok, loaded} = NPM.Lockfile.read(lock_path)

      deps = %{"react" => "^18.0.0"}
      all_present = Enum.all?(deps, fn {name, _} -> Map.has_key?(loaded, name) end)
      refute all_present
    end

    @tag :tmp_dir
    test "detects extra package in lockfile not in deps", %{tmp_dir: dir} do
      lock_path = Path.join(dir, "npm.lock")

      lockfile = %{
        "react" => %{version: "18.2.0", integrity: "", tarball: "", dependencies: %{}},
        "stale-pkg" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      NPM.Lockfile.write(lockfile, lock_path)
      {:ok, loaded} = NPM.Lockfile.read(lock_path)

      deps = %{"react" => "^18.0.0"}

      stale =
        loaded
        |> Map.keys()
        |> Enum.reject(fn name ->
          Map.has_key?(deps, name) or
            Enum.any?(loaded, fn {_, e} -> Map.has_key?(e.dependencies, name) end)
        end)

      assert "stale-pkg" in stale
    end
  end

  describe "frozen install: lockfile roundtrip integrity" do
    @tag :tmp_dir
    test "write then read preserves version and integrity", %{tmp_dir: dir} do
      lock_path = Path.join(dir, "npm.lock")

      lockfile = %{
        "lodash" => %{
          version: "4.17.21",
          integrity:
            "sha512-WpKJQqgLRvCiLpTAXzO3BSGlA2oYebCeS+jKKjA3Dg1iT7S5tLdQEHq+VqbLFeFEAtTwcECbzZyp7TMLxHI2A==",
          tarball: "https://registry.npmjs.org/lodash/-/lodash-4.17.21.tgz",
          dependencies: %{}
        }
      }

      NPM.Lockfile.write(lockfile, lock_path)
      {:ok, loaded} = NPM.Lockfile.read(lock_path)

      assert loaded["lodash"].version == "4.17.21"
      assert loaded["lodash"].integrity == lockfile["lodash"].integrity
      assert loaded["lodash"].tarball == lockfile["lodash"].tarball
    end

    @tag :tmp_dir
    test "lockfile with dependencies preserves dep map", %{tmp_dir: dir} do
      lock_path = Path.join(dir, "npm.lock")

      lockfile = %{
        "express" => %{
          version: "4.21.2",
          integrity: "sha512-x",
          tarball: "url",
          dependencies: %{"accepts" => "~1.3.8", "body-parser" => "1.20.3"}
        },
        "accepts" => %{
          version: "1.3.8",
          integrity: "sha512-y",
          tarball: "url2",
          dependencies: %{}
        },
        "body-parser" => %{
          version: "1.20.3",
          integrity: "sha512-z",
          tarball: "url3",
          dependencies: %{}
        }
      }

      NPM.Lockfile.write(lockfile, lock_path)
      {:ok, loaded} = NPM.Lockfile.read(lock_path)

      assert map_size(loaded["express"].dependencies) == 2
      assert loaded["express"].dependencies["accepts"] == "~1.3.8"
    end

    @tag :tmp_dir
    test "lockfile with optional dependencies is consistent", %{tmp_dir: dir} do
      lock_path = Path.join(dir, "npm.lock")

      lockfile = %{
        "@typescript/native-preview" => %{
          version: "7.0.0",
          integrity: "sha512-a",
          tarball: "url",
          dependencies: %{},
          optional_dependencies: %{
            "@typescript/native-preview-darwin-arm64" => "7.0.0",
            "@typescript/native-preview-linux-x64" => "7.0.0"
          }
        },
        "@typescript/native-preview-darwin-arm64" => %{
          version: "7.0.0",
          integrity: "sha512-b",
          tarball: "url2",
          dependencies: %{}
        },
        "@typescript/native-preview-linux-x64" => %{
          version: "7.0.0",
          integrity: "sha512-c",
          tarball: "url3",
          dependencies: %{}
        }
      }

      NPM.Lockfile.write(lockfile, lock_path)
      {:ok, loaded} = NPM.Lockfile.read(lock_path)

      deps = %{"@typescript/native-preview" => "^7.0.0"}

      all_accounted_for =
        Enum.all?(loaded, fn {name, _entry} ->
          Map.has_key?(deps, name) or
            Enum.any?(loaded, fn {_, e} ->
              Map.has_key?(e.dependencies, name) or
                Map.has_key?(Map.get(e, :optional_dependencies, %{}), name)
            end)
        end)

      assert all_accounted_for
    end
  end
end
