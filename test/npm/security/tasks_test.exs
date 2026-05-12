defmodule NPM.Security.TasksTest do
  use ExUnit.Case, async: false

  alias Mix.Tasks.Npm.Audit

  @advisory %{
    "id" => "MAL-2025-1",
    "summary" => "malicious package",
    "affected" => [
      %{
        "package" => %{"ecosystem" => "npm", "name" => "evil"},
        "versions" => ["1.0.0"]
      }
    ]
  }

  setup do
    Mix.shell(Mix.Shell.Process)

    on_exit(fn ->
      Mix.shell(Mix.Shell.IO)
    end)
  end

  test "local compromised task reports JSON and respects warn policy" do
    dir = tmp_dir()
    lockfile = write_lockfile!(dir)
    db = write_db!(dir)

    Audit.run([
      "--compromised",
      "--lockfile",
      lockfile,
      "--db",
      db,
      "--format",
      "json",
      "--policy",
      "warn"
    ])

    assert_received {:mix_shell, :info, [json]}
    assert %{"findings" => [%{"package" => "evil", "source" => "local"}]} = Jason.decode!(json)
  end

  test "local compromised task raises on findings by default" do
    dir = tmp_dir()
    lockfile = write_lockfile!(dir)
    db = write_db!(dir)

    assert_raise Mix.Error, ~r/Found 1 compromised packages/, fn ->
      Audit.run(["--compromised", "--lockfile", lockfile, "--db", db])
    end
  end

  defp write_lockfile!(dir) do
    path = Path.join(dir, "npm.lock")

    File.write!(
      path,
      NPM.JSON.encode_pretty(%{
        "lockfileVersion" => 1,
        "packages" => %{
          "evil" => %{"version" => "1.0.0"}
        }
      })
    )

    path
  end

  defp write_db!(dir) do
    path = Path.join(dir, "compromised.json")
    File.write!(path, NPM.JSON.encode_pretty([@advisory]))
    path
  end

  defp tmp_dir do
    path = Path.join(System.tmp_dir!(), "npm-security-task-#{System.unique_integer([:positive])}")
    File.mkdir_p!(path)
    path
  end
end
