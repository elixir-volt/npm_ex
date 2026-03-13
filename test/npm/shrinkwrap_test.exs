defmodule NPM.ShrinkwrapTest do
  use ExUnit.Case, async: true

  describe "create shrinkwrap" do
    @tag :tmp_dir
    test "creates shrinkwrap from lockfile", %{tmp_dir: dir} do
      lock_data = %{
        "lockfileVersion" => 3,
        "packages" => %{"lodash" => %{"version" => "4.17.21"}}
      }

      File.write!(Path.join(dir, "package-lock.json"), :json.encode(lock_data))

      assert :ok = NPM.Shrinkwrap.create(dir)
      assert File.exists?(Path.join(dir, "npm-shrinkwrap.json"))
    end

    @tag :tmp_dir
    test "preserves lockfile version", %{tmp_dir: dir} do
      lock_data = %{"lockfileVersion" => 2, "packages" => %{}}
      File.write!(Path.join(dir, "package-lock.json"), :json.encode(lock_data))

      :ok = NPM.Shrinkwrap.create(dir)
      {:ok, shrink} = NPM.Shrinkwrap.read(dir)
      assert shrink["lockfileVersion"] == 2
    end

    @tag :tmp_dir
    test "returns error when no lockfile", %{tmp_dir: dir} do
      assert {:error, {:no_lockfile, _}} = NPM.Shrinkwrap.create(dir)
    end
  end

  describe "exists?" do
    @tag :tmp_dir
    test "true when shrinkwrap exists", %{tmp_dir: dir} do
      File.write!(Path.join(dir, "npm-shrinkwrap.json"), "{}")
      assert NPM.Shrinkwrap.exists?(dir)
    end

    @tag :tmp_dir
    test "false when no shrinkwrap", %{tmp_dir: dir} do
      refute NPM.Shrinkwrap.exists?(dir)
    end
  end

  describe "read" do
    @tag :tmp_dir
    test "reads and parses shrinkwrap", %{tmp_dir: dir} do
      data = %{"lockfileVersion" => 3, "packages" => %{"react" => %{"version" => "18.2.0"}}}
      File.write!(Path.join(dir, "npm-shrinkwrap.json"), :json.encode(data))

      {:ok, parsed} = NPM.Shrinkwrap.read(dir)
      assert parsed["lockfileVersion"] == 3
    end

    @tag :tmp_dir
    test "returns error for missing file", %{tmp_dir: dir} do
      assert {:error, :enoent} = NPM.Shrinkwrap.read(dir)
    end
  end

  describe "verify" do
    test "no mismatches when everything matches" do
      shrinkwrap = %{"lodash" => "4.17.21", "react" => "18.2.0"}

      installed = %{
        "lodash" => %{version: "4.17.21"},
        "react" => %{version: "18.2.0"}
      }

      assert [] = NPM.Shrinkwrap.verify(shrinkwrap, installed)
    end

    test "detects missing packages" do
      shrinkwrap = %{"lodash" => "4.17.21"}
      installed = %{}

      [mismatch] = NPM.Shrinkwrap.verify(shrinkwrap, installed)
      assert mismatch.name == "lodash"
      assert mismatch.type == :missing
      assert mismatch.actual == nil
    end

    test "detects version mismatches" do
      shrinkwrap = %{"lodash" => "4.17.21"}
      installed = %{"lodash" => %{version: "4.17.20"}}

      [mismatch] = NPM.Shrinkwrap.verify(shrinkwrap, installed)
      assert mismatch.type == :version_mismatch
      assert mismatch.expected == "4.17.21"
      assert mismatch.actual == "4.17.20"
    end

    test "multiple mismatches sorted by name" do
      shrinkwrap = %{"z-pkg" => "1.0.0", "a-pkg" => "2.0.0"}
      installed = %{}

      mismatches = NPM.Shrinkwrap.verify(shrinkwrap, installed)
      names = Enum.map(mismatches, & &1.name)
      assert names == Enum.sort(names)
    end
  end

  describe "outdated?" do
    @tag :tmp_dir
    test "false when lockfile and shrinkwrap match", %{tmp_dir: dir} do
      data = %{"packages" => %{"a" => %{"version" => "1.0.0"}}}
      json = :json.encode(data)
      File.write!(Path.join(dir, "package-lock.json"), json)
      File.write!(Path.join(dir, "npm-shrinkwrap.json"), json)

      refute NPM.Shrinkwrap.outdated?(dir)
    end

    @tag :tmp_dir
    test "true when packages differ", %{tmp_dir: dir} do
      lock = %{"packages" => %{"a" => %{"version" => "2.0.0"}}}
      shrink = %{"packages" => %{"a" => %{"version" => "1.0.0"}}}
      File.write!(Path.join(dir, "package-lock.json"), :json.encode(lock))
      File.write!(Path.join(dir, "npm-shrinkwrap.json"), :json.encode(shrink))

      assert NPM.Shrinkwrap.outdated?(dir)
    end

    @tag :tmp_dir
    test "true when files missing", %{tmp_dir: dir} do
      assert NPM.Shrinkwrap.outdated?(dir)
    end
  end

  describe "remove" do
    @tag :tmp_dir
    test "removes shrinkwrap file", %{tmp_dir: dir} do
      path = Path.join(dir, "npm-shrinkwrap.json")
      File.write!(path, "{}")
      assert :ok = NPM.Shrinkwrap.remove(dir)
      refute File.exists?(path)
    end

    @tag :tmp_dir
    test "ok when file doesn't exist", %{tmp_dir: dir} do
      assert :ok = NPM.Shrinkwrap.remove(dir)
    end
  end

  describe "create and read roundtrip" do
    @tag :tmp_dir
    test "shrinkwrap matches lockfile content", %{tmp_dir: dir} do
      lock_data = %{
        "lockfileVersion" => 3,
        "packages" => %{
          "react" => %{"version" => "18.2.0"},
          "lodash" => %{"version" => "4.17.21"}
        }
      }

      File.write!(Path.join(dir, "package-lock.json"), :json.encode(lock_data))
      :ok = NPM.Shrinkwrap.create(dir)
      {:ok, shrink} = NPM.Shrinkwrap.read(dir)
      assert shrink["packages"]["react"]["version"] == "18.2.0"
      assert shrink["packages"]["lodash"]["version"] == "4.17.21"
    end
  end

  describe "verify mixed results" do
    test "both missing and mismatched" do
      shrinkwrap = %{"a" => "1.0.0", "b" => "2.0.0"}
      installed = %{"a" => %{version: "1.0.1"}}

      mismatches = NPM.Shrinkwrap.verify(shrinkwrap, installed)
      types = Map.new(mismatches, &{&1.name, &1.type})
      assert types["a"] == :version_mismatch
      assert types["b"] == :missing
    end
  end
end
