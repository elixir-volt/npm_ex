defmodule NPM.MonorepoTest do
  use ExUnit.Case, async: true

  describe "detect" do
    @tag :tmp_dir
    test "detects npm workspaces", %{tmp_dir: dir} do
      File.write!(Path.join(dir, "package.json"), ~s({"workspaces":["packages/*"]}))
      assert :npm_workspaces in NPM.Monorepo.detect(dir)
    end

    @tag :tmp_dir
    test "detects lerna", %{tmp_dir: dir} do
      File.write!(Path.join(dir, "lerna.json"), "{}")
      assert :lerna in NPM.Monorepo.detect(dir)
    end

    @tag :tmp_dir
    test "detects turborepo", %{tmp_dir: dir} do
      File.write!(Path.join(dir, "turbo.json"), "{}")
      assert :turborepo in NPM.Monorepo.detect(dir)
    end

    @tag :tmp_dir
    test "detects nx", %{tmp_dir: dir} do
      File.write!(Path.join(dir, "nx.json"), "{}")
      assert :nx in NPM.Monorepo.detect(dir)
    end

    @tag :tmp_dir
    test "detects multiple tools", %{tmp_dir: dir} do
      File.write!(Path.join(dir, "package.json"), ~s({"workspaces":["packages/*"]}))
      File.write!(Path.join(dir, "turbo.json"), "{}")
      tools = NPM.Monorepo.detect(dir)
      assert :npm_workspaces in tools
      assert :turborepo in tools
    end

    @tag :tmp_dir
    test "empty when no monorepo files", %{tmp_dir: dir} do
      assert [] = NPM.Monorepo.detect(dir)
    end

    @tag :tmp_dir
    test "npm workspaces not detected without workspaces field", %{tmp_dir: dir} do
      File.write!(Path.join(dir, "package.json"), ~s({"name":"not-mono"}))
      refute :npm_workspaces in NPM.Monorepo.detect(dir)
    end
  end

  describe "monorepo?" do
    @tag :tmp_dir
    test "true for monorepo", %{tmp_dir: dir} do
      File.write!(Path.join(dir, "lerna.json"), "{}")
      assert NPM.Monorepo.monorepo?(dir)
    end

    @tag :tmp_dir
    test "false for non-monorepo", %{tmp_dir: dir} do
      refute NPM.Monorepo.monorepo?(dir)
    end
  end

  describe "primary" do
    @tag :tmp_dir
    test "returns first tool", %{tmp_dir: dir} do
      File.write!(Path.join(dir, "package.json"), ~s({"workspaces":["apps/*"]}))
      assert :npm_workspaces = NPM.Monorepo.primary(dir)
    end

    @tag :tmp_dir
    test "nil when not monorepo", %{tmp_dir: dir} do
      assert nil == NPM.Monorepo.primary(dir)
    end
  end

  describe "info" do
    @tag :tmp_dir
    test "returns full info", %{tmp_dir: dir} do
      File.write!(Path.join(dir, "turbo.json"), "{}")
      info = NPM.Monorepo.info(dir)
      assert info.is_monorepo
      assert :turborepo in info.tools
      assert info.tool_count == 1
    end
  end

  describe "format_info" do
    test "formats monorepo info" do
      info = %{is_monorepo: true, tools: [:turborepo, :npm_workspaces], primary: :turborepo}
      formatted = NPM.Monorepo.format_info(info)
      assert formatted =~ "Monorepo detected"
      assert formatted =~ "turborepo"
    end

    test "not a monorepo message" do
      assert "Not a monorepo." = NPM.Monorepo.format_info(%{is_monorepo: false})
    end
  end
end
