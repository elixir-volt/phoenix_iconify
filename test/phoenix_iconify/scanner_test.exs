defmodule PhoenixIconify.ScannerTest do
  use ExUnit.Case, async: false

  @moduletag :tmp_dir

  alias PhoenixIconify.Scanner

  test "scans configured Astral source globs", %{tmp_dir: tmp} do
    File.mkdir_p!(Path.join(tmp, "components"))

    File.write!(
      Path.join(tmp, "components/link.astral"),
      ~s(<.icon name="ri:external-link-fill" />)
    )

    previous = Application.get_env(:phoenix_iconify, :source_globs)
    Application.put_env(:phoenix_iconify, :source_globs, ["components/**/*.astral"])

    try do
      icons = File.cd!(tmp, &Scanner.scan/0)
      assert icons == ["ri:external-link-fill"]
    after
      if previous do
        Application.put_env(:phoenix_iconify, :source_globs, previous)
      else
        Application.delete_env(:phoenix_iconify, :source_globs)
      end
    end
  end

  test "scans icon components in Markdown", %{tmp_dir: tmp} do
    File.mkdir_p!(Path.join(tmp, "content"))

    File.write!(Path.join(tmp, "content/post.md"), """
    # Post

    Reach me by <.icon name="lucide:mail" /> email, or <.nav_link icon="lucide:rss">the feed</.nav_link>.

    ```elixir
    if a < b, do: :ok
    ```
    """)

    previous = Application.get_env(:phoenix_iconify, :source_globs)
    Application.put_env(:phoenix_iconify, :source_globs, ["content/**/*.md"])

    try do
      assert File.cd!(tmp, &Scanner.scan/0) == ["lucide:mail", "lucide:rss"]
    after
      if previous do
        Application.put_env(:phoenix_iconify, :source_globs, previous)
      else
        Application.delete_env(:phoenix_iconify, :source_globs)
      end
    end
  end

  describe "default source globs" do
    setup %{tmp_dir: tmp} do
      File.mkdir_p!(Path.join(tmp, "content"))
      File.write!(Path.join(tmp, "content/post.md"), ~s(Mail <.icon name="lucide:mail" />.))

      previous = Application.get_env(:phoenix_iconify, :source_globs)
      Application.delete_env(:phoenix_iconify, :source_globs)

      on_exit(fn ->
        if previous, do: Application.put_env(:phoenix_iconify, :source_globs, previous)
      end)
    end

    test "skip Markdown without Astral", %{tmp_dir: tmp} do
      refute Code.ensure_loaded?(Astral)
      assert File.cd!(tmp, &Scanner.scan/0) == []
    end

    test "include Astral templates and Markdown when Astral is present", %{tmp_dir: tmp} do
      Code.compile_string("defmodule Astral do end")

      on_exit(fn ->
        :code.purge(Astral)
        :code.delete(Astral)
      end)

      assert File.cd!(tmp, &Scanner.scan/0) == ["lucide:mail"]
    end
  end

  describe "scan_heex_content/1" do
    test "extracts icon names from heex content" do
      content = """
      <.icon name="heroicons:user" class="w-6" />
      <.icon name="lucide:home" />
      <.icon name={"mdi:account"} />
      """

      icons = Scanner.scan_heex_content(content)
      assert "heroicons:user" in icons
      assert "lucide:home" in icons
      assert "mdi:account" in icons
    end

    test "normalizes hero- prefix to heroicons:" do
      content = ~s(<.icon name="hero-user" />)
      icons = Scanner.scan_heex_content(content)
      assert "heroicons:user" in icons
    end

    test "converts micro suffix to 16-solid" do
      content = ~s(<.icon name="hero-sun-micro" />)
      icons = Scanner.scan_heex_content(content)
      assert "heroicons:sun-16-solid" in icons
    end

    test "converts mini suffix to 20-solid" do
      content = ~s(<.icon name="hero-sun-mini" />)
      icons = Scanner.scan_heex_content(content)
      assert "heroicons:sun-20-solid" in icons
    end

    test "finds literal icon strings passed through component attributes" do
      content = ~s(<.nav_item icon="lucide:messages-square">Sessions</.nav_item>)
      icons = Scanner.scan_heex_content(content)
      assert "lucide:messages-square" in icons
    end

    test "recovers same-line icons when the surrounding HEEx cannot be tokenized as a whole" do
      content = ~s(<%= if true do %>\n<.icon name="lucide:circle-check" />\n<% end %>)
      icons = Scanner.scan_heex_content(content)
      assert "lucide:circle-check" in icons
    end

    test "ignores icons without prefix:name format" do
      content = ~s(<.icon name="just-a-name" />)
      icons = Scanner.scan_heex_content(content)
      assert icons == []
    end
  end
end
