defmodule NPM.Dependency.Duplicate do
  @moduledoc """
  Finds packages installed at multiple versions in the dependency tree.

  Duplicates inflate node_modules size and can cause subtle bugs
  when multiple copies of a library coexist.
  """

  @doc """
  Scans the lockfile for packages present at different versions.
  """
  @spec find(map()) :: [%{name: String.t(), versions: [String.t()]}]
  def find(lockfile) do
    lockfile
    |> Enum.group_by(fn {name, _} -> base_name(name) end, fn {_, entry} ->
      entry_version(entry)
    end)
    |> Enum.filter(fn {_name, versions} -> length(Enum.uniq(versions)) > 1 end)
    |> Enum.map(fn {name, versions} ->
      %{name: name, versions: versions |> Enum.uniq() |> Enum.sort()}
    end)
    |> Enum.sort_by(& &1.name)
  end

  @doc """
  Counts total duplicate packages.
  """
  @spec count(map()) :: non_neg_integer()
  def count(lockfile), do: lockfile |> find() |> length()

  @doc """
  Formats duplicate report for display.
  """
  @spec format_report([%{name: String.t(), versions: [String.t()]}]) :: String.t()
  def format_report([]), do: "No duplicate packages found."

  def format_report(dupes) do
    header = "Duplicate packages (#{length(dupes)}):\n"

    body =
      Enum.map_join(dupes, "\n", fn d ->
        "  #{d.name}: #{Enum.join(d.versions, ", ")}"
      end)

    header <> body
  end

  @doc """
  Returns the potential disk savings if duplicates were deduped.
  """
  @spec potential_savings([%{name: String.t(), versions: [String.t()]}]) :: non_neg_integer()
  def potential_savings(dupes) do
    Enum.sum(Enum.map(dupes, fn d -> length(d.versions) - 1 end))
  end

  defp base_name(name) do
    name
    |> String.split("/")
    |> case do
      ["@" <> _ = scope, pkg] -> "#{scope}/#{pkg}"
      [pkg | _] -> pkg
    end
  end

  defp entry_version(%{version: v}), do: v
  defp entry_version(%{"version" => v}), do: v
  defp entry_version(_), do: "unknown"
end
