defmodule PhoenixIconify.Cache do
  @moduledoc """
  Caches Iconify icon sets locally to avoid repeated API calls.

  Icon sets are stored in `priv/iconify/sets/` as JSON files.
  """

  @cache_dir "priv/iconify/sets"

  @doc """
  Returns the cache directory path.
  """
  def cache_dir do
    Application.get_env(:phoenix_iconify, :cache_dir, @cache_dir)
  end

  @doc """
  Returns the path for a cached icon set.
  """
  def set_path(prefix) do
    Path.join(cache_dir(), "#{prefix}.json")
  end

  @doc """
  Checks if an icon set is cached locally.
  """
  def has_set?(prefix) do
    File.exists?(set_path(prefix))
  end

  @doc """
  Loads a cached icon set.
  """
  def load_set(prefix) do
    path = set_path(prefix)

    with true <- File.exists?(path),
         {:ok, content} <- File.read(path) do
      Iconify.Set.parse(content)
    else
      false -> {:error, :not_found}
      error -> error
    end
  end

  @doc """
  Saves an icon set to cache.
  """
  def save_set(prefix, json_content) when is_binary(json_content) do
    path = set_path(prefix)
    dir = Path.dirname(path)

    File.mkdir_p!(dir)
    File.write!(path, json_content)

    :ok
  end

  @doc """
  Fetches an icon set, using cache if available.
  """
  def fetch_set(prefix) do
    case load_set(prefix) do
      {:ok, set} ->
        {:ok, set}

      {:error, _} ->
        fetch_and_cache_set(prefix)
    end
  end

  defp fetch_and_cache_set(prefix) do
    Mix.shell().info("  Downloading #{prefix} from NPM...")

    case Iconify.Fetcher.fetch_set(prefix) do
      {:ok, set} ->
        save_set(prefix, encode_set_to_json(set))
        {:ok, set}

      error ->
        error
    end
  end

  defp encode_set_to_json(set) do
    Jason.encode!(set, pretty: true)
  end

  @doc """
  Gets a specific icon from cache, fetching the set if needed.
  """
  def get_icon(prefix, icon_name) do
    case fetch_set(prefix) do
      {:ok, set} ->
        case Iconify.Set.get(set, icon_name) do
          {:ok, icon} -> {:ok, icon}
          :error -> {:error, :icon_not_found}
        end

      error ->
        error
    end
  end

  @doc """
  Gets icons of one set, keyed by their full `prefix:name`.

  Icons come from the cached set when it has them. A cached set can predate icons
  added to the collection since it was downloaded, so the rest are fetched one by
  one with `fetch_icon`. Icons that exist in neither are left out.
  """
  @spec get_icons(String.t(), [String.t()], (String.t(), String.t() ->
                                               {:ok, Iconify.Icon.t()} | {:error, term()})) ::
          [{String.t(), Iconify.Icon.t()}]
  def get_icons(prefix, icon_names, fetch_icon \\ &Iconify.Fetcher.fetch_icon/2) do
    cached =
      case fetch_set(prefix) do
        {:ok, set} ->
          for name <- icon_names,
              {:ok, icon} <- [Iconify.Set.get(set, name)],
              into: %{},
              do: {name, icon}

        {:error, _} ->
          %{}
      end

    for name <- icon_names,
        {:ok, icon} <- [cached_or_fetched(cached, prefix, name, fetch_icon)] do
      full_name = "#{prefix}:#{name}"
      {full_name, %{icon | name: full_name}}
    end
  end

  defp cached_or_fetched(cached, prefix, name, fetch_icon) do
    case Map.fetch(cached, name) do
      {:ok, icon} -> {:ok, icon}
      :error -> fetch_icon.(prefix, name)
    end
  end

  @doc """
  Clears all cached icon sets.
  """
  def clear do
    dir = cache_dir()

    if File.exists?(dir) do
      File.rm_rf!(dir)
    end

    :ok
  end

  @doc """
  Lists all cached icon set prefixes.
  """
  def list_cached_sets do
    dir = cache_dir()

    if File.exists?(dir) do
      dir
      |> File.ls!()
      |> Enum.filter(&String.ends_with?(&1, ".json"))
      |> Enum.map(&String.trim_trailing(&1, ".json"))
      |> Enum.sort()
    else
      []
    end
  end

  @doc """
  Returns cache statistics.
  """
  def stats do
    dir = cache_dir()

    if File.exists?(dir) do
      sets = list_cached_sets()

      total_size =
        Enum.reduce(sets, 0, fn set, total ->
          total + (set |> set_path() |> File.stat!()).size
        end)

      %{
        sets: length(sets),
        total_size: total_size,
        total_size_human: format_bytes(total_size)
      }
    else
      %{sets: 0, total_size: 0, total_size_human: "0 B"}
    end
  end

  defp format_bytes(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_bytes(bytes) when bytes < 1024 * 1024, do: "#{Float.round(bytes / 1024, 1)} KB"
  defp format_bytes(bytes), do: "#{Float.round(bytes / (1024 * 1024), 1)} MB"
end
