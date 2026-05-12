defmodule NPM.Dependency.OutdatedUpdateTest do
  use ExUnit.Case, async: true

  describe "update_type" do
    test "major update" do
      assert :major = NPM.Dependency.Outdated.update_type("3.0.0", "4.0.0")
    end

    test "minor update" do
      assert :minor = NPM.Dependency.Outdated.update_type("4.17.0", "4.18.0")
    end

    test "patch update" do
      assert :patch = NPM.Dependency.Outdated.update_type("4.17.20", "4.17.21")
    end

    test "current" do
      assert :current = NPM.Dependency.Outdated.update_type("4.17.21", "4.17.21")
    end
  end

  describe "compute" do
    test "computes updates" do
      packages = [
        {"lodash", "4.17.20", "4.17.21"},
        {"express", "3.0.0", "4.18.2"},
        {"react", "18.2.0", "18.2.0"}
      ]

      updates = NPM.Dependency.Outdated.compute(packages)
      assert length(updates) == 2
      refute Enum.any?(updates, &(&1.name == "react"))
    end

    test "sorted by type then name" do
      packages = [
        {"b-pkg", "1.0.0", "1.0.1"},
        {"a-pkg", "1.0.0", "2.0.0"}
      ]

      updates = NPM.Dependency.Outdated.compute(packages)
      assert hd(updates).name == "a-pkg"
    end

    test "empty for all current" do
      assert [] = NPM.Dependency.Outdated.compute([{"a", "1.0.0", "1.0.0"}])
    end
  end

  describe "summary" do
    test "counts by type" do
      updates = [
        %{name: "a", current: "1.0", latest: "2.0", type: :major},
        %{name: "b", current: "1.0", latest: "1.1", type: :minor},
        %{name: "c", current: "1.0", latest: "1.0.1", type: :patch}
      ]

      sum = NPM.Dependency.Outdated.summary(updates)
      assert sum.major == 1
      assert sum.minor == 1
      assert sum.patch == 1
      assert sum.total == 3
    end
  end

  describe "format" do
    test "formats updates" do
      updates = [%{name: "lodash", current: "4.17.20", latest: "4.17.21", type: :patch}]
      formatted = NPM.Dependency.Outdated.format(updates)
      assert formatted =~ "lodash: 4.17.20 → 4.17.21 (patch)"
    end

    test "all up to date" do
      assert "All packages are up to date." = NPM.Dependency.Outdated.format([])
    end
  end
end
