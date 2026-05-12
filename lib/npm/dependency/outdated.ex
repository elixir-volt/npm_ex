defmodule NPM.Dependency.Outdated do
  @moduledoc """
  Checks for outdated packages by comparing installed versions
  against the latest available versions on the registry.
  """

  @type outdated_entry :: %{
          name: String.t(),
          current: String.t(),
          wanted: String.t(),
          latest: String.t(),
          type: :major | :minor | :patch | :current
        }

  @doc """
  Checks a lockfile against wanted ranges and latest versions.

  Given a lockfile (installed versions) and deps (wanted ranges from package.json),
  and a map of latest versions from the registry, returns a list of outdated entries.
  """
  @spec check(map(), map(), map()) :: [outdated_entry()]
  def check(lockfile, deps, latest_versions) do
    deps
    |> Enum.flat_map(&check_package(&1, lockfile, latest_versions))
    |> Enum.sort_by(& &1.name)
  end

  defp check_package({name, range}, lockfile, latest_versions) do
    case Map.get(lockfile, name) do
      nil -> []
      entry -> build_entry(name, entry.version, range, latest_versions)
    end
  end

  defp build_entry(name, current, range, latest_versions) do
    latest = Map.get(latest_versions, name, current)

    wanted =
      case NPM.SemverUtil.max_satisfying(available_versions(latest), range) do
        {:ok, v} -> v
        _ -> current
      end

    case NPM.SemverUtil.update_type(current, latest) do
      :none -> []
      type -> [%{name: name, current: current, wanted: wanted, latest: latest, type: type}]
    end
  end

  @doc """
  Filters outdated entries by update type.
  """
  @spec filter_by_type([outdated_entry()], :major | :minor | :patch) :: [outdated_entry()]
  def filter_by_type(entries, type) do
    Enum.filter(entries, &(&1.type == type))
  end

  @doc """
  Formats an outdated entry as a human-readable string.
  """
  @spec format_entry(outdated_entry()) :: String.t()
  def format_entry(entry) do
    "#{entry.name}  #{entry.current} → #{entry.latest} (wanted: #{entry.wanted})"
  end

  @doc """
  Returns a summary of outdated packages.
  """
  @spec summary([outdated_entry()]) :: %{
          total: non_neg_integer(),
          major: non_neg_integer(),
          minor: non_neg_integer(),
          patch: non_neg_integer()
        }
  def summary(entries) do
    %{
      total: length(entries),
      major: Enum.count(entries, &(&1.type == :major)),
      minor: Enum.count(entries, &(&1.type == :minor)),
      patch: Enum.count(entries, &(&1.type == :patch))
    }
  end

  defp available_versions(latest) do
    [latest]
  end
end
