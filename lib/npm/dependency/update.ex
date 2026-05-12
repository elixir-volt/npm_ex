defmodule NPM.Dependency.Update do
  @moduledoc """
  Computes available package updates by comparing locked vs latest versions.
  """

  @doc """
  Classifies an update type.
  """
  @spec update_type(String.t(), String.t()) :: atom()
  def update_type(current, latest) do
    with {:ok, {cm, cmin, cp}} <- NPM.VersionUtil.parse_triple(current),
         {:ok, {lm, lmin, lp}} <- NPM.VersionUtil.parse_triple(latest) do
      cond do
        cm < lm -> :major
        cmin < lmin -> :minor
        cp < lp -> :patch
        true -> :current
      end
    else
      _ -> :current
    end
  end

  @doc """
  Computes all available updates.
  """
  @spec compute([{String.t(), String.t(), String.t()}]) :: [map()]
  def compute(packages) do
    packages
    |> Enum.map(fn {name, current, latest} ->
      %{name: name, current: current, latest: latest, type: update_type(current, latest)}
    end)
    |> Enum.reject(&(&1.type == :current))
    |> Enum.sort_by(fn u -> {type_order(u.type), u.name} end)
  end

  @doc """
  Groups updates by type.
  """
  @spec group_by_type([map()]) :: map()
  def group_by_type(updates) do
    Enum.group_by(updates, & &1.type)
  end

  @doc """
  Counts updates by type.
  """
  @spec summary([map()]) :: map()
  def summary(updates) do
    grouped = group_by_type(updates)

    %{
      total: length(updates),
      major: length(Map.get(grouped, :major, [])),
      minor: length(Map.get(grouped, :minor, [])),
      patch: length(Map.get(grouped, :patch, []))
    }
  end

  @doc """
  Formats updates for display.
  """
  @spec format([map()]) :: String.t()
  def format([]), do: "All packages are up to date."

  def format(updates) do
    Enum.map_join(updates, "\n", fn u ->
      "#{u.name}: #{u.current} → #{u.latest} (#{u.type})"
    end)
  end

  defp type_order(:major), do: 0
  defp type_order(:minor), do: 1
  defp type_order(:patch), do: 2
  defp type_order(_), do: 3
end
