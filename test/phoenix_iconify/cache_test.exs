defmodule PhoenixIconify.CacheTest do
  use ExUnit.Case, async: false

  alias PhoenixIconify.Cache

  describe "paths" do
    test "set_path/1 returns set cache path" do
      path = Cache.set_path("heroicons")
      assert String.ends_with?(path, "heroicons.json")
    end
  end

  describe "cache checks" do
    test "has_set?/1 returns false for non-existent set" do
      refute Cache.has_set?("nonexistent-set-12345")
    end

    test "list_cached_sets/0 returns list" do
      assert is_list(Cache.list_cached_sets())
    end
  end

  describe "stats/0" do
    test "returns cache statistics" do
      stats = Cache.stats()
      assert Map.has_key?(stats, :sets)
      assert Map.has_key?(stats, :total_size)
      assert Map.has_key?(stats, :total_size_human)
    end
  end

  describe "get_icons/3" do
    @describetag :tmp_dir

    setup %{tmp_dir: tmp_dir} do
      previous = Application.get_env(:phoenix_iconify, :cache_dir)
      Application.put_env(:phoenix_iconify, :cache_dir, tmp_dir)

      on_exit(fn ->
        if previous,
          do: Application.put_env(:phoenix_iconify, :cache_dir, previous),
          else: Application.delete_env(:phoenix_iconify, :cache_dir)
      end)

      # A set cached before "layer-arrow-up" was added to Lucide.
      Cache.save_set(
        "lucide",
        ~s({"prefix":"lucide","icons":{"mail":{"body":"<path d=\\"M0 0\\"/>"}},"width":24,"height":24})
      )
    end

    test "fetches icons a stale cached set lacks, and skips icons that exist nowhere" do
      parent = self()

      fetch_icon = fn
        "lucide", "layer-arrow-up" = name ->
          send(parent, {:fetched, name})
          {:ok, %Iconify.Icon{name: name, body: "<path/>", width: 24, height: 24}}

        "lucide", name ->
          send(parent, {:fetched, name})
          {:error, :not_found}
      end

      icons = Cache.get_icons("lucide", ["mail", "layer-arrow-up", "no-such-icon"], fetch_icon)

      assert Enum.map(icons, &elem(&1, 0)) == ["lucide:mail", "lucide:layer-arrow-up"]
      assert Enum.all?(icons, fn {full_name, icon} -> icon.name == full_name end)

      refute_received {:fetched, "mail"}
      assert_received {:fetched, "layer-arrow-up"}
      assert_received {:fetched, "no-such-icon"}
    end
  end
end
