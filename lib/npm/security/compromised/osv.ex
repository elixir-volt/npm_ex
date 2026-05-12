defmodule NPM.Security.Compromised.OSV do
  @moduledoc """
  Optional OSV.dev lookup for malicious npm package advisories.

  The OpenSSF malicious-packages dataset is published in OSV format and is
  ingested by OSV.dev. Calls are opt-in so normal installs remain offline and
  deterministic unless a caller explicitly enables online checks.
  """

  @endpoint "https://api.osv.dev/v1/query"

  @doc "Build the OSV package-version query body for an npm package."
  @spec query_body(String.t(), String.t()) :: map()
  def query_body(package, version) do
    %{"package" => %{"name" => package, "ecosystem" => "npm"}, "version" => version}
  end

  @doc "Query OSV.dev for one npm package version."
  @spec query_package(String.t(), String.t(), keyword()) :: {:ok, [map()]} | {:error, term()}
  def query_package(package, version, opts \\ []) do
    endpoint = Keyword.get(opts, :endpoint, @endpoint)

    request = [
      json: query_body(package, version),
      receive_timeout: Keyword.get(opts, :timeout, 10_000)
    ]

    case Req.post(endpoint, request) do
      {:ok, %{status: status, body: %{"vulns" => vulns}}} when status in 200..299 ->
        {:ok, Enum.filter(vulns, &malicious_advisory?/1)}

      {:ok, %{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc "Return whether an OSV advisory is a malicious-package report."
  @spec malicious_advisory?(map()) :: boolean()
  def malicious_advisory?(%{"id" => "MAL-" <> _}), do: true

  def malicious_advisory?(%{"database_specific" => %{"malicious-packages-origins" => origins}})
      when is_list(origins) do
    origins != []
  end

  def malicious_advisory?(%{"summary" => summary}) when is_binary(summary) do
    summary |> String.downcase() |> String.contains?("malicious")
  end

  def malicious_advisory?(_), do: false
end
