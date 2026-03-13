defmodule Mix.Tasks.Npm.Stats do
  @shortdoc "Show dependency statistics"

  @moduledoc """
  Display statistics about the npm dependency graph.

      mix npm.stats

  Shows: total packages, direct deps, transitive deps, max depth,
  leaf count, and fan-in/fan-out leaders.
  """

  use Mix.Task

  @impl true
  def run([]) do
    Mix.Task.run("app.config")

    with {:ok, %{dependencies: deps, dev_dependencies: dev_deps}} <- NPM.PackageJSON.read_all(),
         {:ok, lockfile} when lockfile != %{} <- NPM.Lockfile.read() do
      all_deps = Map.merge(deps, dev_deps)
      adj = NPM.DepGraph.adjacency_list(lockfile)
      fin = NPM.DepGraph.fan_in(adj)
      fout = NPM.DepGraph.fan_out(adj)

      Mix.shell().info("NPM dependency statistics:")
      Mix.shell().info("  Total packages:   #{map_size(lockfile)}")
      Mix.shell().info("  Direct deps:      #{map_size(all_deps)}")
      Mix.shell().info("  Transitive deps:  #{map_size(lockfile) - map_size(all_deps)}")
      Mix.shell().info("  Leaf packages:    #{length(NPM.DepGraph.leaves(adj))}")

      print_top("Most depended on", fin)
      print_top("Most dependencies", fout)
    else
      {:ok, lockfile} when lockfile == %{} ->
        Mix.shell().info("No packages installed.")

      error ->
        Mix.shell().error("Error: #{inspect(error)}")
    end
  end

  def run(_) do
    Mix.shell().error("Usage: mix npm.stats")
  end

  defp print_top(label, map) do
    top =
      map
      |> Enum.sort_by(fn {_, v} -> -v end)
      |> Enum.take(5)
      |> Enum.filter(fn {_, v} -> v > 0 end)

    if top != [] do
      Mix.shell().info("\n  #{label}:")

      Enum.each(top, fn {name, count} ->
        Mix.shell().info("    #{name}: #{count}")
      end)
    end
  end
end
