defmodule NPM.ResolverExoticCandidateTest do
  use ExUnit.Case, async: false

  @table :npm_resolver_cache

  setup do
    NPM.Resolver.clear_cache()
    ensure_table!()

    on_exit(fn -> NPM.Resolver.clear_cache() end)

    :ok
  end

  test "versions excludes candidates with blocked transitive exotic dependencies" do
    package = "__exotic_filter__"

    :ets.insert(@table, {
      package,
      %{
        name: package,
        versions: %{
          "1.0.0" => version_info(%{"payload" => "file:./payload"}),
          "1.0.1" => version_info(%{})
        }
      }
    })

    assert {:ok, versions} = NPM.Resolver.versions(nil, package)
    assert versions == [Version.parse!("1.0.1")]
  end

  defp version_info(dependencies) do
    %{
      dependencies: dependencies,
      optional_dependencies: %{},
      peer_dependencies: %{},
      peer_dependencies_meta: %{},
      bin: %{},
      engines: %{},
      os: [],
      cpu: [],
      has_install_script: false,
      deprecated: nil,
      created_at: nil,
      published_at: nil,
      dist: %{tarball: "", integrity: "", file_count: nil, unpacked_size: nil}
    }
  end

  defp ensure_table! do
    if :ets.whereis(@table) == :undefined do
      :ets.new(@table, [:named_table, :set, :public])
    end
  end
end
