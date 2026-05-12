defmodule NPM.Security.AgeTest do
  use ExUnit.Case, async: false

  alias NPM.Security.Age

  setup do
    original_package_days = Application.get_env(:npm, :package_age_warning_days)
    original_version_days = Application.get_env(:npm, :version_age_warning_days)

    on_exit(fn ->
      restore_app(:package_age_warning_days, original_package_days)
      restore_app(:version_age_warning_days, original_version_days)
    end)
  end

  test "warns for recently created packages and published versions" do
    Application.put_env(:npm, :package_age_warning_days, 7)
    Application.put_env(:npm, :version_age_warning_days, 3)

    now = DateTime.utc_now() |> DateTime.to_iso8601()

    warnings = Age.warnings(%{created_at: now, published_at: now})

    assert Enum.any?(warnings, &(&1.type == :new_package))
    assert Enum.any?(warnings, &(&1.type == :new_version))
  end

  test "does not warn when thresholds are disabled" do
    Application.put_env(:npm, :package_age_warning_days, 0)
    Application.put_env(:npm, :version_age_warning_days, 0)

    now = DateTime.utc_now() |> DateTime.to_iso8601()

    assert [] = Age.warnings(%{created_at: now, published_at: now})
  end

  defp restore_app(key, nil), do: Application.delete_env(:npm, key)
  defp restore_app(key, value), do: Application.put_env(:npm, key, value)
end
