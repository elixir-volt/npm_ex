defmodule NPM.PlatformOptional do
  @moduledoc false

  @spec select(map()) :: map()
  def select(optional_dependencies) when map_size(optional_dependencies) == 0, do: %{}

  def select(optional_dependencies) when is_map(optional_dependencies) do
    cache_key = :erlang.phash2(optional_dependencies)

    case Process.get({__MODULE__, cache_key}) do
      nil ->
        result = do_select(optional_dependencies)
        Process.put({__MODULE__, cache_key}, result)
        result

      cached ->
        cached
    end
  end

  defp do_select(optional_dependencies) do
    optional_dependencies
    |> Enum.group_by(fn {name, _range} -> package_family(name) end)
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

  @platform_tokens ~w(darwin linux win32 freebsd android openharmony arm64 x64 ia32 arm x86 ppc64 s390x riscv64 musl gnu msvc gnueabihf musleabihf)

  defp package_family(name) do
    if platform_binding?(name) do
      case Regex.run(~r/^(@[^\/]+\/)/, name) do
        [scope | _] -> scope
        nil ->
          case String.split(name, "-", parts: 2) do
            [prefix, _] -> prefix
            _ -> name
          end
      end
    else
      name
    end
  end

  defp platform_binding?(name) do
    lower = String.downcase(name)
    Enum.count(@platform_tokens, &String.contains?(lower, &1)) >= 2
  end

  @spec current_match(String.t()) :: boolean()
  def current_match(name) do
    os = NPM.Platform.current_os()
    cpu = NPM.Platform.current_cpu()
    lower = String.downcase(name)
    String.contains?(lower, os) and String.contains?(lower, cpu)
  end
end
