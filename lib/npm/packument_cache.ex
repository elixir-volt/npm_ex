defmodule NPM.PackumentCache do
  @moduledoc false

  @default_ttl_seconds 3600

  def dir do
    Path.join(NPM.Cache.dir(), "packuments")
  end

  @spec get(String.t()) :: {:ok, term()} | :miss
  def get(package) do
    path = path_for(package)

    with {:ok, %{mtime: mtime}} <- File.stat(path, time: :posix),
         true <- System.os_time(:second) - mtime < ttl(),
         {:ok, data} <- File.read(path) do
      {:ok, :erlang.binary_to_term(data)}
    else
      _ -> :miss
    end
  rescue
    _ -> :miss
  end

  @spec put(String.t(), term()) :: :ok
  def put(package, packument) do
    path = path_for(package)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, :erlang.term_to_binary(packument))
    :ok
  end

  defp path_for(package) do
    encoded = String.replace(package, "/", "__")
    Path.join(dir(), "#{encoded}.etf")
  end

  defp ttl do
    Application.get_env(:npm, :packument_cache_ttl, @default_ttl_seconds)
  end
end
