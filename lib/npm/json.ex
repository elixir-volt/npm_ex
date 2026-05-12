defmodule NPM.JSON do
  @moduledoc """
  Deterministic JSON encoding helpers used for generated npm files.

  Elixir's built-in JSON encoder does not guarantee object key ordering. This
  module writes maps with sorted keys so files such as `npm.lock` remain stable
  across repeated writes, which keeps diffs small and reproducible.
  """

  @doc "Encode a term as pretty-printed JSON with sorted keys."
  @spec encode_pretty(term()) :: String.t()
  def encode_pretty(data) do
    do_encode(data, 0)
    |> IO.iodata_to_binary()
    |> Kernel.<>("\n")
  end

  defp do_encode(map, indent) when is_map(map) do
    if map_size(map) == 0 do
      "{}"
    else
      entries =
        map
        |> Enum.sort_by(&elem(&1, 0))
        |> Enum.map_join(",\n", fn {k, v} ->
          "#{pad(indent + 1)}#{encode_scalar(k)}: #{do_encode(v, indent + 1)}"
        end)

      "{\n#{entries}\n#{pad(indent)}}"
    end
  end

  defp do_encode(list, indent) when is_list(list) do
    if list == [] do
      "[]"
    else
      entries =
        Enum.map_join(list, ",\n", fn v ->
          "#{pad(indent + 1)}#{do_encode(v, indent + 1)}"
        end)

      "[\n#{entries}\n#{pad(indent)}]"
    end
  end

  defp do_encode(value, _indent), do: encode_scalar(value)

  defp encode_scalar(value) do
    :json.encode(value) |> IO.iodata_to_binary()
  end

  defp pad(level), do: String.duplicate("  ", level)
end
