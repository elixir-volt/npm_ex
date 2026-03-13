defmodule Mix.Tasks.Npm.Size do
  @shortdoc "Show node_modules size analysis"

  @moduledoc """
  Analyze `node_modules` disk usage.

      mix npm.size
      mix npm.size --top 10

  Shows total size, file count, and per-package breakdown.

  ## Options

    * `--top` — number of largest packages to show (default: 10)
  """

  use Mix.Task

  @impl true
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, strict: [top: :integer])
    top_n = Keyword.get(opts, :top, 10)
    dir = "node_modules"

    total_size = NPM.NodeModules.disk_size(dir)
    total_files = NPM.NodeModules.file_count(dir)

    Mix.shell().info("node_modules analysis:")
    Mix.shell().info("  Total size:  #{format_bytes(total_size)}")
    Mix.shell().info("  Total files: #{total_files}")

    packages = NPM.NodeModules.installed(dir)
    Mix.shell().info("  Packages:    #{length(packages)}")

    if packages != [] do
      Mix.shell().info("\n  Top #{top_n} by size:")
      print_top(dir, packages, top_n)
    end
  end

  defp print_top(dir, packages, top_n) do
    packages
    |> Enum.map(fn name ->
      pkg_dir = Path.join(dir, name)
      size = NPM.NodeModules.disk_size(pkg_dir)
      {name, size}
    end)
    |> Enum.sort_by(fn {_, size} -> -size end)
    |> Enum.take(top_n)
    |> Enum.each(fn {name, size} ->
      Mix.shell().info("    #{format_bytes(size)} #{name}")
    end)
  end

  defp format_bytes(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_bytes(bytes) when bytes < 1_048_576, do: "#{Float.round(bytes / 1024, 1)} KB"
  defp format_bytes(bytes), do: "#{Float.round(bytes / 1_048_576, 1)} MB"
end
