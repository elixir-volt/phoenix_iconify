defmodule PhoenixIconify.Manifest do
  @moduledoc """
  Manages the icon manifest stored in priv/.

  The manifest contains all discovered icons, cached between compilations.

  Each application compiled with the `:phoenix_iconify` compiler writes its
  own manifest. At runtime, icons are read from the manifests of every
  loaded application, so a library that ships `priv/iconify/manifest.json`
  brings its icons along; the application's own manifest wins when two
  define the same icon. The compiler and the mix tasks read and write only
  the application's own manifest.
  """

  @manifest_filename "manifest.json"
  @version 1

  @doc """
  Returns the path to the manifest file for the given application.
  """
  def manifest_path(app \\ nil) do
    app = app || Application.get_env(:phoenix_iconify, :otp_app) || mix_project_app()

    if app do
      Path.join([priv_dir(app), "iconify", @manifest_filename])
    else
      discover_manifest_path() || Path.join(["priv", "iconify", @manifest_filename])
    end
  end

  @doc """
  Reads the manifest from disk.

  Missing manifests are treated as empty. Invalid manifests raise.
  """
  @spec read(Path.t() | nil) :: %{String.t() => Iconify.Icon.t()}
  def read(path \\ nil) do
    path = path || manifest_path()

    case File.read(path) do
      {:ok, json} -> decode!(json)
      {:error, :enoent} -> %{}
      {:error, reason} -> raise File.Error, reason: reason, action: "read file", path: path
    end
  end

  @doc """
  Writes the manifest to disk.
  """
  @spec write(%{String.t() => Iconify.Icon.t()}, Path.t() | nil) :: :ok
  def write(icons, path \\ nil) when is_map(icons) do
    path = path || manifest_path()
    File.mkdir_p!(Path.dirname(path))

    payload = %{version: @version, icons: icons |> Map.values() |> Enum.sort_by(& &1.name)}
    File.write!(path, Jason.encode_to_iodata!(payload, pretty: true))
  end

  @doc """
  Reads and merges the manifests at `paths`, later ones winning.

  Defaults to `manifest_paths/0`: the manifests of loaded libraries, then
  the application's own.
  """
  @spec read_all([Path.t()]) :: %{String.t() => Iconify.Icon.t()}
  def read_all(paths \\ manifest_paths()) do
    Enum.reduce(paths, %{}, fn path, icons -> Map.merge(icons, read(path)) end)
  end

  @doc """
  Returns the manifests runtime icons come from: those shipped by loaded
  applications, sorted by application, followed by the application's own
  manifest, which may not exist yet.
  """
  @spec manifest_paths() :: [Path.t()]
  def manifest_paths do
    own = manifest_path()

    # Applications without a code path have no priv directory of their own.
    libraries =
      for app <- loaded_apps(),
          priv = :code.priv_dir(app),
          is_list(priv),
          path = Path.join([List.to_string(priv), "iconify", @manifest_filename]),
          path != own and File.regular?(path),
          do: path

    libraries ++ [own]
  end

  @doc """
  Gets icons from every loaded manifest, loading from persistent storage on
  first use.
  """
  def get_icons do
    case :persistent_term.get({__MODULE__, :icons}, nil) do
      nil ->
        icons = read_all()
        :persistent_term.put({__MODULE__, :icons}, icons)
        icons

      icons ->
        icons
    end
  end

  @doc """
  Reloads icons from disk into persistent_term.
  """
  def reload do
    icons = read_all()
    :persistent_term.put({__MODULE__, :icons}, icons)
    icons
  end

  @doc """
  Clears the cached icons.
  """
  def clear_cache do
    :persistent_term.erase({__MODULE__, :icons})
  end

  @doc """
  Adds an icon to the runtime cache and optionally persists to disk.
  """
  def add_icon(name, %Iconify.Icon{} = icon, opts \\ []) do
    icon = %{icon | name: name}
    :persistent_term.put({__MODULE__, :icons}, Map.put(get_icons(), name, icon))

    # Only the application's own manifest, never icons from its libraries.
    if Keyword.get(opts, :persist, false) do
      write(Map.put(read(), name, icon))
    end

    :ok
  end

  @doc """
  Returns the number of icons in the manifest.
  """
  def count do
    get_icons() |> map_size()
  end

  defp priv_dir(app) do
    case :code.priv_dir(app) do
      {:error, :bad_name} -> "priv"
      path -> List.to_string(path)
    end
  end

  defp discover_manifest_path do
    loaded_apps()
    |> Enum.map(&Path.join([priv_dir(&1), "iconify", @manifest_filename]))
    |> Enum.find(&File.regular?/1)
  end

  defp loaded_apps do
    :application.loaded_applications()
    |> Enum.map(fn {app, _description, _version} -> app end)
    |> Enum.reject(&(&1 in [:phoenix_iconify, :iconify]))
    |> Enum.sort()
  end

  defp mix_project_app do
    if Code.ensure_loaded?(Mix.Project) and function_exported?(Mix.Project, :config, 0) do
      Mix.Project.config()[:app]
    end
  end

  defp decode!(json) do
    _icon_defaults = struct!(Iconify.Icon, name: "", body: "")
    %{version: @version, icons: icons} = Jason.decode!(json, keys: :atoms!)

    unless is_list(icons) do
      raise ArgumentError, "invalid PhoenixIconify manifest: expected icons to be a list"
    end

    Map.new(icons, &icon_entry/1)
  end

  defp icon_entry(icon) do
    icon = struct!(Iconify.Icon, icon)
    {icon.name, icon}
  end
end
