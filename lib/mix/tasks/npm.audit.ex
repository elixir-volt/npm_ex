defmodule Mix.Tasks.Npm.Audit do
  @shortdoc "Check for security vulnerabilities"

  @moduledoc """
  Check installed packages for known security vulnerabilities.

      mix npm.audit

  Queries the npm registry audit endpoint for advisories affecting
  the packages in `npm.lock`.
  """

  use Mix.Task

  @impl true
  def run([]) do
    Mix.Task.run("app.config")

    case NPM.Lockfile.read() do
      {:ok, lockfile} when lockfile == %{} ->
        Mix.shell().info("No npm.lock found, run `mix npm.install` first.")

      {:ok, lockfile} ->
        audit(lockfile)

      {:error, reason} ->
        Mix.shell().error("Failed to read lockfile: #{inspect(reason)}")
    end
  end

  def run(_) do
    Mix.shell().error("Usage: mix npm.audit")
  end

  defp audit(lockfile) do
    payload = build_audit_payload(lockfile)
    url = "#{NPM.Registry.registry_url()}/-/npm/v1/security/audits"

    case Req.post(url, json: payload) do
      {:ok, %{status: 200, body: body}} ->
        print_audit_results(body)

      {:ok, %{status: status}} ->
        Mix.shell().info("Audit API returned status #{status}. Checking packages manually...")
        check_deprecated(lockfile)

      {:error, reason} ->
        Mix.shell().error("Audit failed: #{inspect(reason)}")
        check_deprecated(lockfile)
    end
  end

  defp build_audit_payload(lockfile) do
    requires =
      for {name, entry} <- lockfile, into: %{} do
        {name, entry.version}
      end

    dependencies =
      for {name, entry} <- lockfile, into: %{} do
        {name, %{"version" => entry.version}}
      end

    %{
      "name" => "npm-audit",
      "version" => "0.0.0",
      "requires" => requires,
      "dependencies" => dependencies
    }
  end

  defp print_audit_results(%{"advisories" => advisories}) when map_size(advisories) == 0 do
    Mix.shell().info("No known vulnerabilities found.")
  end

  defp print_audit_results(%{"advisories" => advisories}) do
    count = map_size(advisories)
    Mix.shell().info("Found #{count} advisor#{if count == 1, do: "y", else: "ies"}:")

    Enum.each(advisories, fn {_id, advisory} ->
      severity = Map.get(advisory, "severity", "unknown")
      title = Map.get(advisory, "title", "Unknown")
      module_name = Map.get(advisory, "module_name", "?")
      Mix.shell().info("  [#{severity}] #{module_name}: #{title}")
    end)
  end

  defp print_audit_results(_body) do
    Mix.shell().info("No vulnerability data available.")
  end

  defp check_deprecated(lockfile) do
    lockfile
    |> Task.async_stream(
      fn {name, _entry} -> {name, NPM.Registry.get_packument(name)} end,
      max_concurrency: 8,
      timeout: 30_000
    )
    |> Enum.each(fn
      {:ok, {name, {:ok, packument}}} ->
        version = lockfile[name].version
        info = Map.get(packument.versions, version, %{})

        case Map.get(info, :deprecated) do
          msg when is_binary(msg) and msg != "" ->
            Mix.shell().info("  [deprecated] #{name}@#{version}: #{msg}")

          _ ->
            :ok
        end

      _ ->
        :ok
    end)
  end
end
