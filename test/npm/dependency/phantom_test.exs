defmodule NPM.Dependency.PhantomTest do
  use ExUnit.Case, async: true

  alias NPM.Dependency.Phantom

  @pkg %{
    "dependencies" => %{"express" => "^4.18.0"},
    "devDependencies" => %{"jest" => "^29.0.0"}
  }

  @lockfile %{
    "express" => %{version: "4.18.2"},
    "jest" => %{version: "29.7.0"},
    "debug" => %{version: "4.3.4"},
    "ms" => %{version: "2.1.3"}
  }

  describe "detect" do
    test "finds undeclared packages" do
      phantoms = Phantom.detect(@pkg, @lockfile)
      assert "debug" in phantoms
      assert "ms" in phantoms
      refute "express" in phantoms
    end

    test "empty when all declared" do
      lockfile = %{"express" => %{version: "4.18.2"}, "jest" => %{version: "29.7.0"}}
      assert [] = Phantom.detect(@pkg, lockfile)
    end
  end

  describe "count" do
    test "counts phantoms" do
      assert 2 = Phantom.count(@pkg, @lockfile)
    end
  end

  describe "phantom?" do
    test "true for undeclared" do
      assert Phantom.phantom?("debug", @pkg)
    end

    test "false for declared" do
      refute Phantom.phantom?("express", @pkg)
    end

    test "checks devDependencies too" do
      refute Phantom.phantom?("jest", @pkg)
    end
  end

  describe "format_report" do
    test "no phantoms message" do
      assert "No phantom dependencies detected." = Phantom.format_report([])
    end

    test "formats phantom list" do
      report = Phantom.format_report(["debug", "ms"])
      assert report =~ "2 phantom"
      assert report =~ "debug"
      assert report =~ "ms"
    end
  end
end
