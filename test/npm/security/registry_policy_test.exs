defmodule NPM.Security.RegistryPolicyTest do
  use ExUnit.Case, async: false

  alias NPM.Security.RegistryPolicy

  setup do
    original_allowed = Application.get_env(:npm, :allowed_registries)
    original_registry = Application.get_env(:npm, :registry)
    original_mirror = Application.get_env(:npm, :mirror)
    original_env = System.get_env("NPM_EX_ALLOWED_REGISTRIES")

    on_exit(fn ->
      restore_app(:allowed_registries, original_allowed)
      restore_app(:registry, original_registry)
      restore_app(:mirror, original_mirror)
      restore_env("NPM_EX_ALLOWED_REGISTRIES", original_env)
    end)
  end

  test "normalizes allowed registry origins" do
    Application.put_env(:npm, :allowed_registries, [
      "https://registry.npmjs.org/foo",
      "https://mirror.example/"
    ])

    assert RegistryPolicy.allowed_origins() == [
             "https://registry.npmjs.org",
             "https://mirror.example"
           ]
  end

  test "allows tarballs from configured registry origins" do
    Application.put_env(:npm, :allowed_registries, ["https://registry.npmjs.org"])

    assert :ok =
             RegistryPolicy.validate_url!(
               "https://registry.npmjs.org/lodash/-/lodash-4.17.21.tgz"
             )
  end

  test "rejects tarballs from unexpected origins" do
    Application.put_env(:npm, :allowed_registries, ["https://registry.npmjs.org"])

    assert_raise RegistryPolicy.Error, ~r/untrusted npm registry URL/, fn ->
      RegistryPolicy.validate_url!("https://evil.example/pkg.tgz")
    end
  end

  defp restore_app(key, nil), do: Application.delete_env(:npm, key)
  defp restore_app(key, value), do: Application.put_env(:npm, key, value)

  defp restore_env(key, nil), do: System.delete_env(key)
  defp restore_env(key, value), do: System.put_env(key, value)
end
