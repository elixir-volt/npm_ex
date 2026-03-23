defmodule NPM.PlatformOptional do
  @moduledoc false

  @spec select(map()) :: map()
  def select(optional_dependencies) when is_map(optional_dependencies) do
    grouped = Enum.group_by(optional_dependencies, fn {name, _range} -> package_family(name) end)

    grouped
    |> Enum.flat_map(fn {_family, deps} -> select_group(deps) end)
    |> Map.new()
  end

  defp select_group([{name, range}]) do
    [{name, range}]
  end

  defp select_group(deps) do
    exact_matches = Enum.filter(deps, fn {name, _range} -> current_match(name) end)

    cond do
      exact_matches != [] ->
        [List.first(exact_matches)]

      true ->
        matches = Enum.filter(deps, fn {name, _range} -> package_matches_platform?(name) end)
        if matches == [], do: [], else: [Enum.max_by(matches, fn {name, _range} -> platform_score(name) end)]
    end
  end

  defp package_matches_platform?(name) do
    platform_score(name) > 0
  end

  defp platform_score(name) do
    case NPM.Registry.get_packument(name) do
      {:ok, packument} ->
        packument.versions
        |> Map.values()
        |> Enum.map(fn info ->
          os_match = if NPM.Platform.os_compatible?(info.os), do: 1, else: 0
          cpu_match = if NPM.Platform.cpu_compatible?(info.cpu), do: 1, else: 0
          os_match + cpu_match
        end)
        |> Enum.max(fn -> 0 end)

      _ ->
        0
    end
  end

  defp package_family(name) do
    cond do
      String.starts_with?(name, "@oxfmt/binding-") -> "@oxfmt/binding"
      String.starts_with?(name, "@oxlint/binding-") -> "@oxlint/binding"
      true -> name
    end
  end

  @spec current_match(String.t()) :: boolean()
  def current_match(name) do
    current_os = NPM.Platform.current_os()
    current_cpu = NPM.Platform.current_cpu()
    String.contains?(name, "-#{current_os}-") and String.ends_with?(name, "-#{current_cpu}") or
      String.ends_with?(name, "-#{current_os}-#{current_cpu}")
  end
end
