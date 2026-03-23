defmodule NPM.PlatformOptionalTest do
  use ExUnit.Case, async: false

  test "select keeps only one matching ox binding family entry" do
    darwin = %{
      name: "@oxfmt/binding-darwin-arm64",
      versions: %{
        "0.37.0" => %{
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

    linux = %{
      name: "@oxfmt/binding-linux-x64-gnu",
      versions: %{
        "0.37.0" => %{
          dependencies: %{},
          optional_dependencies: %{},
          peer_dependencies: %{},
          peer_dependencies_meta: %{},
          bin: %{},
          engines: %{},
          os: ["linux"],
          cpu: ["x64"],
          has_install_script: false,
          deprecated: nil,
          dist: %{tarball: "", integrity: "", file_count: nil, unpacked_size: nil}
        }
      }
    }

    NPM.Resolver.clear_cache()
    NPM.Resolver.versions(nil, "__missing__")
    :ets.insert(:npm_resolver_cache, {"@oxfmt/binding-darwin-arm64", darwin})
    :ets.insert(:npm_resolver_cache, {"@oxfmt/binding-linux-x64-gnu", linux})

    selected =
      NPM.PlatformOptional.select(%{
        "@oxfmt/binding-darwin-arm64" => "0.37.0",
        "@oxfmt/binding-linux-x64-gnu" => "0.37.0"
      })

    assert selected == %{"@oxfmt/binding-darwin-arm64" => "0.37.0"}
    assert NPM.PlatformOptional.current_match("@oxfmt/binding-darwin-arm64")
    refute NPM.PlatformOptional.current_match("@oxfmt/binding-linux-x64-gnu")
  after
    NPM.Resolver.clear_cache()
  end
end
