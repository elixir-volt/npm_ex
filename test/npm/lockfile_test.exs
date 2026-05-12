defmodule NPM.LockfileTest do
  use ExUnit.Case, async: true

  describe "Lockfile.read" do
    @tag :tmp_dir
    test "returns empty map for missing file", %{tmp_dir: dir} do
      assert {:ok, %{}} = NPM.Lockfile.read(Path.join(dir, "npm.lock"))
    end
  end

  describe "Lockfile round-trip" do
    @tag :tmp_dir
    test "write and read preserves all fields", %{tmp_dir: dir} do
      path = Path.join(dir, "npm.lock")

      lockfile = %{
        "lodash" => %{
          version: "4.17.21",
          integrity: "sha512-abc123==",
          tarball: "https://registry.npmjs.org/lodash/-/lodash-4.17.21.tgz",
          dependencies: %{}
        }
      }

      assert :ok = NPM.Lockfile.write(lockfile, path)
      assert {:ok, read_back} = NPM.Lockfile.read(path)
      assert read_back["lodash"].version == "4.17.21"
      assert read_back["lodash"].integrity == "sha512-abc123=="
      assert read_back["lodash"].tarball =~ "lodash-4.17.21.tgz"
      assert read_back["lodash"].dependencies == %{}
      assert read_back["lodash"].has_install_script == false
    end

    @tag :tmp_dir
    test "preserves install script metadata", %{tmp_dir: dir} do
      path = Path.join(dir, "npm.lock")

      lockfile = %{
        "native-pkg" => %{
          version: "1.0.0",
          integrity: "sha512-abc==",
          tarball: "https://registry.npmjs.org/native-pkg/-/native-pkg-1.0.0.tgz",
          dependencies: %{},
          has_install_script: true
        }
      }

      assert :ok = NPM.Lockfile.write(lockfile, path)
      assert {:ok, read_back} = NPM.Lockfile.read(path)
      assert read_back["native-pkg"].has_install_script == true
    end

    @tag :tmp_dir
    test "preserves dependencies in lockfile entries", %{tmp_dir: dir} do
      path = Path.join(dir, "npm.lock")

      lockfile = %{
        "express" => %{
          version: "4.21.2",
          integrity: "sha512-abc==",
          tarball: "https://registry.npmjs.org/express/-/express-4.21.2.tgz",
          dependencies: %{"accepts" => "~1.3.8", "body-parser" => "1.20.3"}
        }
      }

      NPM.Lockfile.write(lockfile, path)
      {:ok, read_back} = NPM.Lockfile.read(path)

      assert read_back["express"].dependencies == %{
               "accepts" => "~1.3.8",
               "body-parser" => "1.20.3"
             }
    end

    @tag :tmp_dir
    test "lockfile is stable on re-write", %{tmp_dir: dir} do
      path = Path.join(dir, "npm.lock")

      lockfile = %{
        "b-pkg" => %{version: "2.0.0", integrity: "", tarball: "", dependencies: %{}},
        "a-pkg" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      NPM.Lockfile.write(lockfile, path)
      content1 = File.read!(path)

      {:ok, read_back} = NPM.Lockfile.read(path)
      NPM.Lockfile.write(read_back, path)
      content2 = File.read!(path)

      assert content1 == content2
    end

    @tag :tmp_dir
    test "lockfile keys are sorted alphabetically", %{tmp_dir: dir} do
      path = Path.join(dir, "npm.lock")

      lockfile = %{
        "zlib" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}},
        "accepts" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      NPM.Lockfile.write(lockfile, path)
      content = File.read!(path)

      accepts_pos = :binary.match(content, "accepts") |> elem(0)
      zlib_pos = :binary.match(content, "zlib") |> elem(0)
      assert accepts_pos < zlib_pos
    end
  end

  describe "Lockfile dependency chain" do
    @tag :tmp_dir
    test "lockfile entries with dependencies can trace dependents", %{tmp_dir: dir} do
      path = Path.join(dir, "npm.lock")

      lockfile = %{
        "express" => %{
          version: "4.21.2",
          integrity: "",
          tarball: "",
          dependencies: %{"accepts" => "~1.3.8", "body-parser" => "1.20.3"}
        },
        "accepts" => %{
          version: "1.3.8",
          integrity: "",
          tarball: "",
          dependencies: %{"mime-types" => "~2.1.34"}
        },
        "body-parser" => %{
          version: "1.20.3",
          integrity: "",
          tarball: "",
          dependencies: %{}
        },
        "mime-types" => %{
          version: "2.1.35",
          integrity: "",
          tarball: "",
          dependencies: %{}
        }
      }

      NPM.Lockfile.write(lockfile, path)
      {:ok, read_back} = NPM.Lockfile.read(path)

      dependents_of_accepts =
        read_back
        |> Enum.filter(fn {name, entry} ->
          name != "accepts" and Map.has_key?(entry.dependencies, "accepts")
        end)
        |> Enum.map(&elem(&1, 0))

      assert dependents_of_accepts == ["express"]
    end
  end

  describe "Lockfile format" do
    @tag :tmp_dir
    test "lockfile contains lockfileVersion", %{tmp_dir: dir} do
      path = Path.join(dir, "npm.lock")

      lockfile = %{
        "pkg" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      NPM.Lockfile.write(lockfile, path)
      content = File.read!(path) |> :json.decode()
      assert content["lockfileVersion"] == 1
    end

    @tag :tmp_dir
    test "lockfile packages section has all required fields", %{tmp_dir: dir} do
      path = Path.join(dir, "npm.lock")

      lockfile = %{
        "test" => %{
          version: "2.0.0",
          integrity: "sha512-abc==",
          tarball: "https://example.com/test.tgz",
          dependencies: %{"dep" => "^1.0"}
        }
      }

      NPM.Lockfile.write(lockfile, path)
      {:ok, read_back} = NPM.Lockfile.read(path)

      entry = read_back["test"]
      assert entry.version == "2.0.0"
      assert entry.integrity == "sha512-abc=="
      assert entry.tarball == "https://example.com/test.tgz"
      assert entry.dependencies == %{"dep" => "^1.0"}
    end
  end

  describe "Lockfile scalability" do
    @tag :tmp_dir
    test "handles 50 packages round-trip", %{tmp_dir: dir} do
      path = Path.join(dir, "npm.lock")

      lockfile =
        for i <- 1..50, into: %{} do
          {"pkg-#{i}",
           %{
             version: "#{i}.0.0",
             integrity: "sha512-hash#{i}==",
             tarball: "https://example.com/pkg-#{i}.tgz",
             dependencies: %{}
           }}
        end

      NPM.Lockfile.write(lockfile, path)
      {:ok, read_back} = NPM.Lockfile.read(path)

      assert map_size(read_back) == 50
      assert read_back["pkg-1"].version == "1.0.0"
      assert read_back["pkg-50"].version == "50.0.0"
    end
  end

  describe "Lockfile complex deps" do
    @tag :tmp_dir
    test "handles diamond dependency pattern", %{tmp_dir: dir} do
      path = Path.join(dir, "npm.lock")

      lockfile = %{
        "app" => %{
          version: "1.0.0",
          integrity: "",
          tarball: "",
          dependencies: %{"left" => "^1.0", "right" => "^1.0"}
        },
        "left" => %{
          version: "1.0.0",
          integrity: "",
          tarball: "",
          dependencies: %{"shared" => "^2.0"}
        },
        "right" => %{
          version: "1.0.0",
          integrity: "",
          tarball: "",
          dependencies: %{"shared" => "^2.0"}
        },
        "shared" => %{
          version: "2.1.0",
          integrity: "",
          tarball: "",
          dependencies: %{}
        }
      }

      NPM.Lockfile.write(lockfile, path)
      {:ok, read_back} = NPM.Lockfile.read(path)

      assert map_size(read_back) == 4
      assert read_back["shared"].version == "2.1.0"
      assert read_back["left"].dependencies["shared"] == "^2.0"
      assert read_back["right"].dependencies["shared"] == "^2.0"
    end
  end

  describe "Lockfile empty deps handling" do
    @tag :tmp_dir
    test "handles entry with empty dependencies map", %{tmp_dir: dir} do
      path = Path.join(dir, "npm.lock")

      lockfile = %{
        "simple" => %{
          version: "1.0.0",
          integrity: "sha512-abc==",
          tarball: "https://example.com/simple.tgz",
          dependencies: %{}
        }
      }

      NPM.Lockfile.write(lockfile, path)
      {:ok, read_back} = NPM.Lockfile.read(path)

      assert read_back["simple"].dependencies == %{}
    end
  end

  describe "Lockfile with special values" do
    @tag :tmp_dir
    test "handles special characters in tarball URLs", %{tmp_dir: dir} do
      path = Path.join(dir, "npm.lock")

      lockfile = %{
        "@scope/pkg" => %{
          version: "1.0.0",
          integrity: "sha512-abc+def/ghi==",
          tarball: "https://registry.npmjs.org/@scope%2fpkg/-/pkg-1.0.0.tgz",
          dependencies: %{}
        }
      }

      NPM.Lockfile.write(lockfile, path)
      {:ok, read_back} = NPM.Lockfile.read(path)

      assert read_back["@scope/pkg"].integrity == "sha512-abc+def/ghi=="
      assert read_back["@scope/pkg"].tarball =~ "%2f"
    end
  end

  describe "Lockfile listing" do
    @tag :tmp_dir
    test "packages can be listed and sorted", %{tmp_dir: dir} do
      path = Path.join(dir, "npm.lock")

      lockfile = %{
        "z-pkg" => %{version: "2.0.0", integrity: "", tarball: "", dependencies: %{}},
        "a-pkg" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      NPM.Lockfile.write(lockfile, path)
      {:ok, read_back} = NPM.Lockfile.read(path)

      packages =
        read_back
        |> Enum.map(fn {name, entry} -> {name, entry.version} end)
        |> Enum.sort_by(&elem(&1, 0))

      assert [{"a-pkg", "1.0.0"}, {"z-pkg", "2.0.0"}] = packages
    end
  end

  describe "Lockfile write idempotency" do
    @tag :tmp_dir
    test "writing same lockfile twice produces identical files", %{tmp_dir: dir} do
      path1 = Path.join(dir, "lock1")
      path2 = Path.join(dir, "lock2")

      lockfile = %{
        "express" => %{
          version: "4.21.2",
          integrity: "sha512-abc==",
          tarball: "https://example.com/express.tgz",
          dependencies: %{"accepts" => "~1.3.8"}
        },
        "accepts" => %{
          version: "1.3.8",
          integrity: "sha512-def==",
          tarball: "https://example.com/accepts.tgz",
          dependencies: %{}
        }
      }

      NPM.Lockfile.write(lockfile, path1)
      NPM.Lockfile.write(lockfile, path2)

      assert File.read!(path1) == File.read!(path2)
    end
  end

  describe "Lockfile.version" do
    @tag :tmp_dir
    test "reads lockfile version", %{tmp_dir: dir} do
      path = Path.join(dir, "npm.lock")

      File.write!(
        path,
        NPM.JSON.encode_pretty(%{"lockfileVersion" => 1, "packages" => %{}})
      )

      assert 1 = NPM.Lockfile.version(path)
    end

    @tag :tmp_dir
    test "returns nil for missing file", %{tmp_dir: dir} do
      assert nil == NPM.Lockfile.version(Path.join(dir, "nope.lock"))
    end
  end

  describe "Lockfile.package_names" do
    @tag :tmp_dir
    test "lists sorted names", %{tmp_dir: dir} do
      path = Path.join(dir, "npm.lock")

      lockfile = %{
        "zebra" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}},
        "alpha" => %{version: "2.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      NPM.Lockfile.write(lockfile, path)
      assert {:ok, ["alpha", "zebra"]} = NPM.Lockfile.package_names(path)
    end
  end

  describe "Lockfile.has_package?" do
    @tag :tmp_dir
    test "detects existing package", %{tmp_dir: dir} do
      path = Path.join(dir, "npm.lock")

      lockfile = %{
        "lodash" => %{version: "4.17.21", integrity: "", tarball: "", dependencies: %{}}
      }

      NPM.Lockfile.write(lockfile, path)
      assert NPM.Lockfile.has_package?("lodash", path)
      refute NPM.Lockfile.has_package?("missing", path)
    end
  end

  describe "Lockfile.get_package" do
    @tag :tmp_dir
    test "retrieves single entry", %{tmp_dir: dir} do
      path = Path.join(dir, "npm.lock")

      lockfile = %{
        "react" => %{
          version: "18.2.0",
          integrity: "sha512-abc",
          tarball: "url",
          dependencies: %{}
        }
      }

      NPM.Lockfile.write(lockfile, path)
      assert {:ok, entry} = NPM.Lockfile.get_package("react", path)
      assert entry.version == "18.2.0"
    end

    @tag :tmp_dir
    test "returns error for missing package", %{tmp_dir: dir} do
      path = Path.join(dir, "npm.lock")
      lockfile = %{"react" => %{version: "18.2.0", integrity: "", tarball: "", dependencies: %{}}}

      NPM.Lockfile.write(lockfile, path)
      assert :error = NPM.Lockfile.get_package("vue", path)
    end
  end

  describe "Lockfile: utility functions" do
    @tag :tmp_dir
    test "has_package? checks lockfile contents", %{tmp_dir: dir} do
      path = Path.join(dir, "npm.lock")

      lockfile = %{
        "lodash" => %{
          version: "4.17.21",
          integrity: "sha512-x",
          tarball: "url",
          dependencies: %{}
        }
      }

      NPM.Lockfile.write(lockfile, path)
      assert NPM.Lockfile.has_package?("lodash", path)
      refute NPM.Lockfile.has_package?("react", path)
    end

    @tag :tmp_dir
    test "package_names lists all locked packages", %{tmp_dir: dir} do
      path = Path.join(dir, "npm.lock")

      lockfile = %{
        "lodash" => %{version: "4.17.21", integrity: "", tarball: "", dependencies: %{}},
        "react" => %{version: "18.2.0", integrity: "", tarball: "", dependencies: %{}}
      }

      NPM.Lockfile.write(lockfile, path)
      {:ok, names} = NPM.Lockfile.package_names(path)
      assert "lodash" in names
      assert "react" in names
    end

    @tag :tmp_dir
    test "get_package retrieves specific entry", %{tmp_dir: dir} do
      path = Path.join(dir, "npm.lock")

      lockfile = %{
        "lodash" => %{
          version: "4.17.21",
          integrity: "sha512-x",
          tarball: "url",
          dependencies: %{}
        }
      }

      NPM.Lockfile.write(lockfile, path)
      {:ok, entry} = NPM.Lockfile.get_package("lodash", path)
      assert entry.version == "4.17.21"
    end

    @tag :tmp_dir
    test "lockfile version returns format version", %{tmp_dir: dir} do
      path = Path.join(dir, "npm.lock")
      NPM.Lockfile.write(%{}, path)
      assert NPM.Lockfile.version(path) == 1
    end
  end

  describe "Lockfile: package_names sorting" do
    @tag :tmp_dir
    test "package_names returns sorted list", %{tmp_dir: dir} do
      path = Path.join(dir, "npm.lock")

      lockfile = %{
        "z-pkg" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}},
        "a-pkg" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}},
        "m-pkg" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      NPM.Lockfile.write(lockfile, path)
      {:ok, names} = NPM.Lockfile.package_names(path)
      assert names == ["a-pkg", "m-pkg", "z-pkg"]
    end
  end

  describe "Lockfile: write produces valid JSON" do
    @tag :tmp_dir
    test "output is parseable JSON", %{tmp_dir: dir} do
      path = Path.join(dir, "npm.lock")

      NPM.Lockfile.write(
        %{
          "react" => %{
            version: "18.2.0",
            integrity: "sha512-x",
            tarball: "url",
            dependencies: %{"loose-envify" => "^1.1.0"}
          }
        },
        path
      )

      content = File.read!(path)
      data = :json.decode(content)
      assert is_map(data["packages"])
      assert data["packages"]["react"]["version"] == "18.2.0"
    end
  end

  describe "Lockfile: read empty lockfile" do
    @tag :tmp_dir
    test "read returns empty map for empty packages", %{tmp_dir: dir} do
      path = Path.join(dir, "npm.lock")
      NPM.Lockfile.write(%{}, path)
      {:ok, result} = NPM.Lockfile.read(path)
      assert result == %{}
    end
  end

  describe "Lockfile: write to existing directory" do
    @tag :tmp_dir
    test "write creates file in existing dir", %{tmp_dir: dir} do
      path = Path.join(dir, "npm.lock")
      NPM.Lockfile.write(%{}, path)
      assert File.exists?(path)
      content = File.read!(path)
      assert content =~ "lockfileVersion"
    end
  end

  describe "Lockfile: get_package edge cases" do
    test "get_package returns :error for missing file" do
      assert :error = NPM.Lockfile.get_package("anything", "/tmp/no_such_file.lock")
    end

    @tag :tmp_dir
    test "get_package returns :error for missing package", %{tmp_dir: dir} do
      path = Path.join(dir, "npm.lock")

      NPM.Lockfile.write(
        %{"a" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}},
        path
      )

      assert :error = NPM.Lockfile.get_package("nonexistent", path)
    end
  end

  describe "Lockfile: has_package? with missing file" do
    test "returns false when lockfile doesn't exist" do
      refute NPM.Lockfile.has_package?("anything", "/tmp/nonexistent_dir/npm.lock")
    end
  end

  describe "Lockfile: version with missing file" do
    test "returns nil when lockfile doesn't exist" do
      assert nil == NPM.Lockfile.version("/tmp/nonexistent_dir/npm.lock")
    end
  end

  describe "Lockfile: read/write round-trip with complex deps" do
    @tag :tmp_dir
    test "preserves nested dependency ranges through round-trip", %{tmp_dir: dir} do
      path = Path.join(dir, "npm.lock")

      original = %{
        "express" => %{
          version: "4.21.2",
          integrity: "sha512-abc",
          tarball: "https://registry/express-4.21.2.tgz",
          dependencies: %{
            "accepts" => "~1.3.8",
            "body-parser" => "1.20.3",
            "cookie" => "0.7.1",
            "debug" => "2.6.9"
          }
        },
        "debug" => %{
          version: "2.6.9",
          integrity: "sha512-def",
          tarball: "https://registry/debug-2.6.9.tgz",
          dependencies: %{"ms" => "2.0.0"}
        }
      }

      NPM.Lockfile.write(original, path)
      {:ok, restored} = NPM.Lockfile.read(path)

      assert restored["express"].version == "4.21.2"
      assert restored["express"].dependencies["accepts"] == "~1.3.8"
      assert restored["express"].dependencies["debug"] == "2.6.9"
      assert restored["debug"].dependencies["ms"] == "2.0.0"
    end
  end

  describe "Lockfile: round-trip preserves all fields" do
    @tag :tmp_dir
    test "write then read preserves version, integrity, tarball, deps", %{tmp_dir: dir} do
      path = Path.join(dir, "npm.lock")

      original = %{
        "lodash" => %{
          version: "4.17.21",
          integrity: "sha512-WjKPNJF79mLQN/qZ+2A==",
          tarball: "https://registry.npmjs.org/lodash/-/lodash-4.17.21.tgz",
          dependencies: %{}
        },
        "accepts" => %{
          version: "1.3.8",
          integrity: "sha512-PYAth==",
          tarball: "https://registry.npmjs.org/accepts/-/accepts-1.3.8.tgz",
          dependencies: %{"mime-types" => "~2.1.34", "negotiator" => "0.6.3"}
        }
      }

      NPM.Lockfile.write(original, path)
      {:ok, restored} = NPM.Lockfile.read(path)

      for {name, entry} <- original do
        assert restored[name].version == entry.version
        assert restored[name].integrity == entry.integrity
        assert restored[name].tarball == entry.tarball
        assert restored[name].dependencies == entry.dependencies
      end
    end

    @tag :tmp_dir
    test "lockfile is sorted alphabetically", %{tmp_dir: dir} do
      path = Path.join(dir, "npm.lock")

      lockfile = %{
        "zebra" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}},
        "alpha" => %{version: "1.0.0", integrity: "", tarball: "", dependencies: %{}}
      }

      NPM.Lockfile.write(lockfile, path)
      content = File.read!(path)

      alpha_pos = :binary.match(content, "alpha") |> elem(0)
      zebra_pos = :binary.match(content, "zebra") |> elem(0)
      assert alpha_pos < zebra_pos
    end
  end

  describe "Lockfile: npm-compatible write format" do
    @tag :tmp_dir
    test "lockfile JSON is pretty-printed with sorted keys", %{tmp_dir: dir} do
      path = Path.join(dir, "npm.lock")

      lockfile = %{
        "b-pkg" => %{version: "2.0.0", integrity: "sha512-b", tarball: "url-b", dependencies: %{}},
        "a-pkg" => %{version: "1.0.0", integrity: "sha512-a", tarball: "url-a", dependencies: %{}}
      }

      NPM.Lockfile.write(lockfile, path)
      content = File.read!(path)

      # Should have lockfileVersion
      assert content =~ "lockfileVersion"
      # packages should be sorted
      a_pos = :binary.match(content, "a-pkg") |> elem(0)
      b_pos = :binary.match(content, "b-pkg") |> elem(0)
      assert a_pos < b_pos

      # Should be valid JSON
      data = :json.decode(content)
      assert data["lockfileVersion"] == 1
    end

    @tag :tmp_dir
    test "empty lockfile round-trips", %{tmp_dir: dir} do
      path = Path.join(dir, "npm.lock")

      NPM.Lockfile.write(%{}, path)
      {:ok, restored} = NPM.Lockfile.read(path)
      assert restored == %{}
    end

    @tag :tmp_dir
    test "lockfile preserves dependency ranges", %{tmp_dir: dir} do
      path = Path.join(dir, "npm.lock")

      lockfile = %{
        "express" => %{
          version: "4.21.2",
          integrity: "sha512-xyz",
          tarball: "https://reg/express-4.21.2.tgz",
          dependencies: %{
            "accepts" => "~1.3.8",
            "debug" => "2.6.9",
            "cookie" => "0.7.1"
          }
        }
      }

      NPM.Lockfile.write(lockfile, path)
      {:ok, restored} = NPM.Lockfile.read(path)

      assert restored["express"].dependencies["accepts"] == "~1.3.8"
      assert restored["express"].dependencies["debug"] == "2.6.9"
    end
  end

  describe "Lockfile: version returns lockfile version" do
    @tag :tmp_dir
    test "returns version from written lockfile", %{tmp_dir: dir} do
      path = Path.join(dir, "npm.lock")
      NPM.Lockfile.write(%{}, path)
      version = NPM.Lockfile.version(path)
      assert is_integer(version)
    end
  end

  describe "Lockfile: has_package? checks existence" do
    @tag :tmp_dir
    test "returns true for existing package", %{tmp_dir: dir} do
      path = Path.join(dir, "npm.lock")

      NPM.Lockfile.write(
        %{
          "react" => %{
            version: "18.2.0",
            integrity: "sha512-x",
            tarball: "url",
            dependencies: %{}
          }
        },
        path
      )

      assert NPM.Lockfile.has_package?("react", path)
      refute NPM.Lockfile.has_package?("vue", path)
    end
  end

  describe "Lockfile: get_package returns entry" do
    @tag :tmp_dir
    test "returns package data when present", %{tmp_dir: dir} do
      path = Path.join(dir, "npm.lock")

      NPM.Lockfile.write(
        %{
          "lodash" => %{
            version: "4.17.21",
            integrity: "sha512-x",
            tarball: "url",
            dependencies: %{}
          }
        },
        path
      )

      {:ok, pkg} = NPM.Lockfile.get_package("lodash", path)
      assert pkg.version == "4.17.21"
    end

    @tag :tmp_dir
    test "returns error for missing package", %{tmp_dir: dir} do
      path = Path.join(dir, "npm.lock")
      NPM.Lockfile.write(%{}, path)
      result = NPM.Lockfile.get_package("missing", path)
      assert result == :error
    end
  end

  describe "Lockfile: roundtrip with multiple packages" do
    @tag :tmp_dir
    test "write and read preserves all packages", %{tmp_dir: dir} do
      path = Path.join(dir, "npm.lock")

      lockfile = %{
        "react" => %{version: "18.2.0", integrity: "sha512-a", tarball: "u1", dependencies: %{}},
        "lodash" => %{version: "4.17.21", integrity: "sha512-b", tarball: "u2", dependencies: %{}},
        "express" => %{
          version: "4.21.2",
          integrity: "sha512-c",
          tarball: "u3",
          dependencies: %{"ms" => "^2.1"}
        }
      }

      NPM.Lockfile.write(lockfile, path)
      {:ok, loaded} = NPM.Lockfile.read(path)
      assert map_size(loaded) == 3
      assert loaded["react"].version == "18.2.0"
      assert loaded["lodash"].version == "4.17.21"
      assert loaded["express"].version == "4.21.2"
    end
  end

  describe "parse_packages" do
    test "parses raw packages map into lockfile entries" do
      packages = %{
        "lodash" => %{
          "version" => "4.17.21",
          "integrity" => "sha512-abc",
          "tarball" => "https://example.com/lodash.tgz",
          "dependencies" => %{"dep" => "^1.0"}
        }
      }

      result = NPM.Lockfile.parse_packages(packages)
      assert result["lodash"].version == "4.17.21"
      assert result["lodash"].integrity == "sha512-abc"
      assert result["lodash"].tarball == "https://example.com/lodash.tgz"
      assert result["lodash"].dependencies == %{"dep" => "^1.0"}
    end

    test "handles missing fields with defaults" do
      packages = %{"minimal" => %{}}
      result = NPM.Lockfile.parse_packages(packages)
      assert result["minimal"].version == ""
      assert result["minimal"].integrity == ""
      assert result["minimal"].dependencies == %{}
    end

    test "empty packages map" do
      assert %{} = NPM.Lockfile.parse_packages(%{})
    end

    test "multiple packages" do
      packages = %{
        "a" => %{"version" => "1.0.0"},
        "b" => %{"version" => "2.0.0"},
        "c" => %{"version" => "3.0.0"}
      }

      result = NPM.Lockfile.parse_packages(packages)
      assert map_size(result) == 3
      assert result["a"].version == "1.0.0"
      assert result["b"].version == "2.0.0"
      assert result["c"].version == "3.0.0"
    end
  end
end
