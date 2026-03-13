defmodule NPM.NpmrcTest do
  use ExUnit.Case, async: true

  @content """
  # npm config
  registry=https://registry.npmjs.org
  save-exact=true
  @myorg:registry=https://npm.myorg.com

  ; auth
  //npm.myorg.com/:_authToken=secret123
  """

  describe "parse" do
    test "parses key-value pairs" do
      config = NPM.Npmrc.parse(@content)
      assert config["registry"] == "https://registry.npmjs.org"
      assert config["save-exact"] == "true"
    end

    test "skips comments and blank lines" do
      config = NPM.Npmrc.parse(@content)
      refute Map.has_key?(config, "# npm config")
    end

    test "parses scoped registries" do
      config = NPM.Npmrc.parse(@content)
      assert config["@myorg:registry"] == "https://npm.myorg.com"
    end

    test "empty content" do
      assert %{} = NPM.Npmrc.parse("")
    end

    test "comment-only file" do
      assert %{} = NPM.Npmrc.parse("# comment\n; another")
    end
  end

  describe "read" do
    @tag :tmp_dir
    test "reads .npmrc file", %{tmp_dir: dir} do
      path = Path.join(dir, ".npmrc")
      File.write!(path, "registry=https://custom.com\n")
      assert {:ok, config} = NPM.Npmrc.read(path)
      assert config["registry"] == "https://custom.com"
    end

    test "error for missing file" do
      assert {:error, :not_found} =
               NPM.Npmrc.read("/tmp/nonexistent_npmrc_#{System.unique_integer([:positive])}")
    end
  end

  describe "merge" do
    test "later configs override" do
      configs = [
        %{"registry" => "https://a.com"},
        %{"registry" => "https://b.com"}
      ]

      merged = NPM.Npmrc.merge(configs)
      assert merged["registry"] == "https://b.com"
    end
  end

  describe "has_auth?" do
    test "true with auth token" do
      config = NPM.Npmrc.parse(@content)
      assert NPM.Npmrc.has_auth?(config)
    end

    test "false without auth" do
      refute NPM.Npmrc.has_auth?(%{"registry" => "https://npm.com"})
    end
  end

  describe "scoped_registries" do
    test "extracts scoped registries" do
      config = NPM.Npmrc.parse(@content)
      registries = NPM.Npmrc.scoped_registries(config)
      assert {"myorg", "https://npm.myorg.com"} in registries
    end

    test "empty for no scoped registries" do
      assert [] = NPM.Npmrc.scoped_registries(%{"registry" => "https://npm.com"})
    end
  end

  describe "format" do
    test "redacts auth tokens" do
      config = %{"_authToken" => "secret", "registry" => "https://npm.com"}
      formatted = NPM.Npmrc.format(config)
      assert formatted =~ "[REDACTED]"
      refute formatted =~ "secret"
    end

    test "empty config" do
      assert "Empty .npmrc" = NPM.Npmrc.format(%{})
    end
  end

  describe "locate" do
    @tag :tmp_dir
    test "finds project .npmrc", %{tmp_dir: dir} do
      File.write!(Path.join(dir, ".npmrc"), "registry=https://custom.com\n")
      found = NPM.Npmrc.locate(dir)
      assert Enum.any?(found, &String.ends_with?(&1, ".npmrc"))
    end
  end
end
