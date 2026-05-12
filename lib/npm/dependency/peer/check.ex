defmodule NPM.Dependency.Peer.Check do
  @moduledoc """
  Deep peer dependency compatibility scanner.

  Scans all installed packages for unmet, conflicting, or optional
  peer dependencies and reports compatibility issues.
  """

  @type issue :: %{
          package: String.t(),
          peer: String.t(),
          required: String.t(),
          status: :missing | :incompatible | :optional_missing,
          installed: String.t() | nil
        }

  @doc """
  Scans installed packages for peer dependency issues.
  """
  @spec check(String.t(), map()) :: [issue()]
  def check(node_modules_dir, lockfile) do
    case File.ls(node_modules_dir) do
      {:ok, entries} ->
        entries
        |> Enum.reject(&String.starts_with?(&1, "."))
        |> Enum.flat_map(&check_package(node_modules_dir, &1, lockfile))
        |> Enum.sort_by(&{&1.package, &1.peer})

      _ ->
        []
    end
  end

  @doc """
  Checks a single package's peer dependencies against installed versions.
  """
  @spec check_peers(map(), map()) :: [issue()]
  def check_peers(pkg_data, lockfile) do
    name = pkg_data["name"] || "unknown"
    peers = pkg_data["peerDependencies"] || %{}
    optional = peer_optional_set(pkg_data)

    Enum.flat_map(peers, fn {peer, range} ->
      check_peer(name, peer, range, lockfile, MapSet.member?(optional, peer))
    end)
  end

  @doc """
  Returns only issues of a specific status.
  """
  @spec filter_by_status([issue()], atom()) :: [issue()]
  def filter_by_status(issues, status) do
    Enum.filter(issues, &(&1.status == status))
  end

  @doc """
  Formats issues for display.
  """
  @spec format_issues([issue()]) :: String.t()
  def format_issues([]), do: "All peer dependencies satisfied."

  def format_issues(issues) do
    Enum.map_join(issues, "\n", &format_issue/1)
  end

  @doc """
  Summary of peer dependency status.
  """
  @spec summary([issue()]) :: %{
          missing: non_neg_integer(),
          incompatible: non_neg_integer(),
          optional_missing: non_neg_integer(),
          total: non_neg_integer()
        }
  def summary(issues) do
    %{
      missing: count_status(issues, :missing),
      incompatible: count_status(issues, :incompatible),
      optional_missing: count_status(issues, :optional_missing),
      total: length(issues)
    }
  end

  defp check_package(nm_dir, entry, lockfile) do
    if String.starts_with?(entry, "@") do
      check_scoped(nm_dir, entry, lockfile)
    else
      check_single_package(nm_dir, entry, lockfile)
    end
  end

  defp check_scoped(nm_dir, scope, lockfile) do
    scope_dir = Path.join(nm_dir, scope)

    case File.ls(scope_dir) do
      {:ok, subs} ->
        Enum.flat_map(subs, fn sub ->
          pkg_dir = Path.join(scope_dir, sub)
          read_and_check_peers(pkg_dir, "#{scope}/#{sub}", lockfile)
        end)

      _ ->
        []
    end
  end

  defp check_single_package(nm_dir, name, lockfile) do
    pkg_dir = Path.join(nm_dir, name)
    read_and_check_peers(pkg_dir, name, lockfile)
  end

  defp read_and_check_peers(pkg_dir, name, lockfile) do
    pkg_json = Path.join(pkg_dir, "package.json")

    case File.read(pkg_json) do
      {:ok, content} ->
        data = :json.decode(content) |> Map.put("name", name)
        check_peers(data, lockfile)

      _ ->
        []
    end
  rescue
    _ -> []
  end

  defp check_peer(package, peer, range, lockfile, is_optional) do
    case Map.get(lockfile, peer) do
      nil ->
        status = if is_optional, do: :optional_missing, else: :missing
        [%{package: package, peer: peer, required: range, status: status, installed: nil}]

      %{version: version} ->
        if NPMSemver.matches?(version, range) do
          []
        else
          [
            %{
              package: package,
              peer: peer,
              required: range,
              status: :incompatible,
              installed: version
            }
          ]
        end

      _ ->
        []
    end
  rescue
    _ -> []
  end

  defp peer_optional_set(pkg_data) do
    case pkg_data["peerDependenciesMeta"] do
      meta when is_map(meta) ->
        meta
        |> Enum.filter(fn {_k, v} -> is_map(v) and v["optional"] == true end)
        |> Enum.map(&elem(&1, 0))
        |> MapSet.new()

      _ ->
        MapSet.new()
    end
  end

  defp format_issue(%{status: :missing} = i) do
    "✗ #{i.package} requires #{i.peer}@#{i.required} — not installed"
  end

  defp format_issue(%{status: :incompatible} = i) do
    "✗ #{i.package} requires #{i.peer}@#{i.required} — installed #{i.installed}"
  end

  defp format_issue(%{status: :optional_missing} = i) do
    "? #{i.package} optionally requires #{i.peer}@#{i.required} — not installed"
  end

  defp count_status(issues, status) do
    Enum.count(issues, &(&1.status == status))
  end
end
