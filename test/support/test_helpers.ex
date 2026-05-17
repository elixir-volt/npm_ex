defmodule NPM.TestHelpers do
  @moduledoc """
  Shared helpers for npm_ex tests.
  """

  def mask_token(token) when byte_size(token) <= 8, do: "****"

  def mask_token(token) do
    String.slice(token, 0, 4) <> "****" <> String.slice(token, -4, 4)
  end

  def create_test_tgz(files) do
    tmp = System.tmp_dir!()
    tgz_path = Path.join(tmp, "npm_test_#{System.unique_integer([:positive])}.tgz")

    file_entries =
      Enum.map(files, fn
        {name, content, mode} ->
          path = Path.join(tmp, name)
          File.mkdir_p!(Path.dirname(path))
          File.write!(path, content)
          File.chmod!(path, mode)
          {~c"#{name}", ~c"#{path}"}

        {name, content} ->
          path = Path.join(tmp, name)
          File.mkdir_p!(Path.dirname(path))
          File.write!(path, content)
          {~c"#{name}", ~c"#{path}"}
      end)

    :ok = :erl_tar.create(~c"#{tgz_path}", file_entries, [:compressed])
    data = File.read!(tgz_path)

    File.rm!(tgz_path)

    Enum.each(files, fn
      {name, _, _} -> File.rm(Path.join(tmp, name))
      {name, _} -> File.rm(Path.join(tmp, name))
    end)

    data
  end

  def setup_cached_package(cache_dir, name, version, files) do
    pkg_dir = Path.join([cache_dir, "cache", name, version])
    File.mkdir_p!(pkg_dir)

    Enum.each(files, fn {filename, content} ->
      path = Path.join(pkg_dir, filename)
      File.mkdir_p!(Path.dirname(path))
      File.write!(path, content)
    end)
  end
end
