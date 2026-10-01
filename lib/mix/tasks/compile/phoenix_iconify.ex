defmodule Mix.Tasks.Compile.PhoenixIconify do
  @moduledoc """
  Compiles icon assets by discovering icons used in templates.

  This compiler:
  1. Scans compiled modules for icon component calls
  2. Extracts literal icon names from the `name` attribute
  3. Fetches missing icons from Iconify
  4. Updates the manifest in priv/iconify/

  ## Usage

  Add to your mix.exs:

      def project do
        [
          compilers: Mix.compilers() ++ [:phoenix_iconify],
          # ...
        ]
      end

  """

  use Mix.Task.Compiler

  alias PhoenixIconify.{Cache, Discovery, Manifest}

  @recursive true

  @impl true
  def run(_args) do
    {:ok, _} = Application.ensure_all_started(:req)

    icons = Discovery.icons()

    if icons == [] do
      {:ok, []}
    else
      process_icons(icons)
    end
  end

  defp process_icons(icon_names) do
    {valid, invalid} = Discovery.split_valid(icon_names)

    for name <- invalid do
      Mix.shell().error(
        "PhoenixIconify: Invalid icon name format: #{inspect(name)}. " <>
          "Expected format: \"prefix:icon-name\" (e.g., \"heroicons:user\")"
      )
    end

    manifest = Manifest.read()
    missing = Enum.reject(valid, &Map.has_key?(manifest, &1))

    fetch_missing_icons(manifest, missing)
  end

  defp fetch_missing_icons(_manifest, []), do: {:ok, []}

  defp fetch_missing_icons(manifest, missing) do
    total = length(missing)
    Mix.shell().info("PhoenixIconify: Fetching #{total} icon(s)...")

    fetched = fetch_icons(missing)
    Manifest.write(Map.merge(manifest, fetched))
    Manifest.clear_cache()
    report_fetch_result(total, map_size(fetched))

    {:ok, []}
  end

  defp report_fetch_result(total, fetched) when total == fetched do
    Mix.shell().info("PhoenixIconify: Fetched #{fetched} icon(s)")
  end

  defp report_fetch_result(total, fetched) do
    Mix.shell().info("PhoenixIconify: Fetched #{fetched}, failed #{total - fetched}")
  end

  defp fetch_icons(icon_names) do
    results =
      icon_names
      |> Enum.group_by(fn name ->
        case Iconify.parse_name(name) do
          {:ok, prefix, _icon_name} -> prefix
          :error -> nil
        end
      end)
      |> Enum.reject(fn {prefix, _} -> is_nil(prefix) end)
      |> Enum.flat_map(fn {prefix, names} ->
        fetch_prefix_icons(prefix, names)
      end)

    fetched_names = Enum.map(results, fn {name, _} -> name end)
    not_found = icon_names -- fetched_names

    for name <- not_found do
      Mix.shell().error("PhoenixIconify: Icon not found: #{name}")
    end

    Map.new(results)
  end

  defp fetch_prefix_icons(prefix, full_names) do
    Cache.get_icons(prefix, Enum.map(full_names, &icon_name!/1))
  end

  defp icon_name!(name) do
    {:ok, _prefix, icon_name} = Iconify.parse_name(name)
    icon_name
  end
end
