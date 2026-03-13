defmodule Mix.Tasks.Npm.Version do
  @shortdoc "Show npm_ex version"

  @moduledoc """
  Display the installed version of npm_ex.

      mix npm.version
  """

  use Mix.Task

  @impl true
  def run([]) do
    {:ok, version} = :application.get_key(:npm, :vsn)
    Mix.shell().info("npm_ex #{version}")
  end

  def run(_) do
    Mix.shell().error("Usage: mix npm.version")
  end
end
