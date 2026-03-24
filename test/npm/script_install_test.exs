defmodule NPM.ScriptInstallTest do
  use ExUnit.Case, async: false

  @test_opts [__skip_project_check__: true]

  setup do
    :persistent_term.erase(:npm_script_installed)
    :ok
  end

  test "installs packages to content-addressed cache dir" do
    deps = %{"is-number" => "^7.0.0"}
    assert :ok = NPM.ScriptInstall.install(deps, @test_opts)
    assert NPM.ScriptInstall.installed?()

    nm = NPM.ScriptInstall.node_modules_dir!()
    assert File.exists?(Path.join(nm, "is-number/package.json"))
  end

  test "second call with same deps is a noop" do
    deps = %{"is-number" => "^7.0.0"}
    assert :ok = NPM.ScriptInstall.install(deps, @test_opts)
    assert :ok = NPM.ScriptInstall.install(deps, @test_opts)
  end

  test "second call with different deps raises" do
    deps1 = %{"is-number" => "^7.0.0"}
    deps2 = %{"is-odd" => "^3.0.0"}
    assert :ok = NPM.ScriptInstall.install(deps1, @test_opts)

    assert_raise Mix.Error, ~r/same dependencies/, fn ->
      NPM.ScriptInstall.install(deps2, @test_opts)
    end
  end

  test "force reinstalls" do
    deps = %{"is-number" => "^7.0.0"}
    assert :ok = NPM.ScriptInstall.install(deps, @test_opts)
    assert :ok = NPM.ScriptInstall.install(deps, [force: true] ++ @test_opts)
  end

  test "install_dir! raises when not installed" do
    assert_raise Mix.Error, ~r/not been called/, fn ->
      NPM.ScriptInstall.install_dir!()
    end
  end
end
