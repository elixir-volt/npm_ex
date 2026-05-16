defmodule NPM.Security.Compromised.OSVTest do
  use ExUnit.Case, async: true

  alias NPM.Security.Compromised.OSV

  describe "query bodies" do
    test "builds single-package query body" do
      assert OSV.query_body("left-pad", "1.0.0") == %{
               "package" => %{"name" => "left-pad", "ecosystem" => "npm"},
               "version" => "1.0.0"
             }
    end

    test "builds batch query body" do
      assert OSV.batch_body([{"left-pad", "1.0.0"}]) == %{
               "queries" => [OSV.query_body("left-pad", "1.0.0")]
             }
    end
  end

  describe "malicious_advisory?/1" do
    test "recognizes malicious advisory shapes" do
      assert OSV.malicious_advisory?(%{"id" => "MAL-2024-1"})

      assert OSV.malicious_advisory?(%{
               "database_specific" => %{"malicious-packages-origins" => [%{}]}
             })

      assert OSV.malicious_advisory?(%{"summary" => "Malicious npm package"})
    end

    test "rejects non-malicious advisories" do
      refute OSV.malicious_advisory?(%{"id" => "GHSA-xxxx"})
      refute OSV.malicious_advisory?(%{"summary" => "regular vulnerability"})
      refute OSV.malicious_advisory?(%{})
    end
  end
end
