defmodule NPM.Registry do
  @moduledoc """
  HTTP client for the npm registry.

  Fetches abbreviated packuments (version list + deps + dist info)
  using the npm registry API.
  """

  @default_registry "https://registry.npmjs.org"
  @max_retries 3

  @type packument :: %{
          name: String.t(),
          versions: %{String.t() => version_info()}
        }

  @type version_info :: %{
          dependencies: %{String.t() => String.t()},
          dist: %{tarball: String.t(), integrity: String.t()}
        }

  @doc "Get the configured registry URL."
  @spec registry_url :: String.t()
  def registry_url do
    System.get_env("NPM_REGISTRY") || @default_registry
  end

  @doc "Fetch the abbreviated packument for a package."
  @spec get_packument(String.t()) :: {:ok, packument()} | {:error, term()}
  def get_packument(package) do
    url = "#{registry_url()}/#{encode_package(package)}"
    headers = auth_headers() ++ [accept: "application/vnd.npm.install-v1+json"]

    fetch_with_retry(url, headers, @max_retries)
  end

  defp fetch_with_retry(url, headers, retries_left) do
    result = Req.get(url, headers: headers)

    case classify_result(result) do
      {:ok, body} -> {:ok, parse_packument(body)}
      {:retry, _} when retries_left > 0 -> retry(url, headers, retries_left)
      {_, error} -> error
    end
  end

  defp classify_result({:ok, %{status: 200, body: body}}), do: {:ok, body}
  defp classify_result({:ok, %{status: 404}}), do: {:error, {:error, :not_found}}
  defp classify_result({:ok, %{status: 401}}), do: {:error, {:error, :unauthorized}}
  defp classify_result({:ok, %{status: 403}}), do: {:error, {:error, :forbidden}}
  defp classify_result({:ok, %{status: s}}) when s >= 500, do: {:retry, {:error, {:http, s}}}
  defp classify_result({:ok, %{status: s}}), do: {:error, {:error, {:http, s}}}
  defp classify_result({:error, reason}), do: {:retry, {:error, reason}}

  defp retry(url, headers, retries_left) do
    Process.sleep(1000 * (@max_retries - retries_left + 1))
    fetch_with_retry(url, headers, retries_left - 1)
  end

  defp auth_headers do
    case System.get_env("NPM_TOKEN") do
      nil -> []
      token -> [authorization: "Bearer #{token}"]
    end
  end

  defp encode_package(package), do: String.replace(package, "/", "%2f")

  defp parse_packument(data) do
    versions =
      for {version_str, info} <- Map.get(data, "versions", %{}), into: %{} do
        {version_str, parse_version_info(info)}
      end

    %{name: Map.get(data, "name", ""), versions: versions}
  end

  defp parse_version_info(info) do
    dist = Map.get(info, "dist", %{})

    %{
      dependencies: Map.get(info, "dependencies", %{}),
      peer_dependencies: Map.get(info, "peerDependencies", %{}),
      optional_dependencies: Map.get(info, "optionalDependencies", %{}),
      bin: parse_bin(info),
      engines: Map.get(info, "engines", %{}),
      dist: %{
        tarball: Map.get(dist, "tarball", ""),
        integrity: Map.get(dist, "integrity", "")
      }
    }
  end

  defp parse_bin(%{"bin" => bin}) when is_map(bin), do: bin
  defp parse_bin(%{"bin" => bin}) when is_binary(bin), do: %{}
  defp parse_bin(_), do: %{}
end
