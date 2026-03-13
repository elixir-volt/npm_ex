defmodule NPM.PeerDeps do
  @moduledoc """
  Analyzes and validates peer dependency requirements.

  Peer dependencies declare that a package is compatible with a specific
  version of another package that the consumer must provide. This module
  checks whether peer dependency requirements are satisfied.
  """

  @type peer_warning :: %{
          package: String.t(),
          peer: String.t(),
          required: String.t(),
          found: String.t() | nil,
          satisfied: boolean()
        }

  @doc """
  Extracts peer dependencies from a package manifest map.
  Returns a map of %{package_name => required_range}.
  """
  @spec extract(map()) :: map()
  def extract(%{"peerDependencies" => peers}) when is_map(peers), do: peers
  def extract(_), do: %{}

  @doc """
  Extracts peer dependency metadata (which peers are optional).
  Returns a MapSet of optional peer dependency names.
  """
  @spec optional_peers(map()) :: MapSet.t()
  def optional_peers(%{"peerDependenciesMeta" => meta}) when is_map(meta) do
    meta
    |> Enum.filter(fn {_name, opts} -> opts["optional"] == true end)
    |> Enum.map(&elem(&1, 0))
    |> MapSet.new()
  end

  def optional_peers(_), do: MapSet.new()

  @doc """
  Checks peer dependency satisfaction for a set of installed packages.

  Given a lockfile (map of %{name => %{version, ...}}) and a list of
  package manifests with their peerDependencies, returns warnings for
  any unmet peer dependencies.
  """
  @spec check(map(), list(map())) :: list(peer_warning())
  def check(lockfile, manifests) when is_map(lockfile) and is_list(manifests) do
    Enum.flat_map(manifests, &check_manifest(lockfile, &1))
  end

  def check(_, _), do: []

  defp check_manifest(lockfile, manifest) do
    package_name = manifest["name"] || "unknown"
    peers = extract(manifest)
    optional = optional_peers(manifest)

    peers
    |> Enum.reject(fn {name, range} -> peer_ok?(lockfile, name, range, optional) end)
    |> Enum.map(fn {peer_name, required_range} ->
      %{
        package: package_name,
        peer: peer_name,
        required: required_range,
        found: installed_version(lockfile, peer_name),
        satisfied: false
      }
    end)
  end

  defp peer_ok?(lockfile, name, range, optional) do
    MapSet.member?(optional, name) or peer_satisfied?(lockfile, name, range)
  end

  defp peer_satisfied?(lockfile, name, range) do
    case installed_version(lockfile, name) do
      nil -> false
      v -> version_satisfies?(v, range)
    end
  end

  defp installed_version(lockfile, name) do
    case Map.get(lockfile, name) do
      %{version: v} -> v
      _ -> nil
    end
  end

  @doc """
  Summarizes peer dependency status for display.
  Returns a map with :satisfied, :missing, and :incompatible counts.
  """
  @spec summary(list(peer_warning())) :: %{
          satisfied: non_neg_integer(),
          missing: non_neg_integer(),
          incompatible: non_neg_integer()
        }
  def summary(warnings) do
    {missing, incompatible} =
      Enum.reduce(warnings, {0, 0}, fn warning, {m, i} ->
        if warning.found == nil, do: {m + 1, i}, else: {m, i + 1}
      end)

    %{satisfied: 0, missing: missing, incompatible: incompatible}
  end

  @doc """
  Formats peer dependency warnings as human-readable strings.
  """
  @spec format_warnings(list(peer_warning())) :: list(String.t())
  def format_warnings(warnings) do
    Enum.map(warnings, fn w ->
      case w.found do
        nil ->
          "#{w.package} requires #{w.peer}@#{w.required} but it is not installed"

        version ->
          "#{w.package} requires #{w.peer}@#{w.required} but found #{version}"
      end
    end)
  end

  defp version_satisfies?(version, range) do
    case NPMSemver.matches?(version, range) do
      result when is_boolean(result) -> result
      _ -> false
    end
  rescue
    _ -> false
  end
end
