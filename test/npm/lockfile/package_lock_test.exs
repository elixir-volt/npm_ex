defmodule NPM.Lockfile.PackageLockTest do
  use ExUnit.Case, async: true

  alias NPM.Lockfile.PackageLock

  @v3_lock %{
    "name" => "my-app",
    "lockfileVersion" => 3,
    "packages" => %{
      "" => %{"dependencies" => %{"react" => "^18.0.0"}},
      "node_modules/react" => %{"version" => "18.2.0"},
      "node_modules/react-dom" => %{"version" => "18.2.0"}
    }
  }

  @v1_lock %{
    "name" => "legacy-app",
    "lockfileVersion" => 1,
    "dependencies" => %{
      "lodash" => %{"version" => "4.17.21"},
      "express" => %{"version" => "4.18.2"}
    }
  }

  describe "version" do
    test "detects v3" do
      assert 3 = PackageLock.version(@v3_lock)
    end

    test "detects v1" do
      assert 1 = PackageLock.version(@v1_lock)
    end

    test "nil for invalid" do
      assert nil == PackageLock.version(%{})
    end
  end

  describe "package_count" do
    test "counts v3 packages (excludes root)" do
      assert 2 = PackageLock.package_count(@v3_lock)
    end

    test "counts v1 dependencies" do
      assert 2 = PackageLock.package_count(@v1_lock)
    end

    test "zero for empty" do
      assert 0 = PackageLock.package_count(%{})
    end
  end

  describe "packages" do
    test "extracts v3 packages" do
      pkgs = PackageLock.packages(@v3_lock)
      assert pkgs["react"] == "18.2.0"
      assert pkgs["react-dom"] == "18.2.0"
    end

    test "extracts v1 dependencies" do
      pkgs = PackageLock.packages(@v1_lock)
      assert pkgs["lodash"] == "4.17.21"
    end

    test "empty for no packages" do
      assert %{} = PackageLock.packages(%{})
    end
  end

  describe "requires_npm7?" do
    test "true for v3" do
      assert PackageLock.requires_npm7?(@v3_lock)
    end

    test "false for v1" do
      refute PackageLock.requires_npm7?(@v1_lock)
    end
  end

  describe "metadata" do
    test "returns lock metadata" do
      meta = PackageLock.metadata(@v3_lock)
      assert meta.version == 3
      assert meta.package_count == 2
      assert meta.name == "my-app"
      assert meta.requires_npm7
    end
  end

  describe "read" do
    @tag :tmp_dir
    test "reads valid lock file", %{tmp_dir: dir} do
      path = Path.join(dir, "package-lock.json")
      File.write!(path, :json.encode(@v3_lock))

      assert {:ok, data} = PackageLock.read(path)
      assert data["lockfileVersion"] == 3
    end

    test "error for missing file" do
      assert {:error, _} =
               PackageLock.read("/tmp/nonexistent_#{System.unique_integer([:positive])}")
    end
  end
end
