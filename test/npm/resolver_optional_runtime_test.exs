defmodule NPM.ResolverOptionalRuntimeTest do
  use ExUnit.Case, async: false

  test "includes platform-matching optional dependencies in solver output" do
    parent = %{
      name: "oxlint",
      versions: %{
        "1.0.0" => %{
          dependencies: %{},
          optional_dependencies: %{"@oxlint/binding-darwin-arm64" => "1.0.0"},
          peer_dependencies: %{},
          peer_dependencies_meta: %{},
          bin: %{},
          engines: %{},
          os: [],
          cpu: [],
          has_install_script: false,
          deprecated: nil,
          dist: %{tarball: "", integrity: "", file_count: nil, unpacked_size: nil}
        }
      }
    }

    binding = %{
      name: "@oxlint/binding-darwin-arm64",
      versions: %{
        "1.0.0" => %{
          dependencies: %{},
          optional_dependencies: %{},
          peer_dependencies: %{},
          peer_dependencies_meta: %{},
          bin: %{},
          engines: %{},
          os: ["darwin"],
          cpu: ["arm64"],
          has_install_script: false,
          deprecated: nil,
          dist: %{tarball: "", integrity: "", file_count: nil, unpacked_size: nil}
        }
      }
    }

    NPM.Resolver.clear_cache()
    NPM.Resolver.versions(nil, "__missing__")
    :ets.insert(:npm_resolver_cache, {"oxlint", parent})
    :ets.insert(:npm_resolver_cache, {"@oxlint/binding-darwin-arm64", binding})

    assert {:ok, deps} = NPM.Resolver.dependencies(nil, "oxlint", Version.parse!("1.0.0"))
    assert Enum.any?(deps, &(&1.name == "@oxlint/binding-darwin-arm64"))
  after
    NPM.Resolver.clear_cache()
  end
end
