defmodule NPM.InitTest do
  use ExUnit.Case, async: true

  describe "generate" do
    test "creates default package.json map" do
      pkg = NPM.Init.generate()
      assert is_binary(pkg["name"])
      assert pkg["version"] == "1.0.0"
      assert pkg["license"] == "ISC"
      assert pkg["main"] == "index.js"
      assert pkg["dependencies"] == %{}
      assert pkg["devDependencies"] == %{}
    end

    test "accepts custom options" do
      pkg = NPM.Init.generate(name: "custom-pkg", version: "2.0.0", license: "MIT")
      assert pkg["name"] == "custom-pkg"
      assert pkg["version"] == "2.0.0"
      assert pkg["license"] == "MIT"
    end

    test "includes default test script" do
      pkg = NPM.Init.generate()
      assert pkg["scripts"]["test"] =~ "Error"
    end
  end

  describe "generate_minimal" do
    test "only name and version" do
      pkg = NPM.Init.generate_minimal("tiny-pkg")
      assert pkg == %{"name" => "tiny-pkg", "version" => "1.0.0"}
    end

    test "custom version" do
      pkg = NPM.Init.generate_minimal("pkg", "0.0.1")
      assert pkg["version"] == "0.0.1"
    end
  end

  describe "write" do
    @tag :tmp_dir
    test "creates package.json", %{tmp_dir: dir} do
      assert :ok = NPM.Init.write(dir, name: "test-pkg")
      assert File.exists?(Path.join(dir, "package.json"))

      content = File.read!(Path.join(dir, "package.json"))
      data = :json.decode(content)
      assert data["name"] == "test-pkg"
    end

    @tag :tmp_dir
    test "refuses to overwrite existing file", %{tmp_dir: dir} do
      File.write!(Path.join(dir, "package.json"), "{}")
      assert {:error, :already_exists} = NPM.Init.write(dir)
    end
  end

  describe "exists?" do
    @tag :tmp_dir
    test "true when package.json exists", %{tmp_dir: dir} do
      File.write!(Path.join(dir, "package.json"), "{}")
      assert NPM.Init.exists?(dir)
    end

    @tag :tmp_dir
    test "false when no package.json", %{tmp_dir: dir} do
      refute NPM.Init.exists?(dir)
    end
  end

  describe "default_name" do
    test "returns a valid package name" do
      name = NPM.Init.default_name()
      assert is_binary(name)
      assert name =~ ~r/^[a-z0-9\-_]+$/
    end
  end

  describe "default_scripts" do
    test "includes test script" do
      scripts = NPM.Init.default_scripts()
      assert Map.has_key?(scripts, "test")
    end
  end

  describe "from_mix_project" do
    test "derives from mix config" do
      pkg =
        NPM.Init.from_mix_project(app: :my_app, version: "0.5.0", description: "My Elixir app")

      assert pkg["name"] == "my_app"
      assert pkg["version"] == "0.5.0"
      assert pkg["description"] == "My Elixir app"
    end

    test "handles missing config" do
      pkg = NPM.Init.from_mix_project([])
      assert pkg["name"] == "unnamed"
      assert pkg["version"] == "0.1.0"
    end
  end
end
