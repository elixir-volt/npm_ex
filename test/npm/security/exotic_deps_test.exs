defmodule NPM.Security.ExoticDepsTest do
  use ExUnit.Case, async: false

  setup do
    previous_env = System.get_env("NPM_EX_BLOCK_EXOTIC_SUBDEPS")
    previous_config = Application.get_env(:npm, :block_exotic_subdeps)
    previous_exotic_deps = Application.get_env(:npm, :exotic_deps)

    on_exit(fn ->
      restore_env("NPM_EX_BLOCK_EXOTIC_SUBDEPS", previous_env)
      restore_config(:block_exotic_subdeps, previous_config)
      restore_config(:exotic_deps, previous_exotic_deps)
    end)

    :ok
  end

  test "detects exotic dependency specs" do
    assert NPM.Security.ExoticDeps.exotic?("github:tanstack/router#abc")
    assert NPM.Security.ExoticDeps.exotic?("git+https://github.com/user/repo.git")
    assert NPM.Security.ExoticDeps.exotic?("https://example.com/pkg.tgz")
    assert NPM.Security.ExoticDeps.exotic?("file:../local")
    assert NPM.Security.ExoticDeps.exotic?("user/repo#abc")

    refute NPM.Security.ExoticDeps.exotic?("^1.2.3")
    refute NPM.Security.ExoticDeps.exotic?("latest")
    refute NPM.Security.ExoticDeps.exotic?("npm:react@^18")
  end

  test "raises for transitive exotic optional dependencies by default" do
    info = %{
      dependencies: %{},
      optional_dependencies: %{"@tanstack/setup" => "github:tanstack/router#79ac49"}
    }

    assert_raise NPM.Security.ExoticDeps.Error,
                 ~r/@tanstack\/setup: github:tanstack\/router/,
                 fn ->
                   NPM.Security.ExoticDeps.validate!("@tanstack/history", "1.161.12", info)
                 end
  end

  test "blocks direct exotic dependencies unless allowed" do
    assert_raise NPM.Security.ExoticDeps.Error, ~r/exotic direct dependency/, fn ->
      NPM.Security.ExoticDeps.validate_direct!("local-pkg", "file:../local-pkg")
    end

    Application.put_env(:npm, :exotic_deps, ["file:../local-pkg"])

    assert :ok = NPM.Security.ExoticDeps.validate_direct!("local-pkg", "file:../local-pkg")
  end

  test "can be disabled through env var" do
    System.put_env("NPM_EX_BLOCK_EXOTIC_SUBDEPS", "false")

    info = %{
      dependencies: %{"payload" => "https://example.com/payload.tgz"},
      optional_dependencies: %{}
    }

    assert :ok = NPM.Security.ExoticDeps.validate!("pkg", "1.0.0", info)
  end

  defp restore_env(name, nil), do: System.delete_env(name)
  defp restore_env(name, value), do: System.put_env(name, value)

  defp restore_config(key, nil), do: Application.delete_env(:npm, key)
  defp restore_config(key, value), do: Application.put_env(:npm, key, value)
end
