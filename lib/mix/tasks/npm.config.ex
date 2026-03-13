defmodule Mix.Tasks.Npm.Config do
  @shortdoc "Show npm configuration"

  @moduledoc """
  Display the current npm configuration.

      mix npm.config

  Shows registry URL, cache directory, auth status, and other settings.
  """

  use Mix.Task

  @impl true
  def run([]) do
    Mix.Task.run("app.config")

    Mix.shell().info("registry: #{NPM.Registry.registry_url()}")
    Mix.shell().info("cache: #{NPM.Cache.dir()}")
    Mix.shell().info("auth: #{auth_status()}")
    Mix.shell().info("link strategy: #{link_strategy()}")
  end

  def run(_) do
    Mix.shell().error("Usage: mix npm.config")
  end

  defp auth_status do
    if System.get_env("NPM_TOKEN"), do: "token set", else: "none"
  end

  defp link_strategy do
    case :os.type() do
      {:unix, _} -> "symlink"
      _ -> "copy"
    end
  end
end
