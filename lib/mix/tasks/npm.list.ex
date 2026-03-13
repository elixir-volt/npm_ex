defmodule Mix.Tasks.Npm.List do
  @shortdoc "List installed npm packages"

  @moduledoc """
  List installed npm packages from `npm.lock`.

      mix npm.list

  Shows direct dependencies (from `package.json`) and their locked versions.
  Transitive dependencies are shown indented.
  """

  use Mix.Task

  @impl true
  def run(args) do
    Mix.Task.run("app.config")
    {opts, _, _} = OptionParser.parse(args, strict: [depth: :integer])

    with {:ok, %{dependencies: deps, dev_dependencies: dev_deps}} <-
           NPM.PackageJSON.read_all(),
         {:ok, packages} <- NPM.list() do
      if packages == [] do
        Mix.shell().info("No npm packages installed.")
      else
        print_tree(packages, deps, dev_deps, opts)
      end
    end
  end

  defp print_tree(packages, deps, dev_deps, opts) do
    direct = Map.keys(deps) |> MapSet.new()
    dev = Map.keys(dev_deps) |> MapSet.new()
    max_depth = Keyword.get(opts, :depth, :infinity)

    {direct_pkgs, rest} =
      Enum.split_with(packages, fn {name, _} -> MapSet.member?(direct, name) end)

    {dev_pkgs, transitive_pkgs} =
      Enum.split_with(rest, fn {name, _} -> MapSet.member?(dev, name) end)

    if direct_pkgs != [] do
      Mix.shell().info("dependencies:")

      Enum.each(direct_pkgs, fn {name, version} ->
        range = Map.get(deps, name, "")
        Mix.shell().info("  ├── #{name}@#{version} (#{range})")
      end)
    end

    if dev_pkgs != [] do
      Mix.shell().info("devDependencies:")

      Enum.each(dev_pkgs, fn {name, version} ->
        range = Map.get(dev_deps, name, "")
        Mix.shell().info("  ├── #{name}@#{version} (#{range})")
      end)
    end

    if transitive_pkgs != [] and max_depth != 0 do
      Mix.shell().info("transitive (#{length(transitive_pkgs)}):")

      Enum.each(transitive_pkgs, fn {name, version} ->
        Mix.shell().info("  └── #{name}@#{version}")
      end)
    end

    Mix.shell().info("#{length(packages)} packages total")
  end
end
