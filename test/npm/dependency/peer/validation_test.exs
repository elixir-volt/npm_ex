defmodule NPM.Dependency.PeerValidationTest do
  use ExUnit.Case, async: true

  alias NPM.Dependency.Peer

  describe "PeerDeps: extract from manifest" do
    test "extracts peerDependencies" do
      manifest = %{"peerDependencies" => %{"react" => "^18.0.0", "react-dom" => "^18.0.0"}}
      peers = Peer.extract(manifest)
      assert peers["react"] == "^18.0.0"
      assert peers["react-dom"] == "^18.0.0"
    end

    test "returns empty map when no peerDependencies" do
      assert %{} = Peer.extract(%{"name" => "pkg"})
    end

    test "returns empty map for nil" do
      assert %{} = Peer.extract(nil)
    end
  end

  describe "PeerDeps: optional_peers" do
    test "detects optional peers" do
      manifest = %{
        "peerDependenciesMeta" => %{
          "react-native" => %{"optional" => true},
          "react" => %{"optional" => false}
        }
      }

      optional = Peer.optional_peers(manifest)
      assert MapSet.member?(optional, "react-native")
      refute MapSet.member?(optional, "react")
    end

    test "returns empty set when no meta" do
      assert MapSet.size(Peer.optional_peers(%{})) == 0
    end
  end

  describe "PeerDeps: check satisfied" do
    test "no warnings when all peers satisfied" do
      lockfile = %{
        "react" => %{version: "18.2.0", integrity: "", tarball: "", dependencies: %{}},
        "react-dom" => %{version: "18.2.0", integrity: "", tarball: "", dependencies: %{}}
      }

      manifests = [
        %{
          "name" => "my-component",
          "peerDependencies" => %{"react" => "^18.0.0", "react-dom" => "^18.0.0"}
        }
      ]

      warnings = Peer.check(lockfile, manifests)
      assert warnings == []
    end
  end

  describe "PeerDeps: check missing" do
    test "warns when peer is not installed" do
      lockfile = %{}

      manifests = [
        %{"name" => "my-hook", "peerDependencies" => %{"react" => "^18.0.0"}}
      ]

      warnings = Peer.check(lockfile, manifests)
      assert Enum.any?(warnings, &(&1.peer == "react" and &1.found == nil))
    end
  end

  describe "PeerDeps: check incompatible version" do
    test "warns when installed version doesn't satisfy range" do
      lockfile = %{
        "react" => %{version: "16.8.0", integrity: "", tarball: "", dependencies: %{}}
      }

      manifests = [
        %{"name" => "modern-hooks", "peerDependencies" => %{"react" => "^18.0.0"}}
      ]

      warnings = Peer.check(lockfile, manifests)
      assert Enum.any?(warnings, &(&1.peer == "react" and &1.found == "16.8.0"))
    end
  end

  describe "PeerDeps: check skips optional peers" do
    test "optional missing peer produces no warning" do
      lockfile = %{}

      manifests = [
        %{
          "name" => "cross-platform",
          "peerDependencies" => %{"react-native" => ">=0.60"},
          "peerDependenciesMeta" => %{"react-native" => %{"optional" => true}}
        }
      ]

      warnings = Peer.check(lockfile, manifests)
      assert warnings == []
    end
  end

  describe "PeerDeps: check multiple packages" do
    test "checks peers across multiple manifests" do
      lockfile = %{
        "react" => %{version: "18.2.0", integrity: "", tarball: "", dependencies: %{}}
      }

      manifests = [
        %{"name" => "pkg-a", "peerDependencies" => %{"react" => "^18.0.0"}},
        %{"name" => "pkg-b", "peerDependencies" => %{"vue" => "^3.0.0"}}
      ]

      warnings = Peer.check(lockfile, manifests)
      assert Enum.any?(warnings, &(&1.package == "pkg-b" and &1.peer == "vue"))
      refute Enum.any?(warnings, &(&1.package == "pkg-a"))
    end
  end

  describe "PeerDeps: summary" do
    test "counts missing and incompatible" do
      warnings = [
        %{package: "a", peer: "react", required: "^18", found: nil, satisfied: false},
        %{package: "b", peer: "vue", required: "^3", found: "2.7.0", satisfied: false},
        %{package: "c", peer: "svelte", required: "^4", found: nil, satisfied: false}
      ]

      s = Peer.summary(warnings)
      assert s.missing == 2
      assert s.incompatible == 1
    end

    test "empty warnings" do
      s = Peer.summary([])
      assert s.missing == 0
      assert s.incompatible == 0
    end
  end

  describe "PeerDeps: format_warnings" do
    test "formats missing peer" do
      warnings = [
        %{package: "hooks-lib", peer: "react", required: "^18.0.0", found: nil, satisfied: false}
      ]

      [msg] = Peer.format_warnings(warnings)
      assert msg =~ "hooks-lib"
      assert msg =~ "react"
      assert msg =~ "not installed"
    end

    test "formats incompatible peer" do
      warnings = [
        %{
          package: "new-lib",
          peer: "react",
          required: "^18.0.0",
          found: "16.8.0",
          satisfied: false
        }
      ]

      [msg] = Peer.format_warnings(warnings)
      assert msg =~ "new-lib"
      assert msg =~ "16.8.0"
    end

    test "formats empty list" do
      assert [] = Peer.format_warnings([])
    end
  end

  describe "PeerDeps: check with empty manifests" do
    test "no manifests produces no warnings" do
      assert [] = Peer.check(%{"react" => %{version: "18.0.0"}}, [])
    end
  end

  describe "PeerDeps: check with no peers in manifest" do
    test "manifest without peerDependencies produces no warnings" do
      lockfile = %{"react" => %{version: "18.0.0", integrity: "", tarball: "", dependencies: %{}}}
      manifests = [%{"name" => "simple-pkg"}]
      assert [] = Peer.check(lockfile, manifests)
    end
  end
end
