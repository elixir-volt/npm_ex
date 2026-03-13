defmodule NPM.GraphOps do
  @moduledoc """
  Advanced graph operations on dependency graphs.

  Builds on NPM.DepGraph's adjacency list to provide transitive closure,
  shortest path, depth analysis, and dependency impact scoring.
  """

  @doc """
  Computes the transitive closure — all reachable packages from a root.
  """
  @spec transitive_deps(map(), String.t()) :: MapSet.t()
  def transitive_deps(adj, root) do
    walk(adj, [root], MapSet.new())
  end

  @doc """
  Finds the shortest path between two packages.
  """
  @spec shortest_path(map(), String.t(), String.t()) :: [String.t()] | nil
  def shortest_path(adj, from, to) do
    bfs(adj, [{[from]}], MapSet.new([from]), to)
  end

  @doc """
  Computes the maximum depth of a package in the dependency tree.
  """
  @spec max_depth(map(), String.t()) :: non_neg_integer()
  def max_depth(adj, root) do
    depth(adj, root, MapSet.new())
  end

  @doc """
  Computes impact score — how many packages transitively depend on a package.
  """
  @spec impact(map(), String.t()) :: non_neg_integer()
  def impact(adj, package) do
    reverse = reverse_graph(adj)

    if Map.has_key?(reverse, package) do
      reverse |> transitive_deps(package) |> MapSet.size()
    else
      0
    end
  end

  @doc """
  Returns all leaf packages (no dependencies).
  """
  @spec leaves(map()) :: [String.t()]
  def leaves(adj) do
    adj
    |> Enum.filter(fn {_, deps} -> deps == [] end)
    |> Enum.map(&elem(&1, 0))
    |> Enum.sort()
  end

  @doc """
  Returns all root packages (nothing depends on them).
  """
  @spec roots(map()) :: [String.t()]
  def roots(adj) do
    all_deps = adj |> Map.values() |> List.flatten() |> MapSet.new()

    adj
    |> Map.keys()
    |> Enum.reject(&MapSet.member?(all_deps, &1))
    |> Enum.sort()
  end

  @doc """
  Reverses the graph (all edges point the other direction).
  """
  @spec reverse_graph(map()) :: map()
  def reverse_graph(adj) do
    base = Map.new(Map.keys(adj), &{&1, []})

    Enum.reduce(adj, base, fn {name, deps}, acc ->
      Enum.reduce(deps, acc, fn dep, inner ->
        Map.update(inner, dep, [name], &[name | &1])
      end)
    end)
  end

  defp walk(_adj, [], visited), do: visited

  defp walk(adj, [node | rest], visited) do
    deps = Map.get(adj, node, [])
    new_deps = Enum.reject(deps, &MapSet.member?(visited, &1))
    walk(adj, new_deps ++ rest, MapSet.union(visited, MapSet.new(new_deps)))
  end

  defp bfs(_adj, [], _visited, _target), do: nil

  defp bfs(adj, [{path} | rest], visited, target) do
    current = hd(path)

    if current == target do
      Enum.reverse(path)
    else
      neighbors = Map.get(adj, current, [])
      new_paths = for n <- neighbors, not MapSet.member?(visited, n), do: {[n | path]}
      new_visited = MapSet.union(visited, MapSet.new(Enum.map(neighbors, & &1)))
      bfs(adj, rest ++ new_paths, new_visited, target)
    end
  end

  defp depth(adj, node, visited) do
    if MapSet.member?(visited, node) do
      0
    else
      deps = Map.get(adj, node, [])
      new_visited = MapSet.put(visited, node)

      case deps do
        [] -> 0
        _ -> 1 + (deps |> Enum.map(&depth(adj, &1, new_visited)) |> Enum.max())
      end
    end
  end
end
