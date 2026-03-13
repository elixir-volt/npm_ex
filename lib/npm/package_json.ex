defmodule NPM.PackageJSON do
  @moduledoc """
  Read and write `package.json` files.
  """

  @default_path "package.json"

  @doc "Read dependencies from `package.json`."
  @spec read(String.t()) :: {:ok, %{String.t() => String.t()}} | {:error, term()}
  def read(path \\ @default_path) do
    case File.read(path) do
      {:ok, content} ->
        data = :json.decode(content)
        {:ok, Map.get(data, "dependencies", %{})}

      {:error, :enoent} ->
        {:ok, %{}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc "Read all dependency groups from `package.json`."
  @spec read_all(String.t()) ::
          {:ok, %{dependencies: map(), dev_dependencies: map()}} | {:error, term()}
  def read_all(path \\ @default_path) do
    case File.read(path) do
      {:ok, content} ->
        data = :json.decode(content)

        {:ok,
         %{
           dependencies: Map.get(data, "dependencies", %{}),
           dev_dependencies: Map.get(data, "devDependencies", %{})
         }}

      {:error, :enoent} ->
        {:ok, %{dependencies: %{}, dev_dependencies: %{}}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc "Read scripts from `package.json`."
  @spec read_scripts(String.t()) :: {:ok, %{String.t() => String.t()}} | {:error, term()}
  def read_scripts(path \\ @default_path) do
    case File.read(path) do
      {:ok, content} ->
        data = :json.decode(content)
        {:ok, Map.get(data, "scripts", %{})}

      {:error, :enoent} ->
        {:ok, %{}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Add a dependency to `package.json`, creating the file if needed.

  ## Options

    * `:dev` - when `true`, adds to `devDependencies` instead of `dependencies`
  """
  @spec add_dep(String.t(), String.t(), String.t(), keyword()) :: :ok | {:error, term()}
  def add_dep(name, range, path \\ @default_path, opts \\ []) do
    data = read_raw(path)
    field = if opts[:dev], do: "devDependencies", else: "dependencies"
    deps = Map.get(data, field, %{})
    updated = Map.put(data, field, Map.put(deps, name, range))

    File.write(path, NPM.JSON.encode_pretty(updated))
  end

  @doc "Remove a dependency from `package.json`."
  @spec remove_dep(String.t(), String.t()) :: :ok | {:error, term()}
  def remove_dep(name, path \\ @default_path) do
    data = read_raw(path)
    deps = Map.get(data, "dependencies", %{})
    dev_deps = Map.get(data, "devDependencies", %{})

    cond do
      Map.has_key?(deps, name) ->
        updated = Map.put(data, "dependencies", Map.delete(deps, name))
        File.write(path, NPM.JSON.encode_pretty(updated))

      Map.has_key?(dev_deps, name) ->
        updated = Map.put(data, "devDependencies", Map.delete(dev_deps, name))
        File.write(path, NPM.JSON.encode_pretty(updated))

      true ->
        {:error, {:not_found, name}}
    end
  end

  defp read_raw(path) do
    case File.read(path) do
      {:ok, content} -> :json.decode(content)
      {:error, :enoent} -> %{}
    end
  end
end
