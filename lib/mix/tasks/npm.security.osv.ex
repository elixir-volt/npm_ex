defmodule Mix.Tasks.Npm.Security.Osv do
  @shortdoc "Query OSV for malicious advisories in npm.lock"

  @moduledoc """
  Query OSV.dev for malicious npm package advisories affecting packages in
  `npm.lock`.

      mix npm.security.osv
      mix npm.security.osv --write priv/security/compromised_packages.json

  The task only records malicious-package advisories (`MAL-*` and equivalent
  OSV records), not general vulnerability advisories.
  """

  use Mix.Task

  alias NPM.JSON
  alias NPM.Security.Compromised

  @impl true
  def run(args) do
    Application.ensure_all_started(:req)

    {opts, argv, invalid} = OptionParser.parse(args, strict: [write: :string])

    case {argv, invalid} do
      {[], []} -> run_query(opts)
      _ -> Mix.shell().error("Usage: mix npm.security.osv [--write path]")
    end
  end

  defp run_query(opts) do
    case NPM.Lockfile.read() do
      {:ok, lockfile} ->
        findings = Compromised.check(lockfile, sources: [:osv], online?: true)
        advisories = findings |> Enum.map(& &1.advisory) |> Enum.uniq_by(& &1["id"])

        report(findings)
        maybe_write(opts[:write], advisories)

      {:error, reason} ->
        Mix.shell().error("Failed to read npm.lock: #{inspect(reason)}")
    end
  end

  defp report([]),
    do: Mix.shell().info("No malicious OSV advisories found for npm.lock packages.")

  defp report(findings) do
    Mix.shell().error("Found #{length(findings)} malicious OSV advisory matches:")
    findings |> Compromised.format_findings() |> Enum.each(&Mix.shell().error("  #{&1}"))
  end

  defp maybe_write(nil, _advisories), do: :ok

  defp maybe_write(path, advisories) do
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, JSON.encode_pretty(advisories))
    Mix.shell().info("Wrote #{length(advisories)} OSV advisories to #{path}")
  end
end
