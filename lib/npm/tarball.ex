defmodule NPM.Tarball do
  @moduledoc """
  Download and extract npm package tarballs.

  Verifies SHA-512 integrity and extracts contents to disk.
  """

  @doc """
  Download a tarball, verify its integrity, and extract to a directory.

  Returns `{:ok, file_count}` or `{:error, reason}`.
  """
  @spec fetch_and_extract(String.t(), String.t(), String.t()) ::
          {:ok, non_neg_integer()} | {:error, term()}
  def fetch_and_extract(tarball_url, integrity, dest_dir) do
    case Req.get(tarball_url, decode_body: false) do
      {:ok, %{status: 200, body: body}} ->
        with :ok <- verify_integrity(body, integrity) do
          extract(body, dest_dir)
        end

      {:ok, %{status: status}} ->
        {:error, {:http, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc "Verify SHA-512 integrity of a binary against an SRI hash."
  @spec verify_integrity(binary(), String.t()) :: :ok | {:error, :integrity_mismatch}
  def verify_integrity(_body, ""), do: :ok

  def verify_integrity(body, "sha512-" <> expected_b64) do
    actual = :crypto.hash(:sha512, body) |> Base.encode64()
    if actual == expected_b64, do: :ok, else: {:error, :integrity_mismatch}
  end

  def verify_integrity(body, "sha256-" <> expected_b64) do
    actual = :crypto.hash(:sha256, body) |> Base.encode64()
    if actual == expected_b64, do: :ok, else: {:error, :integrity_mismatch}
  end

  def verify_integrity(body, "sha1-" <> expected_b64) do
    actual = :crypto.hash(:sha, body) |> Base.encode64()
    if actual == expected_b64, do: :ok, else: {:error, :integrity_mismatch}
  end

  def verify_integrity(_body, _unknown), do: :ok

  @doc """
  Extract a `.tgz` tarball into a destination directory.

  Strips the `package/` prefix that npm tarballs use.
  Returns `{:ok, file_count}`.
  """
  @spec extract(binary(), String.t()) :: {:ok, non_neg_integer()} | {:error, term()}
  def extract(tgz_data, dest_dir) do
    File.mkdir_p!(dest_dir)

    case :erl_tar.extract({:binary, tgz_data}, [:compressed, :memory]) do
      {:ok, entries} ->
        with {:ok, files} <- safe_entries(entries, dest_dir) do
          Enum.each(files, &write_entry/1)
          {:ok, length(files)}
        end

      {:error, reason} ->
        {:error, {:extract, reason}}
    end
  end

  defp safe_entries(entries, dest_dir) do
    Enum.reduce_while(entries, {:ok, []}, fn {path, content}, {:ok, acc} ->
      original_path = to_string(path)
      rel_path = strip_prefix(original_path)

      case safe_path(dest_dir, rel_path) do
        {:ok, full_path} -> {:cont, {:ok, [{full_path, content} | acc]}}
        {:error, reason} -> {:halt, {:error, {reason, original_path}}}
      end
    end)
    |> case do
      {:ok, files} -> {:ok, Enum.reverse(files)}
      error -> error
    end
  end

  defp safe_path(dest_dir, rel_path) do
    dest = Path.expand(dest_dir)
    full_path = Path.expand(rel_path, dest)

    cond do
      rel_path in ["", "."] ->
        {:error, :unsafe_path}

      unsafe_segments?(Path.split(rel_path)) ->
        {:error, :unsafe_path}

      not inside_dir?(full_path, dest) ->
        {:error, :unsafe_path}

      true ->
        {:ok, full_path}
    end
  end

  defp unsafe_segments?(segments), do: Enum.any?(segments, &(&1 in ["..", ""]))

  defp inside_dir?(path, dir), do: path == dir or String.starts_with?(path, dir <> "/")

  defp write_entry({full_path, content}) do
    full_path |> Path.dirname() |> File.mkdir_p!()
    File.write!(full_path, content)
  end

  defp strip_prefix("package/" <> rest), do: rest
  defp strip_prefix(path), do: path
end
