defmodule NPM.PackumentCacheTest do
  use ExUnit.Case, async: false

  setup do
    old_cache = System.get_env("NPM_EX_CACHE_DIR")
    old_ttl = Application.get_env(:npm, :packument_cache_ttl)

    on_exit(fn ->
      if old_cache,
        do: System.put_env("NPM_EX_CACHE_DIR", old_cache),
        else: System.delete_env("NPM_EX_CACHE_DIR")

      if old_ttl,
        do: Application.put_env(:npm, :packument_cache_ttl, old_ttl),
        else: Application.delete_env(:npm, :packument_cache_ttl)
    end)

    :ok
  end

  @tag :tmp_dir
  test "stores and reads packuments", %{tmp_dir: dir} do
    System.put_env("NPM_EX_CACHE_DIR", dir)
    packument = %{versions: %{"1.0.0" => %{}}}

    assert :miss = NPM.PackumentCache.get("@scope/pkg")
    assert :ok = NPM.PackumentCache.put("@scope/pkg", packument)
    assert {:ok, ^packument} = NPM.PackumentCache.get("@scope/pkg")
  end

  @tag :tmp_dir
  test "misses expired entries", %{tmp_dir: dir} do
    System.put_env("NPM_EX_CACHE_DIR", dir)
    Application.put_env(:npm, :packument_cache_ttl, -1)

    assert :ok = NPM.PackumentCache.put("pkg", %{name: "pkg"})
    assert :miss = NPM.PackumentCache.get("pkg")
  end
end
