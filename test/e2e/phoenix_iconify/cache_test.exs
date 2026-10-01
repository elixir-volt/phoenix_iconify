defmodule PhoenixIconify.E2E.CacheTest do
  # Talks to the Iconify API. Run with `mix test.e2e`.
  use ExUnit.Case, async: false

  alias PhoenixIconify.Cache

  @moduletag :e2e
  @moduletag :tmp_dir

  setup %{tmp_dir: tmp_dir} do
    {:ok, _} = Application.ensure_all_started(:req)
    previous = Application.get_env(:phoenix_iconify, :cache_dir)
    Application.put_env(:phoenix_iconify, :cache_dir, tmp_dir)

    on_exit(fn ->
      if previous,
        do: Application.put_env(:phoenix_iconify, :cache_dir, previous),
        else: Application.delete_env(:phoenix_iconify, :cache_dir)
    end)
  end

  test "fetches an icon added to Lucide after its set was cached (#2)" do
    Cache.save_set(
      "lucide",
      ~s({"prefix":"lucide","icons":{"mail":{"body":"<path/>"}},"width":24,"height":24})
    )

    assert [{"lucide:layer-arrow-up", icon}] = Cache.get_icons("lucide", ["layer-arrow-up"])
    assert icon.body =~ "<path"
    assert Cache.get_icons("lucide", ["no-such-icon-anywhere"]) == []
  end
end
