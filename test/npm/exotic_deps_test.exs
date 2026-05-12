defmodule NPM.ExoticDepsTest do
  use ExUnit.Case, async: false

  setup do
    previous_env = System.get_env("NPM_EX_BLOCK_EXOTIC_SUBDEPS")
    previous_config = Application.get_env(:npm, :block_exotic_subdeps)

    on_exit(fn ->
      restore_env("NPM_EX_BLOCK_EXOTIC_SUBDEPS", previous_env)
      restore_config(:block_exotic_subdeps, previous_config)
    end)

    :ok
  end

  test "detects exotic dependency specs" do
    assert NPM.ExoticDeps.exotic?("github:tanstack/router#abc")
    assert NPM.ExoticDeps.exotic?("git+https://github.com/user/repo.git")
    assert NPM.ExoticDeps.exotic?("https://example.com/pkg.tgz")
    assert NPM.ExoticDeps.exotic?("file:../local")
    assert NPM.ExoticDeps.exotic?("user/repo#abc")

    refute NPM.ExoticDeps.exotic?("^1.2.3")
    refute NPM.ExoticDeps.exotic?("latest")
    refute NPM.ExoticDeps.exotic?("npm:react@^18")
  end

  test "raises for transitive exotic optional dependencies by default" do
    info = %{
      dependencies: %{},
      optional_dependencies: %{"@tanstack/setup" => "github:tanstack/router#79ac49"}
    }

    assert_raise NPM.ExoticDeps.Error, ~r/@tanstack\/setup: github:tanstack\/router/, fn ->
      NPM.ExoticDeps.validate!("@tanstack/history", "1.161.12", info)
    end
  end

  test "can be disabled through env var" do
    System.put_env("NPM_EX_BLOCK_EXOTIC_SUBDEPS", "false")

    info = %{
      dependencies: %{"payload" => "https://example.com/payload.tgz"},
      optional_dependencies: %{}
    }

    assert :ok = NPM.ExoticDeps.validate!("pkg", "1.0.0", info)
  end

  defp restore_env(name, nil), do: System.delete_env(name)
  defp restore_env(name, value), do: System.put_env(name, value)

  defp restore_config(key, nil), do: Application.delete_env(:npm, key)
  defp restore_config(key, value), do: Application.put_env(:npm, key, value)
end
