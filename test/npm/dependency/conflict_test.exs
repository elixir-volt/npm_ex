defmodule NPM.Dependency.ConflictTest do
  use ExUnit.Case, async: true

  alias NPM.Dependency.Conflict

  @conflicting %{
    "dependencies" => %{"lodash" => "^4.17.0"},
    "devDependencies" => %{"lodash" => "^3.10.0", "jest" => "^29.0"},
    "peerDependencies" => %{"react" => "^18.0"}
  }

  @no_conflict %{
    "dependencies" => %{"express" => "^4.18"},
    "devDependencies" => %{"jest" => "^29.0"}
  }

  describe "find" do
    test "detects conflicting ranges" do
      conflicts = Conflict.find(@conflicting)
      assert length(conflicts) == 1
      assert hd(conflicts).name == "lodash"
      assert length(hd(conflicts).ranges) == 2
    end

    test "no conflicts when ranges match" do
      data = %{
        "dependencies" => %{"lodash" => "^4.17.0"},
        "devDependencies" => %{"lodash" => "^4.17.0"}
      }

      assert [] = Conflict.find(data)
    end

    test "no conflicts when no overlap" do
      assert [] = Conflict.find(@no_conflict)
    end
  end

  describe "conflicts?" do
    test "true with conflicts" do
      assert Conflict.conflicts?(@conflicting)
    end

    test "false without" do
      refute Conflict.conflicts?(@no_conflict)
    end
  end

  describe "count" do
    test "counts conflicts" do
      assert 1 = Conflict.count(@conflicting)
    end
  end

  describe "duplicated" do
    test "finds packages in multiple groups" do
      duped = Conflict.duplicated(@conflicting)
      assert Enum.any?(duped, &(&1.name == "lodash"))
    end

    test "includes same-range duplicates" do
      data = %{
        "dependencies" => %{"lodash" => "^4.17.0"},
        "devDependencies" => %{"lodash" => "^4.17.0"}
      }

      duped = Conflict.duplicated(data)
      assert length(duped) == 1
    end

    test "empty when no duplication" do
      assert [] = Conflict.duplicated(@no_conflict)
    end
  end

  describe "format" do
    test "no conflicts message" do
      assert "No version conflicts." = Conflict.format([])
    end

    test "formats conflict details" do
      conflicts = Conflict.find(@conflicting)
      formatted = Conflict.format(conflicts)
      assert formatted =~ "lodash"
      assert formatted =~ "dependencies"
      assert formatted =~ "devDependencies"
    end
  end
end
