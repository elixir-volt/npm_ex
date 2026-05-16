defmodule NPM.TestStructureTest do
  use ExUnit.Case, async: true

  @allowed_indirect_tests MapSet.new([
                            "install/lockfile_builder.ex"
                          ])

  test "lib/npm modules have matching test files or documented indirect coverage" do
    missing =
      "lib/npm/**/*.ex"
      |> Path.wildcard()
      |> Enum.map(&Path.relative_to(&1, "lib/npm"))
      |> Enum.reject(&matching_test?/1)
      |> MapSet.new()

    assert MapSet.subset?(missing, @allowed_indirect_tests), """
    Modules without matching tests:
    #{missing |> MapSet.difference(@allowed_indirect_tests) |> Enum.sort() |> Enum.join("\n")}
    """
  end

  defp matching_test?(relative_lib_path) do
    test_path =
      relative_lib_path
      |> Path.rootname()
      |> then(&Path.join("test/npm", &1 <> "_test.exs"))

    File.exists?(test_path)
  end
end
