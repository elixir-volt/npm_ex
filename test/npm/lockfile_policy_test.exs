defmodule NPM.LockfilePolicyTest do
  use ExUnit.Case, async: false

  setup do
    original_block = Application.get_env(:npm, :block_exotic_subdeps)
    original_exotic = Application.get_env(:npm, :exotic_deps)
    original_allowed = Application.get_env(:npm, :allowed_registries)
    original_redirects = Application.get_env(:npm, :allow_registry_redirects)

    on_exit(fn ->
      restore_app(:block_exotic_subdeps, original_block)
      restore_app(:exotic_deps, original_exotic)
      restore_app(:allowed_registries, original_allowed)
      restore_app(:allow_registry_redirects, original_redirects)
    end)
  end

  @tag :tmp_dir
  test "writes and reads lockfile security policy", %{tmp_dir: dir} do
    path = Path.join(dir, "npm.lock")

    Application.put_env(:npm, :block_exotic_subdeps, true)
    Application.put_env(:npm, :exotic_deps, ["file:../local"])
    Application.put_env(:npm, :allowed_registries, ["https://registry.npmjs.org"])
    Application.put_env(:npm, :allow_registry_redirects, false)

    :ok = NPM.Lockfile.write(%{}, path)

    assert {:ok,
            %{
              "block_exotic_subdeps" => true,
              "exotic_deps" => ["file:../local"],
              "allowed_registries" => ["https://registry.npmjs.org"],
              "allow_registry_redirects" => false
            }} = NPM.Lockfile.read_policy(path)
  end

  test "detects weaker or incompatible recorded policies" do
    Application.put_env(:npm, :block_exotic_subdeps, true)
    Application.put_env(:npm, :exotic_deps, [])
    Application.put_env(:npm, :allowed_registries, ["https://registry.npmjs.org"])
    Application.put_env(:npm, :allow_registry_redirects, false)

    refute NPM.Lockfile.policy_matches?(nil)
    refute NPM.Lockfile.policy_matches?(%{"block_exotic_subdeps" => false})

    assert NPM.Lockfile.policy_matches?(%{
             "block_exotic_subdeps" => true,
             "exotic_deps" => [],
             "allowed_registries" => ["https://registry.npmjs.org"],
             "allow_registry_redirects" => false
           })
  end

  defp restore_app(key, nil), do: Application.delete_env(:npm, key)
  defp restore_app(key, value), do: Application.put_env(:npm, key, value)
end
