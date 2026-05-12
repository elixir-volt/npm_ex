defmodule NPM.Package.PublishConfigTest do
  use ExUnit.Case, async: true

  alias NPM.Package.PublishConfig

  describe "extract" do
    test "extracts config" do
      data = %{
        "publishConfig" => %{"registry" => "https://npm.pkg.github.com", "access" => "public"}
      }

      config = PublishConfig.extract(data)
      assert config["registry"] == "https://npm.pkg.github.com"
    end

    test "empty for no config" do
      assert %{} = PublishConfig.extract(%{})
    end
  end

  describe "registry" do
    test "returns publish registry" do
      data = %{"publishConfig" => %{"registry" => "https://custom.reg"}}
      assert "https://custom.reg" = PublishConfig.registry(data)
    end

    test "nil for no registry" do
      assert nil == PublishConfig.registry(%{})
    end
  end

  describe "access" do
    test "public when declared" do
      data = %{"publishConfig" => %{"access" => "public"}}
      assert "public" = PublishConfig.access(data)
    end

    test "restricted when declared" do
      data = %{"publishConfig" => %{"access" => "restricted"}}
      assert "restricted" = PublishConfig.access(data)
    end

    test "defaults to restricted for scoped" do
      data = %{"name" => "@myorg/pkg"}
      assert "restricted" = PublishConfig.access(data)
    end

    test "defaults to public for unscoped" do
      data = %{"name" => "my-pkg"}
      assert "public" = PublishConfig.access(data)
    end
  end

  describe "tag" do
    test "returns custom tag" do
      data = %{"publishConfig" => %{"tag" => "next"}}
      assert "next" = PublishConfig.tag(data)
    end

    test "defaults to latest" do
      assert "latest" = PublishConfig.tag(%{})
    end
  end

  describe "public?" do
    test "true when access is public" do
      data = %{"publishConfig" => %{"access" => "public"}}
      assert PublishConfig.public?(data)
    end

    test "false for scoped default" do
      refute PublishConfig.public?(%{"name" => "@org/pkg"})
    end
  end

  describe "configured?" do
    test "true when set" do
      assert PublishConfig.configured?(%{"publishConfig" => %{"access" => "public"}})
    end

    test "false when not set" do
      refute PublishConfig.configured?(%{})
    end
  end

  describe "format" do
    test "with config" do
      data = %{"publishConfig" => %{"access" => "public"}}
      formatted = PublishConfig.format(data)
      assert formatted =~ "Publish config:"
      assert formatted =~ "access: public"
    end

    test "no config" do
      assert "No publish configuration." = PublishConfig.format(%{})
    end
  end
end
