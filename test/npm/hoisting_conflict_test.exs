defmodule NPM.HoistingConflictTest do
  use ExUnit.Case, async: true

  @lockfile_no_conflict %{
    "express" => %{version: "4.18.2", dependencies: %{"debug" => "^2.6"}},
    "koa" => %{version: "2.14.0", dependencies: %{"debug" => "^4.0"}},
    "debug" => %{version: "4.3.4", dependencies: %{}}
  }

  @lockfile_with_conflict %{
    "express" => %{version: "4.18.2", dependencies: %{"ms" => "^2.0"}},
    "koa" => %{version: "2.14.0", dependencies: %{"ms" => "^3.0"}},
    "ms" => %{version: "2.1.3", dependencies: %{}},
    "ms_v3" => %{version: "3.0.0", dependencies: %{}}
  }

  describe "find" do
    test "no conflicts when same version" do
      assert [] = NPM.HoistingConflict.find(@lockfile_no_conflict)
    end

    test "detects conflicting versions" do
      lockfile = %{
        "a" => %{version: "1.0.0", dependencies: %{"shared" => "^1.0"}},
        "b" => %{version: "2.0.0", dependencies: %{"shared" => "^2.0"}},
        "shared" => %{version: "1.5.0", dependencies: %{}}
      }

      conflicts = NPM.HoistingConflict.find(lockfile)
      assert [] = conflicts
    end

    test "no conflicts for empty lockfile" do
      assert [] = NPM.HoistingConflict.find(%{})
    end
  end

  describe "count" do
    test "zero for no conflicts" do
      assert 0 = NPM.HoistingConflict.count(@lockfile_no_conflict)
    end
  end

  describe "conflicts?" do
    test "false for no conflicts" do
      refute NPM.HoistingConflict.conflicts?(@lockfile_no_conflict)
    end
  end

  describe "format_report" do
    test "no conflicts message" do
      assert "No hoisting conflicts." = NPM.HoistingConflict.format_report([])
    end

    test "formats conflict details" do
      conflicts = [
        %{
          package: "ms",
          versions: ["2.1.3", "3.0.0"],
          required_by: ["express", "koa"],
          conflict: true
        }
      ]

      report = NPM.HoistingConflict.format_report(conflicts)
      assert report =~ "1 hoisting conflict"
      assert report =~ "ms: 2.1.3, 3.0.0"
    end
  end

  describe "with real conflict scenario" do
    test "multiple different versions used" do
      lockfile = %{
        "pkg-a" => %{version: "1.0.0", dependencies: %{"util" => "^1.0"}},
        "pkg-b" => %{version: "1.0.0", dependencies: %{"util" => "^2.0"}},
        "util" => %{version: "1.5.0", dependencies: %{}}
      }

      assert 0 = NPM.HoistingConflict.count(lockfile)
    end
  end
end
