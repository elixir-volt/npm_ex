defmodule NPM.Security.CompromisedTest do
  use ExUnit.Case, async: true

  alias NPM.Security.Compromised
  alias NPM.Security.Compromised.OSV

  @osv_advisory %{
    "id" => "MAL-2025-1",
    "summary" => "malicious npm package",
    "affected" => [
      %{
        "package" => %{"ecosystem" => "npm", "name" => "evil"},
        "versions" => ["1.0.0"]
      }
    ]
  }

  test "checks package versions against local OSV advisories" do
    lockfile = %{
      "evil" => %{version: "1.0.0"},
      "safe" => %{version: "1.0.0"}
    }

    path = write_database!([@osv_advisory])

    assert [finding] = Compromised.check(lockfile, sources: [:local], db_path: path)
    assert finding.package == "evil"
    assert finding.version == "1.0.0"
    assert finding.source == :local
    assert finding.advisory["id"] == "MAL-2025-1"
  end

  test "matches OSV ecosystem ranges" do
    advisory = %{
      "id" => "MAL-2025-2",
      "affected" => [
        %{
          "package" => %{"ecosystem" => "npm", "name" => "range-pkg"},
          "ranges" => [
            %{
              "type" => "ECOSYSTEM",
              "events" => [%{"introduced" => "1.0.0"}, %{"fixed" => "1.2.0"}]
            }
          ]
        }
      ]
    }

    assert Compromised.affects?(advisory, "range-pkg", "1.1.0")
    refute Compromised.affects?(advisory, "range-pkg", "1.2.0")
  end

  test "supports OSV response shaped local databases" do
    path = write_database!(%{"vulns" => [@osv_advisory]})

    assert [finding] =
             Compromised.check_package("evil", "1.0.0", sources: [:local], db_path: path)

    assert finding.advisory["summary"] == "malicious npm package"
  end

  test "falls back to bundled database when cache database is missing" do
    assert {:ok, []} = Compromised.read_database("tmp/no-such-db.json")
  end

  test "exposes shared cache path" do
    assert Compromised.cache_path() =~ "security/compromised_packages.json"
  end

  test "online OSV source is opt-in" do
    assert [] = Compromised.check_package("evil", "1.0.0", sources: [:osv])
  end

  test "builds OSV npm query bodies" do
    assert OSV.query_body("@scope/pkg", "1.0.0") == %{
             "package" => %{"name" => "@scope/pkg", "ecosystem" => "npm"},
             "version" => "1.0.0"
           }

    assert OSV.batch_body([{"evil", "1.0.0"}]) == %{
             "queries" => [
               %{"package" => %{"name" => "evil", "ecosystem" => "npm"}, "version" => "1.0.0"}
             ]
           }
  end

  test "converts findings to JSON maps" do
    finding = %{
      package: "evil",
      version: "1.0.0",
      source: :local,
      advisory: @osv_advisory
    }

    assert Compromised.finding_to_json(finding)["source"] == "local"
  end

  test "identifies malicious OSV advisories" do
    assert OSV.malicious_advisory?(%{"id" => "MAL-2025-2170"})
    assert OSV.malicious_advisory?(%{"summary" => "Malicious package"})
    refute OSV.malicious_advisory?(%{"id" => "GHSA-xxxx"})
  end

  defp write_database!(data) do
    path =
      Path.join(System.tmp_dir!(), "npm-compromised-#{System.unique_integer([:positive])}.json")

    File.write!(path, NPM.JSON.encode_pretty(data))
    path
  end
end
