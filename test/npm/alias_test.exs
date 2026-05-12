defmodule NPM.AliasTest do
  use ExUnit.Case, async: true

  describe "PackageSpec + Alias integration" do
    test "alias parsed via spec matches direct parse" do
      spec = NPM.Package.Spec.parse("npm:react@^18.0.0")
      assert spec.type == :alias
      assert spec.name == "react"

      alias_result = NPM.Alias.parse("npm:react@^18.0.0")
      assert {:alias, "react", "^18.0.0"} = alias_result
    end
  end

  describe "Alias.parse" do
    test "parses npm: alias" do
      assert {:alias, "react", "^18.0.0"} = NPM.Alias.parse("npm:react@^18.0.0")
    end

    test "parses scoped alias" do
      assert {:alias, "@scope/pkg", "1.0.0"} = NPM.Alias.parse("npm:@scope/pkg@1.0.0")
    end

    test "returns normal for regular range" do
      assert {:normal, "^1.0.0"} = NPM.Alias.parse("^1.0.0")
    end

    test "returns normal for plain version" do
      assert {:normal, "1.2.3"} = NPM.Alias.parse("1.2.3")
    end

    test "returns normal for unparseable npm: prefix" do
      assert {:normal, "npm:"} = NPM.Alias.parse("npm:")
    end
  end

  describe "Alias.alias?" do
    test "detects alias" do
      assert NPM.Alias.alias?("npm:react@^18.0.0")
    end

    test "non-alias" do
      refute NPM.Alias.alias?("^1.0.0")
    end
  end

  describe "Alias.real_name" do
    test "extracts real package name from alias" do
      assert "react" = NPM.Alias.real_name("my-react", "npm:react@^18.0.0")
    end

    test "extracts scoped real name" do
      assert "@babel/core" = NPM.Alias.real_name("babel", "npm:@babel/core@7.0.0")
    end

    test "returns original name for non-alias" do
      assert "lodash" = NPM.Alias.real_name("lodash", "^4.17.0")
    end
  end

  describe "Alias: edge cases" do
    test "alias? checks npm: prefix" do
      assert NPM.Alias.alias?("npm:react@^18.0")
      refute NPM.Alias.alias?("^18.0")
      refute NPM.Alias.alias?("latest")
    end

    test "parse returns {:normal, range} for non-alias" do
      assert {:normal, "^4.0.0"} = NPM.Alias.parse("^4.0.0")
    end
  end

  describe "Alias: real_name for scoped aliases" do
    test "scoped alias returns scoped real name" do
      assert "@babel/core" = NPM.Alias.real_name("my-babel", "npm:@babel/core@^7.0")
    end
  end

  describe "Alias: parse with different formats" do
    test "alias with tilde range" do
      assert {:alias, "react", "~18.0.0"} = NPM.Alias.parse("npm:react@~18.0.0")
    end

    test "alias with exact version" do
      assert {:alias, "lodash", "4.17.21"} = NPM.Alias.parse("npm:lodash@4.17.21")
    end
  end

  describe "Alias: real npm alias patterns" do
    test "npm:react@^18 for multiple React versions" do
      assert {:alias, "react", "^18.0.0"} = NPM.Alias.parse("npm:react@^18.0.0")
    end

    test "npm: scoped alias for forked packages" do
      assert {:alias, "@babel/core", "7.0.0"} = NPM.Alias.parse("npm:@babel/core@7.0.0")
    end

    test "real_name extracts actual package for fetch" do
      assert "react" = NPM.Alias.real_name("my-react", "npm:react@^18.0.0")
    end

    test "non-alias returns same name" do
      assert "lodash" = NPM.Alias.real_name("lodash", "^4.17.0")
    end
  end

  describe "Alias: alias? detection" do
    test "npm: prefix is alias" do
      assert NPM.Alias.alias?("npm:react@^18")
    end

    test "semver range is not alias" do
      refute NPM.Alias.alias?("^1.0.0")
    end

    test "git URL is not alias" do
      refute NPM.Alias.alias?("git+https://github.com/user/repo")
    end
  end
end
