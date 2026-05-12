defmodule NPM.Dependency.Graph do
  @moduledoc """
  Dependency graph operations on the lockfile.

  Provides adjacency-list based graph algorithms for analyzing
  the dependency structure: detecting cycles, computing fan-in/out,
  and finding orphans.
  """

  @doc """
  Build an adjacency list from the lockfile.

  Returns `%{name => [dep_name, ...]}`.
  """
  @spec adjacency_list(%{String.t() => NPM.Lockfile.entry()}) :: %{String.t() => [String.t()]}
  def adjacency_list(lockfile) do
    Map.new(lockfile, fn {name, entry} ->
      {name, Map.keys(entry.dependencies) |> Enum.sort()}
    end)
  end

  @doc """
  Compute fan-out (number of dependencies) for each package.
  """
  @spec fan_out(%{String.t() => [String.t()]}) :: %{String.t() => non_neg_integer()}
  def fan_out(adj) do
    Map.new(adj, fn {name, deps} -> {name, length(deps)} end)
  end

  @doc """
  Compute fan-in (number of dependents) for each package.
  """
  @spec fan_in(%{String.t() => [String.t()]}) :: %{String.t() => non_neg_integer()}
  def fan_in(adj) do
    all_names = Map.keys(adj)
    base = Map.new(all_names, &{&1, 0})

    Enum.reduce(adj, base, fn {_name, deps}, acc ->
      Enum.reduce(deps, acc, fn dep, inner_acc ->
        Map.update(inner_acc, dep, 1, &(&1 + 1))
      end)
    end)
  end

  @doc """
  Find leaf packages (no dependencies).
  """
  @spec leaves(%{String.t() => [String.t()]}) :: [String.t()]
  def leaves(adj) do
    adj
    |> Enum.filter(fn {_, deps} -> deps == [] end)
    |> Enum.map(&elem(&1, 0))
    |> Enum.sort()
  end

  @doc """
  Find root packages (not depended on by any other package).
  """
  @spec roots(%{String.t() => [String.t()]}) :: [String.t()]
  def roots(adj) do
    all_deps = adj |> Map.values() |> List.flatten() |> MapSet.new()
    adj |> Map.keys() |> Enum.reject(&MapSet.member?(all_deps, &1)) |> Enum.sort()
  end

  @doc """
  Detect circular dependencies. Returns list of cycle paths.

  Uses Erlang's `:digraph_utils` for reliable cycle detection.
  """
  @spec cycles(%{String.t() => [String.t()]}) :: [[String.t()]]
  def cycles(adj) do
    g = :digraph.new()

    try do
      Enum.each(adj, fn {name, _} -> :digraph.add_vertex(g, name) end)

      Enum.each(adj, fn {name, deps} ->
        Enum.each(deps, fn dep ->
          :digraph.add_vertex(g, dep)
          :digraph.add_edge(g, name, dep)
        end)
      end)

      components = :digraph_utils.cyclic_strong_components(g)

      components
      |> Enum.filter(fn component ->
        length(component) > 1 or self_loop?(g, component)
      end)
      |> Enum.map(&Enum.sort/1)
      |> Enum.uniq()
    after
      :digraph.delete(g)
    end
  end

  defp self_loop?(g, [v]) do
    Enum.any?(:digraph.out_edges(g, v), fn edge ->
      {_, ^v, ^v, _} = :digraph.edge(g, edge)
      true
    end)
  rescue
    _ -> false
  end

  defp self_loop?(_, _), do: false
end
