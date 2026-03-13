defmodule NPM.LinkTest do
  use ExUnit.Case, async: true

  describe "link" do
    @tag :tmp_dir
    test "creates symlink in node_modules", %{tmp_dir: dir} do
      pkg_dir = Path.join(dir, "my-local-pkg")
      nm_dir = Path.join(dir, "node_modules")
      File.mkdir_p!(pkg_dir)
      File.mkdir_p!(nm_dir)
      File.write!(Path.join(pkg_dir, "package.json"), ~s({"name":"my-local-pkg"}))

      assert {:ok, info} = NPM.Link.link(pkg_dir, nm_dir)
      assert info.name == "my-local-pkg"
      assert File.exists?(Path.join(nm_dir, "my-local-pkg"))

      {:ok, target} = File.read_link(Path.join(nm_dir, "my-local-pkg"))
      assert target == Path.expand(pkg_dir)
    end

    @tag :tmp_dir
    test "links scoped package", %{tmp_dir: dir} do
      pkg_dir = Path.join(dir, "scoped-pkg")
      nm_dir = Path.join(dir, "node_modules")
      File.mkdir_p!(pkg_dir)
      File.mkdir_p!(nm_dir)
      File.write!(Path.join(pkg_dir, "package.json"), ~s({"name":"@myorg/utils"}))

      assert {:ok, info} = NPM.Link.link(pkg_dir, nm_dir)
      assert info.name == "@myorg/utils"
    end

    @tag :tmp_dir
    test "returns error for missing package.json", %{tmp_dir: dir} do
      pkg_dir = Path.join(dir, "no-pkg")
      File.mkdir_p!(pkg_dir)

      assert {:error, :enoent} = NPM.Link.link(pkg_dir, Path.join(dir, "node_modules"))
    end
  end

  describe "unlink" do
    @tag :tmp_dir
    test "removes symlink", %{tmp_dir: dir} do
      pkg_dir = Path.join(dir, "linked-pkg")
      nm_dir = Path.join(dir, "node_modules")
      File.mkdir_p!(pkg_dir)
      File.mkdir_p!(nm_dir)
      File.write!(Path.join(pkg_dir, "package.json"), ~s({"name":"linked-pkg"}))

      {:ok, _} = NPM.Link.link(pkg_dir, nm_dir)
      assert :ok = NPM.Link.unlink("linked-pkg", nm_dir)
      refute File.exists?(Path.join(nm_dir, "linked-pkg"))
    end

    @tag :tmp_dir
    test "returns error when not linked", %{tmp_dir: dir} do
      nm_dir = Path.join(dir, "node_modules")
      File.mkdir_p!(nm_dir)

      assert {:error, :not_linked} = NPM.Link.unlink("nonexistent", nm_dir)
    end
  end

  describe "list" do
    @tag :tmp_dir
    test "lists linked packages", %{tmp_dir: dir} do
      pkg_dir = Path.join(dir, "local-pkg")
      nm_dir = Path.join(dir, "node_modules")
      File.mkdir_p!(pkg_dir)
      File.mkdir_p!(nm_dir)
      File.write!(Path.join(pkg_dir, "package.json"), ~s({"name":"local-pkg"}))

      {:ok, _} = NPM.Link.link(pkg_dir, nm_dir)
      links = NPM.Link.list(nm_dir)
      assert Enum.any?(links, &(&1.name == "local-pkg"))
    end

    @tag :tmp_dir
    test "excludes non-symlinked packages", %{tmp_dir: dir} do
      nm_dir = Path.join(dir, "node_modules")
      File.mkdir_p!(Path.join(nm_dir, "real-pkg"))
      File.write!(Path.join([nm_dir, "real-pkg", "package.json"]), ~s({"name":"real-pkg"}))

      links = NPM.Link.list(nm_dir)
      refute Enum.any?(links, &(&1.name == "real-pkg"))
    end

    test "empty for nonexistent directory" do
      assert [] = NPM.Link.list("/tmp/nonexistent_#{System.unique_integer([:positive])}")
    end
  end

  describe "linked?" do
    @tag :tmp_dir
    test "true for linked package", %{tmp_dir: dir} do
      pkg_dir = Path.join(dir, "pkg")
      nm_dir = Path.join(dir, "node_modules")
      File.mkdir_p!(pkg_dir)
      File.mkdir_p!(nm_dir)
      File.write!(Path.join(pkg_dir, "package.json"), ~s({"name":"pkg"}))

      {:ok, _} = NPM.Link.link(pkg_dir, nm_dir)
      assert NPM.Link.linked?("pkg", nm_dir)
    end

    @tag :tmp_dir
    test "false for regular installed package", %{tmp_dir: dir} do
      nm_dir = Path.join(dir, "node_modules")
      File.mkdir_p!(Path.join(nm_dir, "real-pkg"))

      refute NPM.Link.linked?("real-pkg", nm_dir)
    end
  end
end
