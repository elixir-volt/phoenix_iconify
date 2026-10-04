defmodule PhoenixIconify.LibraryManifestsTest do
  # Loads applications and changes :otp_app and the cached icons, all node-wide.
  use ExUnit.Case, async: false

  alias PhoenixIconify.Manifest

  @moduletag :tmp_dir

  defp icon(name, body), do: %Iconify.Icon{name: name, body: body, width: 24, height: 24}

  # An application on the code path with its own priv/iconify/manifest.json,
  # as a library compiled with the :phoenix_iconify compiler ships it. The
  # directory is named after the application so :code.priv_dir/1 finds it.
  defp load_app(tmp_dir, icons) do
    app = :"iconify_fixture_#{System.unique_integer([:positive])}"
    dir = Path.join(tmp_dir, Atom.to_string(app))
    ebin = Path.join(dir, "ebin")
    File.mkdir_p!(ebin)

    spec = {:application, app, [vsn: ~c"1.0.0", modules: [], applications: []]}
    File.write!(Path.join(ebin, "#{app}.app"), :io_lib.format(~c"~p.~n", [spec]))

    if icons != %{},
      do: Manifest.write(icons, Path.join([dir, "priv", "iconify", "manifest.json"]))

    true = Code.prepend_path(ebin)
    :ok = Application.load(app)

    on_exit(fn ->
      Application.unload(app)
      Code.delete_path(ebin)
    end)

    app
  end

  defp use_own_app(app) do
    previous = Application.get_env(:phoenix_iconify, :otp_app)
    Application.put_env(:phoenix_iconify, :otp_app, app)
    Manifest.clear_cache()

    on_exit(fn ->
      Manifest.clear_cache()

      if previous,
        do: Application.put_env(:phoenix_iconify, :otp_app, previous),
        else: Application.delete_env(:phoenix_iconify, :otp_app)
    end)
  end

  test "read_all/1 merges manifests, later ones winning", %{tmp_dir: tmp_dir} do
    library = Path.join(tmp_dir, "library.json")
    own = Path.join(tmp_dir, "own.json")

    Manifest.write(
      %{"lucide:a" => icon("lucide:a", "lib"), "lucide:b" => icon("lucide:b", "lib")},
      library
    )

    Manifest.write(%{"lucide:b" => icon("lucide:b", "own")}, own)

    icons = Manifest.read_all([library, own, Path.join(tmp_dir, "missing.json")])

    assert icons["lucide:a"].body == "lib"
    assert icons["lucide:b"].body == "own"
  end

  test "runtime icons include loaded libraries', the application's own winning", %{
    tmp_dir: tmp_dir
  } do
    library =
      load_app(tmp_dir, %{
        "lucide:shared" => icon("lucide:shared", "library"),
        "lucide:only-lib" => icon("lucide:only-lib", "l")
      })

    own = load_app(tmp_dir, %{"lucide:shared" => icon("lucide:shared", "own")})
    use_own_app(own)

    paths = Manifest.manifest_paths()

    library_path =
      Path.join([List.to_string(:code.priv_dir(library)), "iconify", "manifest.json"])

    assert library_path in paths
    assert List.last(paths) == Manifest.manifest_path()

    icons = Manifest.get_icons()
    assert icons["lucide:only-lib"].body == "l"
    assert icons["lucide:shared"].body == "own"
    assert PhoenixIconify.icon_exists?("lucide:only-lib")
  end

  test "add_icon/3 persists only the application's own icons", %{tmp_dir: tmp_dir} do
    load_app(tmp_dir, %{"lucide:from-lib" => icon("lucide:from-lib", "l")})
    own = load_app(tmp_dir, %{})
    use_own_app(own)

    assert Map.has_key?(Manifest.get_icons(), "lucide:from-lib")

    :ok = Manifest.add_icon("lucide:new", icon("lucide:new", "n"), persist: true)

    assert Map.keys(Manifest.read()) == ["lucide:new"]
    assert Map.has_key?(Manifest.get_icons(), "lucide:from-lib")
  end
end
