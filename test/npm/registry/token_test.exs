defmodule NPM.Registry.TokenTest do
  use ExUnit.Case, async: true

  alias NPM.Registry.Token

  describe "mask" do
    test "masks long tokens" do
      masked = Token.mask("npm_abcdefghijklmnop")
      assert masked =~ "npm_"
      assert masked =~ "mnop"
      assert masked =~ "..."
      refute masked =~ "efgh"
    end

    test "fully masks short tokens" do
      assert "****" = Token.mask("short")
    end

    test "masks exactly 8 char token" do
      assert "****" = Token.mask("12345678")
    end

    test "masks 9 char token partially" do
      masked = Token.mask("123456789")
      assert masked =~ "1234"
      assert masked =~ "6789"
    end
  end

  describe "valid_format?" do
    test "valid UUID-style token" do
      assert Token.valid_format?("npm_abcdefghijklmnop1234")
    end

    test "valid base64 token" do
      assert Token.valid_format?("NjQ2NTY0YTQ3MWU2OGUzYjMw")
    end

    test "too short" do
      refute Token.valid_format?("abc")
    end

    test "contains spaces" do
      refute Token.valid_format?("token with spaces")
    end

    test "contains newlines" do
      refute Token.valid_format?("token\nwith\nnewlines")
    end
  end

  describe "auth_header" do
    test "returns Bearer token" do
      assert "Bearer my-token" = Token.auth_header("my-token")
    end
  end

  describe "parse_npmrc" do
    test "extracts auth token from npmrc content" do
      content = """
      registry=https://registry.npmjs.org/
      //registry.npmjs.org/:_authToken=npm_abc123def456
      """

      assert "npm_abc123def456" = Token.parse_npmrc(content)
    end

    test "handles scoped registry auth" do
      content = """
      @myorg:registry=https://npm.pkg.github.com
      //npm.pkg.github.com/:_authToken=ghp_abcdef123456
      """

      assert "ghp_abcdef123456" = Token.parse_npmrc(content)
    end

    test "returns nil when no token" do
      content = """
      registry=https://registry.npmjs.org/
      """

      assert nil == Token.parse_npmrc(content)
    end

    test "handles empty content" do
      assert nil == Token.parse_npmrc("")
    end
  end

  describe "configured?" do
    test "returns boolean" do
      result = Token.configured?()
      assert is_boolean(result)
    end
  end

  describe "read" do
    test "returns string or nil" do
      result = Token.read()
      assert is_binary(result) or is_nil(result)
    end
  end
end
