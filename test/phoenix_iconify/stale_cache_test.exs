defmodule PhoenixIconify.StaleCacheTest do
  use ExUnit.Case, async: false

  alias PhoenixIconify.Cache

  @moduletag :tmp_dir

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
