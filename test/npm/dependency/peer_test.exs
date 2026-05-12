defmodule NPM.Dependency.PeerTest do
  use ExUnit.Case, async: true

  @pkg %{
    "peerDependencies" => %{"react" => "^18.0.0", "react-dom" => "^18.0.0"},
    "peerDependenciesMeta" => %{"react-dom" => %{"optional" => true}}
  }

  @lockfile %{
    "react" => %{version: "18.2.0", integrity: "", tarball: "", dependencies: %{}},
    "react-dom" => %{version: "18.2.0", integrity: "", tarball: "", dependencies: %{}}
  }

  describe "extract" do
    test "extracts peer deps" do
      peers = NPM.Dependency.Peer.extract(@pkg)
      assert peers["react"] == "^18.0.0"
    end

    test "empty for no peers" do
      assert %{} = NPM.Dependency.Peer.extract(%{})
    end
  end

  describe "meta" do
    test "extracts peer meta" do
      m = NPM.Dependency.Peer.meta(@pkg)
      assert m["react-dom"]["optional"] == true
    end

    test "empty for no meta" do
      assert %{} = NPM.Dependency.Peer.meta(%{})
    end
  end

  describe "optional?" do
    test "true for optional peer" do
      assert NPM.Dependency.Peer.optional?("react-dom", @pkg)
    end

    test "false for required peer" do
      refute NPM.Dependency.Peer.optional?("react", @pkg)
    end
  end

  describe "required" do
    test "excludes optional peers" do
      req = NPM.Dependency.Peer.required(@pkg)
      assert Map.has_key?(req, "react")
      refute Map.has_key?(req, "react-dom")
    end
  end

  describe "satisfied?" do
    test "true when all required peers present" do
      assert NPM.Dependency.Peer.satisfied?(@pkg, @lockfile)
    end

    test "false when missing required peer" do
      lockfile = Map.delete(@lockfile, "react")
      refute NPM.Dependency.Peer.satisfied?(@pkg, lockfile)
    end

    test "false when version mismatch" do
      lockfile =
        Map.put(@lockfile, "react", %{
          version: "17.0.0",
          integrity: "",
          tarball: "",
          dependencies: %{}
        })

      refute NPM.Dependency.Peer.satisfied?(@pkg, lockfile)
    end
  end

  describe "unsatisfied" do
    test "empty when satisfied" do
      assert [] = NPM.Dependency.Peer.unsatisfied(@pkg, @lockfile)
    end

    test "lists missing peers" do
      result = NPM.Dependency.Peer.unsatisfied(@pkg, %{})
      assert length(result) == 1
      {name, _range, version} = hd(result)
      assert name == "react"
      assert version == nil
    end

    test "lists version mismatches" do
      lockfile =
        Map.put(@lockfile, "react", %{
          version: "17.0.0",
          integrity: "",
          tarball: "",
          dependencies: %{}
        })

      result = NPM.Dependency.Peer.unsatisfied(@pkg, lockfile)
      assert {_, _, "17.0.0"} = hd(result)
    end
  end

  describe "count_across" do
    test "sums peer deps" do
      packages = [@pkg, %{"peerDependencies" => %{"vue" => "^3.0"}}]
      assert 3 = NPM.Dependency.Peer.count_across(packages)
    end

    test "zero for no peers" do
      assert 0 = NPM.Dependency.Peer.count_across([%{}, %{}])
    end
  end
end
