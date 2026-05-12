defmodule NPM.Dependency.Peer.CheckTest do
  use ExUnit.Case, async: true

  @lockfile %{
    "react" => %{version: "18.2.0", integrity: "", tarball: "", dependencies: %{}},
    "react-dom" => %{version: "18.2.0", integrity: "", tarball: "", dependencies: %{}}
  }

  describe "check_peers" do
    test "no issues when peers satisfied" do
      data = %{
        "name" => "my-lib",
        "peerDependencies" => %{"react" => "^18.0.0"}
      }

      assert [] = NPM.Dependency.Peer.Check.check_peers(data, @lockfile)
    end

    test "missing peer dependency" do
      data = %{
        "name" => "my-lib",
        "peerDependencies" => %{"vue" => "^3.0.0"}
      }

      issues = NPM.Dependency.Peer.Check.check_peers(data, @lockfile)
      assert length(issues) == 1
      assert hd(issues).status == :missing
      assert hd(issues).peer == "vue"
    end

    test "incompatible version" do
      data = %{
        "name" => "old-lib",
        "peerDependencies" => %{"react" => "^16.0.0"}
      }

      issues = NPM.Dependency.Peer.Check.check_peers(data, @lockfile)
      assert length(issues) == 1
      assert hd(issues).status == :incompatible
      assert hd(issues).installed == "18.2.0"
    end

    test "optional missing peer" do
      data = %{
        "name" => "flex-lib",
        "peerDependencies" => %{"@emotion/styled" => "^11.0.0"},
        "peerDependenciesMeta" => %{"@emotion/styled" => %{"optional" => true}}
      }

      issues = NPM.Dependency.Peer.Check.check_peers(data, @lockfile)
      assert length(issues) == 1
      assert hd(issues).status == :optional_missing
    end

    test "no peer deps means no issues" do
      data = %{"name" => "simple"}
      assert [] = NPM.Dependency.Peer.Check.check_peers(data, @lockfile)
    end
  end

  describe "check" do
    @tag :tmp_dir
    test "scans node_modules for peer issues", %{tmp_dir: dir} do
      nm = Path.join(dir, "node_modules")
      pkg = Path.join(nm, "my-component")
      File.mkdir_p!(pkg)

      File.write!(
        Path.join(pkg, "package.json"),
        ~s({"name":"my-component","peerDependencies":{"angular":"^15.0.0"}})
      )

      issues = NPM.Dependency.Peer.Check.check(nm, @lockfile)
      assert Enum.any?(issues, &(&1.peer == "angular"))
    end

    @tag :tmp_dir
    test "empty for nonexistent dir", %{tmp_dir: dir} do
      assert [] = NPM.Dependency.Peer.Check.check(Path.join(dir, "nonexistent"), %{})
    end
  end

  describe "filter_by_status" do
    test "filters to missing only" do
      issues = [
        %{package: "a", peer: "x", required: "^1", status: :missing, installed: nil},
        %{package: "b", peer: "y", required: "^2", status: :incompatible, installed: "1.0.0"}
      ]

      result = NPM.Dependency.Peer.Check.filter_by_status(issues, :missing)
      assert length(result) == 1
      assert hd(result).package == "a"
    end
  end

  describe "format_issues" do
    test "formats missing issue" do
      issues = [
        %{package: "lib", peer: "react", required: "^18", status: :missing, installed: nil}
      ]

      formatted = NPM.Dependency.Peer.Check.format_issues(issues)
      assert formatted =~ "not installed"
      assert formatted =~ "react"
    end

    test "formats incompatible issue" do
      issues = [
        %{
          package: "lib",
          peer: "react",
          required: "^16",
          status: :incompatible,
          installed: "18.2.0"
        }
      ]

      formatted = NPM.Dependency.Peer.Check.format_issues(issues)
      assert formatted =~ "18.2.0"
    end

    test "all satisfied message" do
      assert "All peer dependencies satisfied." = NPM.Dependency.Peer.Check.format_issues([])
    end
  end

  describe "summary" do
    test "counts by status" do
      issues = [
        %{package: "a", peer: "x", required: "^1", status: :missing, installed: nil},
        %{package: "b", peer: "y", required: "^2", status: :incompatible, installed: "1.0"},
        %{package: "c", peer: "z", required: "^3", status: :optional_missing, installed: nil}
      ]

      s = NPM.Dependency.Peer.Check.summary(issues)
      assert s.missing == 1
      assert s.incompatible == 1
      assert s.optional_missing == 1
      assert s.total == 3
    end

    test "empty issues" do
      s = NPM.Dependency.Peer.Check.summary([])
      assert s.total == 0
    end
  end
end
