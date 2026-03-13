defmodule NPM.DedupeTest do
  use ExUnit.Case, async: true

  describe "find_duplicates with no duplicates" do
    test "returns empty list" do
      lockfile = %{
        "a" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}},
        "b" => %{version: "2.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      assert [] = NPM.Dedupe.find_duplicates(lockfile)
    end
  end

  describe "find_duplicates with empty lockfile" do
    test "returns empty list" do
      assert [] = NPM.Dedupe.find_duplicates(%{})
    end
  end

  describe "find_duplicates with nested duplicates" do
    test "detects packages with different versions" do
      lockfile = %{
        "ms" => %{version: "2.1.3", integrity: "", tarball: "", dependencies: %{}},
        "express/node_modules/ms" => %{
          version: "2.0.0",
          integrity: "",
          tarball: "",
          dependencies: %{}
        }
      }

      dupes = NPM.Dedupe.find_duplicates(lockfile)
      assert length(dupes) == 1
      {name, versions} = hd(dupes)
      assert name == "ms"
      assert "2.0.0" in versions
      assert "2.1.3" in versions
    end
  end

  describe "find_duplicates ignores same-version entries" do
    test "same version in different locations is not a duplicate" do
      lockfile = %{
        "ms" => %{version: "2.1.3", integrity: "", tarball: "", dependencies: %{}},
        "express/node_modules/ms" => %{
          version: "2.1.3",
          integrity: "",
          tarball: "",
          dependencies: %{}
        }
      }

      assert [] = NPM.Dedupe.find_duplicates(lockfile)
    end
  end

  describe "savings_estimate" do
    test "no duplicates means zero savings" do
      lockfile = %{
        "a" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}},
        "b" => %{version: "2.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      result = NPM.Dedupe.savings_estimate(lockfile)
      assert result.packages == 2
      assert result.duplicates == 0
    end

    test "one duplicate pair means one saveable" do
      lockfile = %{
        "ms" => %{version: "2.1.3", integrity: "", tarball: "", dependencies: %{}},
        "express/node_modules/ms" => %{
          version: "2.0.0",
          integrity: "",
          tarball: "",
          dependencies: %{}
        }
      }

      result = NPM.Dedupe.savings_estimate(lockfile)
      assert result.duplicates == 1
    end
  end

  describe "best_shared_version" do
    test "finds version satisfying all dependents" do
      lockfile = %{
        "ms" => %{version: "2.1.3", integrity: "", tarball: "", dependencies: %{}},
        "debug" => %{
          version: "4.3.4",
          integrity: "",
          tarball: "",
          dependencies: %{"ms" => "^2.1.1"}
        },
        "express" => %{
          version: "4.21.2",
          integrity: "",
          tarball: "",
          dependencies: %{"ms" => "^2.0.0"}
        }
      }

      assert {:ok, "2.1.3"} = NPM.Dedupe.best_shared_version("ms", lockfile)
    end

    test "returns :no_common_version for missing package" do
      lockfile = %{
        "a" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      assert :no_common_version = NPM.Dedupe.best_shared_version("nonexistent", lockfile)
    end

    test "returns :no_common_version when version doesn't satisfy all ranges" do
      lockfile = %{
        "ms" => %{version: "2.0.0", integrity: "", tarball: "", dependencies: %{}},
        "debug" => %{
          version: "4.3.4",
          integrity: "",
          tarball: "",
          dependencies: %{"ms" => "^2.1.1"}
        }
      }

      assert :no_common_version = NPM.Dedupe.best_shared_version("ms", lockfile)
    end
  end

  describe "summary" do
    test "correct counts for clean lockfile" do
      lockfile = %{
        "a" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}},
        "b" => %{version: "2.0.0", integrity: "", tarball: "", dependencies: %{}},
        "c" => %{version: "3.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      s = NPM.Dedupe.summary(lockfile)
      assert s.total_packages == 3
      assert s.unique_packages == 3
      assert s.duplicate_groups == 0
      assert s.saveable == 0
    end

    test "correct counts for lockfile with duplicates" do
      lockfile = %{
        "ms" => %{version: "2.1.3", integrity: "", tarball: "", dependencies: %{}},
        "express/node_modules/ms" => %{
          version: "2.0.0",
          integrity: "",
          tarball: "",
          dependencies: %{}
        },
        "debug" => %{version: "4.3.4", integrity: "", tarball: "", dependencies: %{}}
      }

      s = NPM.Dedupe.summary(lockfile)
      assert s.total_packages == 3
      assert s.unique_packages == 2
      assert s.duplicate_groups == 1
      assert s.saveable == 1
    end

    test "empty lockfile" do
      s = NPM.Dedupe.summary(%{})
      assert s.total_packages == 0
      assert s.unique_packages == 0
      assert s.duplicate_groups == 0
    end
  end
end
