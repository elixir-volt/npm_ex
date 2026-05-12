defmodule NPM.ConfigTest do
  use ExUnit.Case, async: false

  describe "Config.parse_npmrc" do
    test "parses key=value pairs" do
      content = "registry=https://registry.example.com\nalways-auth=true"
      result = NPM.Config.parse_npmrc(content)
      assert result["registry"] == "https://registry.example.com"
      assert result["always-auth"] == "true"
    end

    test "ignores comments" do
      content = "# this is a comment\nregistry=https://example.com\n# another comment"
      result = NPM.Config.parse_npmrc(content)
      assert map_size(result) == 1
      assert result["registry"] == "https://example.com"
    end

    test "ignores blank lines" do
      content = "\nregistry=https://example.com\n\n\n"
      result = NPM.Config.parse_npmrc(content)
      assert map_size(result) == 1
    end

    test "handles auth tokens with = in value" do
      content = "//registry.npmjs.org/:_authToken=abc123def456=="
      result = NPM.Config.parse_npmrc(content)
      assert result["//registry.npmjs.org/:_authToken"] == "abc123def456=="
    end

    test "handles empty content" do
      assert NPM.Config.parse_npmrc("") == %{}
    end

    test "handles whitespace around values" do
      content = "  registry = https://example.com  "
      result = NPM.Config.parse_npmrc(content)
      assert result["registry"] == "https://example.com"
    end
  end

  describe "Config registry priority" do
    test "env var overrides everything" do
      original = System.get_env("NPM_REGISTRY")
      System.put_env("NPM_REGISTRY", "https://custom.registry.io")

      assert NPM.Config.registry() == "https://custom.registry.io"

      if original,
        do: System.put_env("NPM_REGISTRY", original),
        else: System.delete_env("NPM_REGISTRY")
    end

    test "defaults to npmjs.org" do
      original = System.get_env("NPM_REGISTRY")
      System.delete_env("NPM_REGISTRY")

      result = NPM.Config.registry()
      assert result =~ "registry.npmjs.org" or result =~ "npm"

      if original, do: System.put_env("NPM_REGISTRY", original)
    end

    test "falls back to application registry config" do
      original_env = System.get_env("NPM_REGISTRY")
      original_config = Application.get_env(:npm, :registry)

      System.delete_env("NPM_REGISTRY")
      Application.put_env(:npm, :registry, "https://configured.registry")

      assert NPM.Config.registry() == "https://configured.registry"

      restore_env("NPM_REGISTRY", original_env)
      restore_app_config(:registry, original_config)
    end

    test "reads application config for npm_ex specific directories and policies" do
      original_cache = Application.get_env(:npm, :cache_dir)
      original_install = Application.get_env(:npm, :install_dir)
      original_mirror = Application.get_env(:npm, :mirror)
      original_block = Application.get_env(:npm, :block_exotic_subdeps)
      original_compromised_db = Application.get_env(:npm, :compromised_db_path)
      original_compromised_sources = Application.get_env(:npm, :compromised_sources)

      Application.put_env(:npm, :cache_dir, "/tmp/npm-cache")
      Application.put_env(:npm, :install_dir, "/tmp/npm-installs")
      Application.put_env(:npm, :mirror, "https://mirror.example")
      Application.put_env(:npm, :block_exotic_subdeps, false)
      Application.put_env(:npm, :compromised_db_path, "/tmp/npm-compromised.json")
      Application.put_env(:npm, :compromised_sources, [:local, :osv])

      assert NPM.Config.cache_dir() == "/tmp/npm-cache"
      assert NPM.Config.install_dir("abc") == "/tmp/npm-installs/abc"
      assert NPM.Config.mirror_url() == "https://mirror.example"
      assert NPM.Config.compromised_db_path() == "/tmp/npm-compromised.json"
      assert NPM.Config.compromised_sources() == [:local, :osv]
      refute NPM.Config.block_exotic_subdeps?()

      restore_app_config(:cache_dir, original_cache)
      restore_app_config(:install_dir, original_install)
      restore_app_config(:mirror, original_mirror)
      restore_app_config(:block_exotic_subdeps, original_block)
      restore_app_config(:compromised_db_path, original_compromised_db)
      restore_app_config(:compromised_sources, original_compromised_sources)
    end
  end

  describe "Config.parse_npmrc edge cases" do
    test "handles multiple = signs in value" do
      result = NPM.Config.parse_npmrc("key=value=with=equals")
      assert result["key"] == "value=with=equals"
    end

    test "handles lines with only comments" do
      result = NPM.Config.parse_npmrc("# comment\n# another")
      assert result == %{}
    end

    test "handles mixed content" do
      content = """
      # npm config
      registry=https://example.com
      # auth stuff
      always-auth=true
      save-exact=true
      """

      result = NPM.Config.parse_npmrc(content)
      assert map_size(result) == 3
      assert result["registry"] == "https://example.com"
      assert result["always-auth"] == "true"
      assert result["save-exact"] == "true"
    end
  end

  describe "Config: parse_npmrc handles env vars" do
    test "parses key=value with env var references" do
      content = "registry=${NPM_REGISTRY:-https://registry.npmjs.org/}"
      result = NPM.Config.parse_npmrc(content)
      assert Map.has_key?(result, "registry")
    end
  end

  describe "Config: multi-line npmrc" do
    test "parses complex real-world npmrc" do
      content = """
      registry=https://registry.npmjs.org/
      @myorg:registry=https://npm.myorg.com/
      //npm.myorg.com/:_authToken=npm_abcdef
      save-exact=true
      engine-strict=true
      fund=false
      audit=false
      """

      result = NPM.Config.parse_npmrc(content)
      assert map_size(result) == 7
      assert result["fund"] == "false"
      assert result["audit"] == "false"
    end
  end

  describe "Config: parse_npmrc round-trip" do
    @tag :tmp_dir
    test "manually written npmrc parses correctly", %{tmp_dir: dir} do
      path = Path.join(dir, ".npmrc")
      content = "registry=https://custom.registry.com\nsave-exact=true\n"
      File.write!(path, content)

      result = NPM.Config.parse_npmrc(File.read!(path))
      assert result["registry"] == "https://custom.registry.com"
      assert result["save-exact"] == "true"
    end
  end

  describe "Config: parse_npmrc edge cases" do
    test "handles = signs in values" do
      content = "//registry.npmjs.org/:_authToken=npm_abcdef123456=="
      result = NPM.Config.parse_npmrc(content)
      assert result["//registry.npmjs.org/:_authToken"] == "npm_abcdef123456=="
    end

    test "handles trailing whitespace" do
      content = "registry=https://registry.npmjs.org/  \n"
      result = NPM.Config.parse_npmrc(content)
      assert result["registry"] == "https://registry.npmjs.org/"
    end
  end

  describe "Config: real .npmrc patterns" do
    test "parses registry config" do
      content = "registry=https://registry.npmjs.org/"
      result = NPM.Config.parse_npmrc(content)
      assert result["registry"] == "https://registry.npmjs.org/"
    end

    test "parses scoped registry" do
      content = "@mycompany:registry=https://npm.mycompany.com"
      result = NPM.Config.parse_npmrc(content)
      assert result["@mycompany:registry"] == "https://npm.mycompany.com"
    end

    test "parses auth token" do
      content = "//registry.npmjs.org/:_authToken=npm_abc123"
      result = NPM.Config.parse_npmrc(content)
      assert result["//registry.npmjs.org/:_authToken"] == "npm_abc123"
    end

    test "ignores comments and blank lines" do
      content = """
      # This is a comment
      registry=https://registry.npmjs.org/

      # Another comment
      always-auth=false
      """

      result = NPM.Config.parse_npmrc(content)
      assert map_size(result) == 2
      assert result["registry"] == "https://registry.npmjs.org/"
    end

    test "handles real-world .npmrc with multiple settings" do
      content = """
      registry=https://registry.npmjs.org/
      @myco:registry=https://npm.myco.com/
      //npm.myco.com/:_authToken=secret123
      save-exact=true
      engine-strict=true
      """

      result = NPM.Config.parse_npmrc(content)
      assert map_size(result) == 5
      assert result["save-exact"] == "true"
    end
  end

  describe "Config: registry and auth_token" do
    test "registry returns a URL string" do
      url = NPM.Config.registry()
      assert is_binary(url)
      assert String.starts_with?(url, "https://")
    end

    test "auth_token returns nil or string" do
      token = NPM.Config.auth_token()
      assert is_nil(token) or is_binary(token)
    end
  end

  describe "get" do
    test "returns value for existing key" do
      config = %{"registry" => "https://example.com"}
      assert "https://example.com" = NPM.Config.get(config, "registry")
    end

    test "returns default for missing key" do
      assert "fallback" = NPM.Config.get(%{}, "missing", "fallback")
    end

    test "returns nil for missing key with no default" do
      assert nil == NPM.Config.get(%{}, "missing")
    end
  end

  describe "merge" do
    test "later configs override earlier" do
      configs = [
        %{"registry" => "https://a.com", "save-exact" => "true"},
        %{"registry" => "https://b.com"}
      ]

      result = NPM.Config.merge(configs)
      assert result["registry"] == "https://b.com"
      assert result["save-exact"] == "true"
    end

    test "empty list returns empty map" do
      assert %{} = NPM.Config.merge([])
    end
  end

  describe "load" do
    @tag :tmp_dir
    test "loads project .npmrc", %{tmp_dir: dir} do
      File.write!(Path.join(dir, ".npmrc"), "save-exact=true")
      config = NPM.Config.load(dir)
      assert config["save-exact"] == "true"
    end

    @tag :tmp_dir
    test "empty for project without .npmrc", %{tmp_dir: dir} do
      config = NPM.Config.load(dir)
      assert is_map(config)
    end
  end

  describe "scoped_registry" do
    test "returns scoped registry when configured" do
      config = %{
        "registry" => "https://registry.npmjs.org",
        "@myorg:registry" => "https://npm.myorg.com"
      }

      assert "https://npm.myorg.com" = NPM.Config.scoped_registry(config, "@myorg")
    end

    test "falls back to default registry" do
      config = %{"registry" => "https://registry.npmjs.org"}
      assert "https://registry.npmjs.org" = NPM.Config.scoped_registry(config, "@other")
    end

    test "falls back to npmjs.org when no registry configured" do
      assert "https://registry.npmjs.org" = NPM.Config.scoped_registry(%{}, "@scope")
    end
  end

  defp restore_env(name, nil), do: System.delete_env(name)
  defp restore_env(name, value), do: System.put_env(name, value)

  defp restore_app_config(key, nil), do: Application.delete_env(:npm, key)
  defp restore_app_config(key, value), do: Application.put_env(:npm, key, value)
end
