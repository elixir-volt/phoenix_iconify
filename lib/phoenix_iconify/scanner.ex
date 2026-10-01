defmodule PhoenixIconify.Scanner do
  @moduledoc """
  Scans source files for literal icon component usage.
  """

  @compile {:no_warn_undefined, {Phoenix.LiveView.Tokenizer, :init, 4}}
  @compile {:no_warn_undefined, {Phoenix.LiveView.Tokenizer, :tokenize, 5}}
  @compile {:no_warn_undefined, {Phoenix.LiveView.TagEngine.Parser, :tokenize, 2}}
  @compile {:no_warn_undefined, {Phoenix.LiveView.TagEngine.Tokenizer, :init, 4}}
  @compile {:no_warn_undefined, {Phoenix.LiveView.TagEngine.Tokenizer, :tokenize, 5}}

  alias Phoenix.LiveView.HTMLEngine
  alias Phoenix.LiveView.TagEngine
  alias Phoenix.LiveView.Tokenizer, as: LegacyTokenizer

  @default_source_globs [
    "lib/**/*.ex",
    "lib/**/*.heex",
    "priv/**/*.heex",
    "pages/**/*.astral",
    "components/**/*.astral",
    "layouts/**/*.astral",
    "content/**/*.md"
  ]

  @doc """
  Scans all relevant source files and extracts icon names.
  """
  def scan do
    source_paths()
    |> Enum.flat_map(&scan_file/1)
    |> Enum.uniq()
    |> Enum.sort()
  end

  @doc """
  Scans HEEx content for icon names. Exposed for testing.
  """
  def scan_heex_content(content) do
    content
    |> tokenize_heex("nofile")
    |> icons_from_tokens()
    |> Enum.uniq()
  end

  defp source_paths do
    :phoenix_iconify
    |> Application.get_env(:source_globs, @default_source_globs)
    |> List.wrap()
    |> Enum.flat_map(&Path.wildcard/1)
  end

  defp scan_file(path) do
    content = File.read!(path)

    cond do
      # Markdown in Astral and similar tools can use HEEx components.
      Path.extname(path) in [".heex", ".astral", ".md"] -> scan_heex(content, path)
      Path.extname(path) == ".ex" -> scan_ex(content)
      true -> []
    end
  rescue
    _ -> []
  end

  defp scan_heex(content, path) do
    content
    |> tokenize_heex(path)
    |> icons_from_tokens()
  end

  defp scan_ex(content) do
    case Code.string_to_quoted(content) do
      {:ok, ast} -> scan_ast(ast)
      {:error, _} -> []
    end
  end

  defp scan_ast(ast) do
    heex_icons = ast |> heex_sigil_sources() |> Enum.flat_map(&scan_heex_content/1)
    icon_function_icons = ast |> icon_function_string_literals()

    heex_icons ++ icon_function_icons
  end

  defp heex_sigil_sources(ast) do
    {_ast, sources} =
      Macro.prewalk(ast, [], fn
        {:sigil_H, _meta, [{:<<>>, _string_meta, [source]}, _modifiers]} = node, sources
        when is_binary(source) ->
          {node, [source | sources]}

        node, sources ->
          {node, sources}
      end)

    Enum.reverse(sources)
  end

  defp tokenize_heex(content, path) do
    do_tokenize_heex(content, path)
  rescue
    error ->
      if parse_error?(error) do
        tokenize_heex_lines(content, path)
      else
        reraise(error, __STACKTRACE__)
      end
  end

  defp tokenize_heex_lines(content, path) do
    content
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.flat_map(fn {line, line_number} ->
      try do
        do_tokenize_heex(line, path, line_number)
      rescue
        error ->
          if parse_error?(error) do
            []
          else
            reraise(error, __STACKTRACE__)
          end
      end
    end)
  end

  defp do_tokenize_heex(content, path, line \\ 1) do
    case heex_tokenizer() do
      :parser ->
        TagEngine.Parser.tokenize(content,
          file: path,
          line: line,
          column: 1,
          tag_handler: HTMLEngine,
          trim_eex: false,
          strip_eex_comments: true
        )

      :tag_engine_tokenizer ->
        state = TagEngine.Tokenizer.init(0, path, content, HTMLEngine)

        {tokens, _cont} =
          TagEngine.Tokenizer.tokenize(
            content,
            [line: line, column: 1],
            [],
            {:text, :enabled},
            state
          )

        tokens

      :legacy_tokenizer ->
        state = LegacyTokenizer.init(0, path, content, HTMLEngine)

        {tokens, _cont} =
          LegacyTokenizer.tokenize(
            content,
            [line: line, column: 1],
            [],
            {:text, :enabled},
            state
          )

        tokens
    end
  end

  defp heex_tokenizer do
    cond do
      Code.ensure_loaded?(TagEngine.Parser) -> :parser
      Code.ensure_loaded?(TagEngine.Tokenizer) -> :tag_engine_tokenizer
      Code.ensure_loaded?(LegacyTokenizer) -> :legacy_tokenizer
    end
  end

  defp parse_error?(error) do
    error
    |> Map.get(:__struct__)
    |> case do
      module when is_atom(module) ->
        module
        |> Atom.to_string()
        |> then(
          &(&1 in [
              "Elixir.Phoenix.LiveView.Tokenizer.ParseError",
              "Elixir.Phoenix.LiveView.TagEngine.Tokenizer.ParseError"
            ])
        )

      _ ->
        false
    end
  end

  defp icons_from_tokens(tokens) do
    tokens
    |> Enum.flat_map(&icon_from_token/1)
    |> Enum.reject(&is_nil/1)
  end

  defp icon_from_token({:local_component, "icon", attrs, _meta}) do
    attrs
    |> Enum.find_value(&icon_name_attr/1)
    |> List.wrap()
  end

  defp icon_from_token({:local_component, _name, attrs, _meta}) do
    attrs
    |> Enum.find_value(&component_icon_attr/1)
    |> List.wrap()
  end

  defp icon_from_token(_token), do: []

  defp icon_name_attr({"name", {:string, name, _meta}, _attr_meta}) do
    normalize_name(name)
  end

  defp icon_name_attr({"name", {:expr, expr, _meta}, _attr_meta}) do
    case Code.string_to_quoted(expr) do
      {:ok, name} when is_binary(name) -> normalize_name(name)
      _ -> nil
    end
  end

  defp icon_name_attr(_attr), do: nil

  defp component_icon_attr({"icon", {:string, name, _meta}, _attr_meta}) do
    normalize_name(name)
  end

  defp component_icon_attr({"icon", {:expr, expr, _meta}, _attr_meta}) do
    case Code.string_to_quoted(expr) do
      {:ok, name} when is_binary(name) -> normalize_name(name)
      _ -> nil
    end
  end

  defp component_icon_attr(_attr), do: nil

  defp icon_function_string_literals(ast) do
    {_ast, icons} =
      Macro.prewalk(ast, [], fn
        {kind, _meta, [{name, _name_meta, args}, [do: body]]} = node, icons
        when kind in [:def, :defp] and is_atom(name) and is_list(args) ->
          if icon_function?(name) do
            {node, string_literals(body) ++ icons}
          else
            {node, icons}
          end

        {kind, _meta, [{name, _name_meta, args}, body]} = node, icons
        when kind in [:def, :defp] and is_atom(name) and is_list(args) ->
          if icon_function?(name) do
            {node, string_literals(body) ++ icons}
          else
            {node, icons}
          end

        node, icons ->
          {node, icons}
      end)

    icons
    |> Enum.map(&normalize_name/1)
    |> Enum.reject(&is_nil/1)
  end

  defp icon_function?(name) do
    name
    |> Atom.to_string()
    |> String.contains?("icon")
  end

  defp string_literals(ast) do
    {_ast, strings} =
      Macro.prewalk(ast, [], fn
        string, strings when is_binary(string) -> {string, [string | strings]}
        node, strings -> {node, strings}
      end)

    strings
  end

  defp normalize_name("hero-" <> _rest = name), do: PhoenixIconify.normalize_name(name)

  defp normalize_name(name) do
    if valid_iconify_name?(name), do: name
  end

  defp valid_iconify_name?(name) when is_binary(name) do
    case String.split(name, ":", parts: 2) do
      [prefix, icon] -> valid_name_part?(prefix) and valid_name_part?(icon)
      _ -> false
    end
  end

  defp valid_iconify_name?(_name), do: false

  defp valid_name_part?(part) do
    part != "" and part |> String.to_charlist() |> Enum.all?(&valid_name_character?/1)
  end

  defp valid_name_character?(character) do
    character in ?a..?z or character in ?A..?Z or character in ?0..?9 or character in [?-, ?_]
  end
end
