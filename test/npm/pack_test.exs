defmodule NPM.PackTest do
  use ExUnit.Case, async: true

  describe "tarball_name" do
    test "regular package" do
      assert "lodash-4.17.21.tgz" =
               NPM.Pack.tarball_name(%{"name" => "lodash", "version" => "4.17.21"})
    end

    test "scoped package" do
      assert "babel-core-7.24.0.tgz" =
               NPM.Pack.tarball_name(%{"name" => "@babel/core", "version" => "7.24.0"})
    end

    test "missing version defaults to 0.0.0" do
      assert "my-pkg-0.0.0.tgz" = NPM.Pack.tarball_name(%{"name" => "my-pkg"})
    end
  end

  describe "excluded?" do
    test ".git is excluded" do
      assert NPM.Pack.excluded?(".git")
    end

    test "node_modules is excluded" do
      assert NPM.Pack.excluded?("node_modules")
    end

    test ".DS_Store is excluded" do
      assert NPM.Pack.excluded?(".DS_Store")
    end

    test "dotfiles are excluded" do
      assert NPM.Pack.excluded?(".eslintrc")
    end

    test "regular files are not excluded" do
      refute NPM.Pack.excluded?("index.js")
    end

    test "nested in excluded dir" do
      assert NPM.Pack.excluded?("node_modules/pkg/index.js")
    end
  end

  describe "always_included?" do
    test "package.json" do
      assert NPM.Pack.always_included?("package.json")
    end

    test "README.md" do
      assert NPM.Pack.always_included?("README.md")
    end

    test "LICENSE" do
      assert NPM.Pack.always_included?("LICENSE")
    end

    test "CHANGELOG" do
      assert NPM.Pack.always_included?("CHANGELOG")
    end

    test "readme.md (case insensitive)" do
      assert NPM.Pack.always_included?("readme.md")
    end

    test "regular files are not always included" do
      refute NPM.Pack.always_included?("index.js")
    end
  end

  describe "list_files" do
    @tag :tmp_dir
    test "includes all non-excluded files by default", %{tmp_dir: dir} do
      File.write!(Path.join(dir, "package.json"), ~s({"name":"test","version":"1.0.0"}))
      File.write!(Path.join(dir, "index.js"), "module.exports = {}")
      File.write!(Path.join(dir, "README.md"), "# Test")
      File.write!(Path.join(dir, ".gitignore"), "node_modules")

      {:ok, files} = NPM.Pack.list_files(dir)
      assert "package.json" in files
      assert "index.js" in files
      assert "README.md" in files
      refute ".gitignore" in files
    end

    @tag :tmp_dir
    test "respects files field", %{tmp_dir: dir} do
      File.write!(
        Path.join(dir, "package.json"),
        ~s({"name":"test","version":"1.0.0","files":["dist"]})
      )

      File.mkdir_p!(Path.join(dir, "dist"))
      File.write!(Path.join([dir, "dist", "bundle.js"]), "bundled")
      File.write!(Path.join(dir, "src.js"), "source")

      {:ok, files} = NPM.Pack.list_files(dir)
      assert "dist/bundle.js" in files
      assert "package.json" in files
      refute "src.js" in files
    end

    @tag :tmp_dir
    test "always includes package.json even with files field", %{tmp_dir: dir} do
      File.write!(
        Path.join(dir, "package.json"),
        ~s({"name":"test","version":"1.0.0","files":["lib"]})
      )

      File.mkdir_p!(Path.join(dir, "lib"))
      File.write!(Path.join([dir, "lib", "index.js"]), "code")

      {:ok, files} = NPM.Pack.list_files(dir)
      assert "package.json" in files
    end

    test "returns error for missing package.json" do
      assert {:error, :enoent} =
               NPM.Pack.list_files("/tmp/nonexistent_#{System.unique_integer([:positive])}")
    end
  end

  describe "default_files" do
    @tag :tmp_dir
    test "excludes dotfiles and node_modules", %{tmp_dir: dir} do
      File.write!(Path.join(dir, "index.js"), "code")
      File.write!(Path.join(dir, ".env"), "SECRET=x")
      File.mkdir_p!(Path.join(dir, "node_modules"))

      files = NPM.Pack.default_files(dir)
      assert "index.js" in files
      refute ".env" in files
    end

    @tag :tmp_dir
    test "includes nested files from subdirectories", %{tmp_dir: dir} do
      File.mkdir_p!(Path.join(dir, "lib"))
      File.write!(Path.join([dir, "lib", "util.js"]), "code")
      File.write!(Path.join(dir, "index.js"), "code")

      files = NPM.Pack.default_files(dir)
      assert "lib/util.js" in files
      assert "index.js" in files
    end
  end
end
