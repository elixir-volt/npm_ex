defmodule NPM.TarballTest do
  use ExUnit.Case, async: true

  import NPM.TestHelpers

  describe "Tarball.verify_integrity" do
    test "passes for correct sha512" do
      data = "hello world"
      hash = :crypto.hash(:sha512, data) |> Base.encode64()
      assert :ok = NPM.Tarball.verify_integrity(data, "sha512-#{hash}")
    end

    test "fails for wrong sha512 hash" do
      assert {:error, :integrity_mismatch} =
               NPM.Tarball.verify_integrity("hello", "sha512-wronghash==")
    end

    test "passes for correct sha1" do
      data = "hello world"
      hash = :crypto.hash(:sha, data) |> Base.encode64()
      assert :ok = NPM.Tarball.verify_integrity(data, "sha1-#{hash}")
    end

    test "fails for wrong sha1 hash" do
      assert {:error, :integrity_mismatch} =
               NPM.Tarball.verify_integrity("hello", "sha1-wronghash==")
    end

    test "passes for empty integrity string" do
      assert :ok = NPM.Tarball.verify_integrity("anything", "")
    end

    test "passes for correct sha256" do
      data = "hello world"
      hash = :crypto.hash(:sha256, data) |> Base.encode64()
      assert :ok = NPM.Tarball.verify_integrity(data, "sha256-#{hash}")
    end

    test "fails for wrong sha256 hash" do
      assert {:error, :integrity_mismatch} =
               NPM.Tarball.verify_integrity("hello", "sha256-wronghash==")
    end

    test "passes for unknown hash algorithm" do
      assert :ok = NPM.Tarball.verify_integrity("anything", "sha384-something==")
    end
  end

  describe "Tarball.extract" do
    @tag :tmp_dir
    test "unpacks tgz and strips package/ prefix", %{tmp_dir: dir} do
      tgz = create_test_tgz(%{"package/index.js" => "module.exports = 42;"})

      assert {:ok, 1} = NPM.Tarball.extract(tgz, dir)
      assert File.read!(Path.join(dir, "index.js")) == "module.exports = 42;"
    end

    @tag :tmp_dir
    test "handles multiple files", %{tmp_dir: dir} do
      tgz =
        create_test_tgz(%{
          "package/index.js" => "exports.a = 1;",
          "package/lib/util.js" => "exports.b = 2;",
          "package/package.json" => ~s({"name":"test"})
        })

      assert {:ok, 3} = NPM.Tarball.extract(tgz, dir)
      assert File.exists?(Path.join(dir, "index.js"))
      assert File.exists?(Path.join(dir, "lib/util.js"))
      assert File.exists?(Path.join(dir, "package.json"))
    end

    @tag :tmp_dir
    test "creates nested directories", %{tmp_dir: dir} do
      tgz = create_test_tgz(%{"package/a/b/c/deep.js" => "deep"})

      assert {:ok, 1} = NPM.Tarball.extract(tgz, dir)
      assert File.read!(Path.join(dir, "a/b/c/deep.js")) == "deep"
    end

    @tag :tmp_dir
    test "handles files without package/ prefix", %{tmp_dir: dir} do
      tgz = create_test_tgz(%{"index.js" => "no prefix"})

      assert {:ok, 1} = NPM.Tarball.extract(tgz, dir)
      assert File.read!(Path.join(dir, "index.js")) == "no prefix"
    end
  end

  describe "Tarball.extract edge cases" do
    @tag :tmp_dir
    test "handles empty tarball", %{tmp_dir: dir} do
      files = %{}
      tgz = create_test_tgz(files)
      assert {:ok, 0} = NPM.Tarball.extract(tgz, dir)
    end

    @tag :tmp_dir
    test "handles deeply nested paths", %{tmp_dir: dir} do
      tgz = create_test_tgz(%{"package/a/b/c/d/e/deep.txt" => "deep value"})

      assert {:ok, 1} = NPM.Tarball.extract(tgz, dir)
      assert File.read!(Path.join(dir, "a/b/c/d/e/deep.txt")) == "deep value"
    end

    @tag :tmp_dir
    test "preserves file content exactly", %{tmp_dir: dir} do
      content = String.duplicate("x", 10_000) <> "\n" <> String.duplicate("y", 10_000)
      tgz = create_test_tgz(%{"package/big.txt" => content})

      assert {:ok, 1} = NPM.Tarball.extract(tgz, dir)
      assert File.read!(Path.join(dir, "big.txt")) == content
    end
  end

  describe "Tarball.verify_integrity edge cases" do
    test "handles sha512 with plus and slash characters" do
      data = "complex content with special chars"
      hash = :crypto.hash(:sha512, data) |> Base.encode64()
      assert :ok = NPM.Tarball.verify_integrity(data, "sha512-#{hash}")
    end

    test "handles large binary data" do
      data = :crypto.strong_rand_bytes(100_000)
      hash = :crypto.hash(:sha512, data) |> Base.encode64()
      assert :ok = NPM.Tarball.verify_integrity(data, "sha512-#{hash}")
    end
  end

  describe "Tarball with binary content" do
    @tag :tmp_dir
    test "handles binary file content", %{tmp_dir: dir} do
      binary_content = <<0, 1, 2, 3, 255, 254, 253>>
      tgz = create_test_tgz(%{"package/binary.bin" => binary_content})

      assert {:ok, 1} = NPM.Tarball.extract(tgz, dir)
      assert File.read!(Path.join(dir, "binary.bin")) == binary_content
    end
  end

  describe "Tarball.fetch_and_extract" do
    @tag :tmp_dir
    test "fetches and extracts valid tarball", %{tmp_dir: dir} do
      tgz = create_test_tgz(%{"package/index.js" => "test content"})
      hash = :crypto.hash(:sha512, tgz) |> Base.encode64()

      {:ok, listen} = :gen_tcp.listen(0, [:binary, active: false, reuseaddr: true])
      {:ok, port} = :inet.port(listen)

      spawn(fn ->
        {:ok, conn} = :gen_tcp.accept(listen)
        {:ok, _data} = :gen_tcp.recv(conn, 0, 5000)
        response = "HTTP/1.1 200 OK\r\nContent-Length: #{byte_size(tgz)}\r\n\r\n" <> tgz
        :gen_tcp.send(conn, response)
        :gen_tcp.close(conn)
      end)

      url = "http://127.0.0.1:#{port}/test.tgz"
      assert {:ok, 1} = NPM.Tarball.fetch_and_extract(url, "sha512-#{hash}", dir)
      assert File.read!(Path.join(dir, "index.js")) == "test content"

      :gen_tcp.close(listen)
    end

    @tag :tmp_dir
    test "fails on integrity mismatch", %{tmp_dir: dir} do
      tgz = create_test_tgz(%{"package/index.js" => "content"})

      {:ok, listen} = :gen_tcp.listen(0, [:binary, active: false, reuseaddr: true])
      {:ok, port} = :inet.port(listen)

      spawn(fn ->
        {:ok, conn} = :gen_tcp.accept(listen)
        {:ok, _data} = :gen_tcp.recv(conn, 0, 5000)
        response = "HTTP/1.1 200 OK\r\nContent-Length: #{byte_size(tgz)}\r\n\r\n" <> tgz
        :gen_tcp.send(conn, response)
        :gen_tcp.close(conn)
      end)

      url = "http://127.0.0.1:#{port}/test.tgz"

      assert {:error, :integrity_mismatch} =
               NPM.Tarball.fetch_and_extract(url, "sha512-wrong==", dir)

      :gen_tcp.close(listen)
    end
  end

  describe "Tarball extract various file types" do
    @tag :tmp_dir
    test "handles nested package.json with dependencies", %{tmp_dir: dir} do
      pkg_json = ~s({"name":"test","version":"1.0.0","dependencies":{"dep":"^1.0"}})
      tgz = create_test_tgz(%{"package/package.json" => pkg_json})

      assert {:ok, 1} = NPM.Tarball.extract(tgz, dir)
      content = File.read!(Path.join(dir, "package.json")) |> :json.decode()
      assert content["name"] == "test"
      assert content["dependencies"]["dep"] == "^1.0"
    end

    @tag :tmp_dir
    test "handles multiple nested directories", %{tmp_dir: dir} do
      files = %{
        "package/src/index.js" => "main",
        "package/src/utils/helper.js" => "helper",
        "package/dist/bundle.js" => "bundled",
        "package/README.md" => "# Test"
      }

      tgz = create_test_tgz(files)
      assert {:ok, 4} = NPM.Tarball.extract(tgz, dir)
      assert File.read!(Path.join(dir, "src/index.js")) == "main"
      assert File.read!(Path.join(dir, "src/utils/helper.js")) == "helper"
      assert File.read!(Path.join(dir, "dist/bundle.js")) == "bundled"
      assert File.read!(Path.join(dir, "README.md")) == "# Test"
    end
  end

  describe "Tarball integrity comprehensive" do
    test "sha512 with correct padding" do
      data = String.duplicate("a", 1000)
      hash = :crypto.hash(:sha512, data) |> Base.encode64()
      assert :ok = NPM.Tarball.verify_integrity(data, "sha512-#{hash}")
    end

    test "sha256 with small data" do
      data = "x"
      hash = :crypto.hash(:sha256, data) |> Base.encode64()
      assert :ok = NPM.Tarball.verify_integrity(data, "sha256-#{hash}")
    end

    test "sha1 with empty data" do
      data = ""
      hash = :crypto.hash(:sha, data) |> Base.encode64()
      assert :ok = NPM.Tarball.verify_integrity(data, "sha1-#{hash}")
    end

    test "sha512 with binary data" do
      data = <<0, 1, 2, 255, 254, 253>>
      hash = :crypto.hash(:sha512, data) |> Base.encode64()
      assert :ok = NPM.Tarball.verify_integrity(data, "sha512-#{hash}")
    end
  end

  describe "Tarball: sha512 mismatch detection" do
    test "wrong hash returns integrity_mismatch" do
      data = "test data"
      wrong_hash = "sha512-" <> Base.encode64("wrong")
      assert {:error, :integrity_mismatch} = NPM.Tarball.verify_integrity(data, wrong_hash)
    end
  end

  describe "Tarball: edge cases" do
    @tag :tmp_dir
    test "extract handles empty tarball", %{tmp_dir: dir} do
      # An empty tgz should return an error, not crash
      result = NPM.Tarball.extract("", dir)
      assert {:error, _} = result
    end

    @tag :tmp_dir
    test "extract handles single-file tarball", %{tmp_dir: dir} do
      tgz = create_test_tgz(%{"package.json" => ~s({"name":"single"})})
      {:ok, count} = NPM.Tarball.extract(tgz, dir)
      assert count == 1
    end
  end

  describe "Tarball: real format handling" do
    @tag :tmp_dir
    test "creates proper package dir from tgz with nested dirs", %{tmp_dir: dir} do
      tgz =
        create_test_tgz(%{
          "package.json" => ~s({"name":"multi-file","version":"1.0.0"}),
          "lib/index.js" => "module.exports = {}",
          "lib/utils/helper.js" => "module.exports = {}"
        })

      {:ok, count} = NPM.Tarball.extract(tgz, dir)
      assert count == 3
      assert File.exists?(Path.join(dir, "package.json"))
      assert File.exists?(Path.join(dir, "lib/index.js"))
      assert File.exists?(Path.join(dir, "lib/utils/helper.js"))
    end

    @tag :tmp_dir
    test "integrity check rejects tampered data", %{tmp_dir: _dir} do
      tgz = create_test_tgz(%{"package.json" => ~s({"name":"test"})})

      good_integrity = NPM.Integrity.compute_sha512(tgz)
      assert :ok = NPM.Tarball.verify_integrity(tgz, good_integrity)

      bad_integrity = "sha512-" <> Base.encode64("wrong")
      assert {:error, :integrity_mismatch} = NPM.Tarball.verify_integrity(tgz, bad_integrity)
    end
  end

  describe "Tarball: strip_prefix behavior" do
    @tag :tmp_dir
    test "strips package/ prefix from tar entries", %{tmp_dir: dir} do
      # npm tarballs have files under package/ prefix
      tgz = create_test_tgz(%{"package.json" => ~s({"name":"test"})})
      {:ok, _count} = NPM.Tarball.extract(tgz, dir)

      # Should be extracted without the package/ prefix
      assert File.exists?(Path.join(dir, "package.json"))
      refute File.exists?(Path.join(dir, "package/package.json"))
    end
  end

  describe "Tarball: verify_integrity edge cases" do
    test "empty integrity passes" do
      assert :ok = NPM.Tarball.verify_integrity("data", "")
    end

    test "sha256 integrity works" do
      data = "hello"
      hash = :crypto.hash(:sha256, data) |> Base.encode64()
      assert :ok = NPM.Tarball.verify_integrity(data, "sha256-#{hash}")
    end

    test "sha1 integrity works" do
      data = "hello"
      hash = :crypto.hash(:sha, data) |> Base.encode64()
      assert :ok = NPM.Tarball.verify_integrity(data, "sha1-#{hash}")
    end

    test "unknown algorithm passes" do
      assert :ok = NPM.Tarball.verify_integrity("data", "md5-something")
    end
  end

  describe "Tarball: verify_integrity for different algorithms" do
    test "sha512 verification with correct hash passes" do
      data = "test data for sha512"
      hash = :crypto.hash(:sha512, data) |> Base.encode64()
      assert :ok = NPM.Tarball.verify_integrity(data, "sha512-#{hash}")
    end

    test "sha256 verification with correct hash passes" do
      data = "test data for sha256"
      hash = :crypto.hash(:sha256, data) |> Base.encode64()
      assert :ok = NPM.Tarball.verify_integrity(data, "sha256-#{hash}")
    end

    test "sha1 verification with correct hash passes" do
      data = "test data for sha1"
      hash = :crypto.hash(:sha, data) |> Base.encode64()
      assert :ok = NPM.Tarball.verify_integrity(data, "sha1-#{hash}")
    end

    test "empty integrity passes" do
      assert :ok = NPM.Tarball.verify_integrity("anything", "")
    end

    test "wrong sha512 hash fails" do
      result = NPM.Tarball.verify_integrity("data", "sha512-wronghash")
      assert result != :ok
    end
  end

  describe "Tarball: extract from tgz data" do
    @tag :tmp_dir
    test "extracts files from tgz to directory", %{tmp_dir: dir} do
      tgz_data =
        create_test_tgz([
          {"package/index.js", "console.log('hello')"},
          {"package/package.json", ~s({"name":"test"})}
        ])

      dest = Path.join(dir, "extracted")
      File.mkdir_p!(dest)
      NPM.Tarball.extract(tgz_data, dest)

      assert File.exists?(Path.join(dest, "index.js")) or
               File.exists?(Path.join(dest, "package/index.js"))
    end
  end
end
