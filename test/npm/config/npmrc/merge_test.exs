defmodule NPM.Config.Npmrc.MergeTest do
  use ExUnit.Case, async: true

  describe "layers" do
    test "returns three paths in order" do
      paths = NPM.Config.Npmrc.Merge.layers("/my/project")
      assert length(paths) == 3
      assert paths |> Enum.reverse() |> hd() == "/my/project/.npmrc"
    end
  end

  describe "read_layer" do
    @tag :tmp_dir
    test "reads existing file", %{tmp_dir: dir} do
      path = Path.join(dir, ".npmrc")
      File.write!(path, "registry=https://custom.registry.com\n")
      config = NPM.Config.Npmrc.Merge.read_layer(path)
      assert config["registry"] == "https://custom.registry.com"
    end

    test "returns empty for missing file" do
      assert %{} = NPM.Config.Npmrc.Merge.read_layer("/nonexistent/.npmrc")
    end
  end

  describe "resolve" do
    @tag :tmp_dir
    test "project overrides user", %{tmp_dir: dir} do
      File.write!(Path.join(dir, ".npmrc"), "registry=https://project.com\n")
      config = NPM.Config.Npmrc.Merge.resolve(dir)
      assert config["registry"] == "https://project.com"
    end

    @tag :tmp_dir
    test "returns empty for no configs", %{tmp_dir: dir} do
      config = NPM.Config.Npmrc.Merge.resolve(dir)
      assert is_map(config)
    end
  end

  describe "active_layers" do
    @tag :tmp_dir
    test "includes project layer with config", %{tmp_dir: dir} do
      File.write!(Path.join(dir, ".npmrc"), "save-exact=true\n")
      layers = NPM.Config.Npmrc.Merge.active_layers(dir)
      project_path = Path.join(dir, ".npmrc")
      project = Enum.find(layers, &(&1.path == project_path))
      assert project
      assert "save-exact" in project.keys
    end
  end

  describe "trace" do
    @tag :tmp_dir
    test "finds key in project layer", %{tmp_dir: dir} do
      File.write!(Path.join(dir, ".npmrc"), "registry=https://my.com\n")
      assert {:ok, path, value} = NPM.Config.Npmrc.Merge.trace(dir, "registry")
      assert path =~ ".npmrc"
      assert value == "https://my.com"
    end

    @tag :tmp_dir
    test "not found for missing key", %{tmp_dir: dir} do
      assert :not_found = NPM.Config.Npmrc.Merge.trace(dir, "nonexistent-key")
    end
  end
end
