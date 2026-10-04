# PhoenixIconify

[![Hex.pm](https://img.shields.io/hexpm/v/phoenix_iconify.svg)](https://hex.pm/packages/phoenix_iconify) [![Documentation](https://img.shields.io/badge/documentation-gray)](https://hexdocs.pm/phoenix_iconify)

Inline [Iconify](https://iconify.design) SVGs for Phoenix and LiveView. Write a normal Phoenix component, let the compiler discover the icons you use, and ship only those icons with your app.

```heex
<.icon name="lucide:settings" class="size-5" />
```

PhoenixIconify gives Phoenix apps access to 200,000+ icons from 150+ icon sets without a client-side icon runtime. Browse icons at [icon-sets.iconify.design](https://icon-sets.iconify.design).

## Why PhoenixIconify

Most Iconify integrations load icons in JavaScript. PhoenixIconify keeps icons on the server:

- Icons are discovered from HEEx at compile time
- Only icons you use are fetched and stored
- Rendering is plain inline SVG
- SVG IDs are rewritten to avoid duplicate gradient/mask collisions
- No browser-side icon loader
- Works with LiveView diffs and `phx-*` attributes
- Dynamic icons can be pre-registered in config

It pairs naturally with Tailwind and Volt-powered Phoenix projects:

```heex
<button class="inline-flex items-center gap-2">
  <.icon name="lucide:settings" class="size-4" />
  Settings
</button>
```

## Installation

Add the dependency:

```elixir
def deps do
  [
    {:phoenix_iconify, "~> 0.3.2"}
  ]
end
```

Add the compiler:

```elixir
def project do
  [
    compilers: Mix.compilers() ++ [:phoenix_iconify]
  ]
end
```

Import the component in your web module:

```elixir
# lib/my_app_web.ex
defp html_helpers do
  quote do
    import PhoenixIconify, only: [icon: 1]
  end
end
```

Now use icons in HEEx:

```heex
<.icon name="lucide:settings" class="size-5" />
```

## Usage

Use Iconify's standard `prefix:name` format:

```heex
<.icon name="lucide:home" class="size-5" />
<.icon name="mdi:account" class="size-6 text-blue-600" />
<.icon name="heroicons:check" class="size-4" />
```

Phoenix-style Heroicons names are supported too:

```heex
<.icon name="hero-user" class="size-6" />
<.icon name="hero-sun-mini" class="size-5" />
<.icon name="hero-sun-micro" class="size-4" />
```

Global attributes are forwarded to the SVG, including `phx-*`, `data-*`, and `aria-*`:

```heex
<.icon name="lucide:x" class="size-4" phx-click="close" data-testid="close" />
```

Use `color` for currentColor icon sets and `inline` when an icon should align with text:

```heex
<span>
  Saved <.icon name="lucide:check" color="green" inline />
</span>
```

## Accessibility

Icons are decorative by default and render with `aria-hidden="true"`:

```heex
<.icon name="lucide:settings" class="size-5" />
```

For meaningful icons, provide `label` or `title`:

```heex
<.icon name="lucide:settings" label="Settings" />
<.icon name="lucide:settings" title="Settings" />
```

## Sizing

Use Tailwind's `size-*` utilities when possible:

```heex
<.icon name="lucide:settings" class="size-5" />
```

PhoenixIconify follows Iconify's dimension behavior. Icons default to `1em` high and preserve their aspect ratio. Set one dimension and the other is calculated from the viewBox:

```heex
<.icon name="lucide:settings" size="20" />
<.icon name="lucide:settings" height="1em" />
<.icon name="lucide:settings" width="unset" />
```

## Transformations and render modes

Iconify aliases can include transformations, and you can transform at render time:

```heex
<.icon name="lucide:arrow-right" rotate={1} />
<.icon name="lucide:arrow-right" flip="horizontal" />
<.icon name="lucide:arrow-right" h_flip />
<.icon name="lucide:arrow-right" v_flip />
```

SVG mode is the default. CSS mask/background modes are available for Iconify-style CSS rendering:

```heex
<.icon name="lucide:settings" mode="mask" class="size-5" />
<.icon name="logos:elixir" mode="bg" class="size-5" />
```

SVG IDs are replaced automatically, so icons with gradients, masks, clip paths, or animation references can be rendered multiple times on the same page.

## How it works

1. You write `<.icon name="lucide:settings" />`
2. The `:phoenix_iconify` compiler scans HEEx and `~H` sigils
3. Literal icon names are collected
4. Missing icons are fetched through Iconify
5. A JSON manifest is written to `priv/iconify/manifest.json`
6. At runtime, the component reads icons from the manifest and renders inline SVG

There is no client-side icon runtime and no JavaScript bundle impact.

## Dynamic icons

Compile-time discovery only works for literal names. If an icon name comes from assigns, a database, or user configuration, register the possible values:

```elixir
# config/config.exs
config :phoenix_iconify,
  extra_icons: [
    "lucide:check",
    "lucide:x",
    "lucide:alert-triangle"
  ]
```

Then dynamic usage works at runtime:

```heex
<.icon name={@status_icon} class="size-4" />
```

## Configuration

```elixir
config :phoenix_iconify,
  extra_icons: ["lucide:check", "lucide:x"],
  fallback: "lucide:circle-help",
  warn_on_missing: true
```

Options:

- `:extra_icons` - icons to include even when they are not found by static discovery
- `:source_globs` - source globs to scan for literal icon usage. Defaults to Phoenix sources (`lib/**/*.ex`, `lib/**/*.heex`, `priv/**/*.heex`). In projects that depend on [Astral](https://hex.pm/packages/astral), the defaults also include its templates and Markdown: `pages/**/*.{astral,md}`, `components/**/*.astral`, `layouts/**/*.astral`, and `content/**/*.md`.
- `:fallback` - icon to render when a requested icon is missing
- `:warn_on_missing` - log missing icon warnings, enabled by default

## Cache and manifest

PhoenixIconify stores:

- `priv/iconify/manifest.json` - icons used by your app
- `priv/iconify/sets/*.json` - cached icon sets

Useful tasks:

```bash
mix phoenix_iconify.prefetch  # scan and fetch discovered icons
mix phoenix_iconify.audit     # report discovered icons missing from the manifest
mix phoenix_iconify.clean     # remove manifest icons no longer used
mix phoenix_iconify.list      # list manifest icons
mix phoenix_iconify.stats     # show manifest and cache stats
```

Cache tasks:

```bash
mix phoenix_iconify.cache fetch
mix phoenix_iconify.cache list
mix phoenix_iconify.cache clear
```

## Icons in libraries

A library can use icons in its own components, and they reach the application without any configuration there. Add the compiler to the library's `mix.exs` as above, and ship its manifest in the Hex package:

```elixir
defp package do
  [files: ~w(lib priv/iconify/manifest.json mix.exs README.md LICENSE)]
end
```

Commit `priv/iconify/manifest.json`, so applications compiling the library never fetch icons. At runtime, icons are read from the manifests of every loaded application; when two define the same icon, the application's own manifest wins. The compiler and the `mix phoenix_iconify.*` tasks only ever read and write the current project's own manifest.

## Volt projects

For projects created with [Volt](https://hex.pm/packages/volt), PhoenixIconify is the server-rendered option:

```heex
<.icon name="lucide:settings" class="size-5" />
```

It does not use Volt's JavaScript pipeline. If you want client-side icon components instead, use the official npm packages (`iconify-icon`, `@iconify/react`, `@iconify/vue`, etc.) through Volt's normal package handling.

## Part of Elixir Volt

phoenix_iconify ships compile-time discovered, server-rendered Iconify SVGs for Phoenix — 200,000+ icons, zero client runtime.

It is part of a frontend stack that runs inside the BEAM — builds, JS
runtimes, icons, and Vue-to-LiveView compilation as supervised parts of the
application instead of external toolchain processes. See the
[Elixir Volt](https://github.com/elixir-volt) organization for the rest, and
[Building Blocks for the Future Web](https://github.com/elixir-vibe/building-blocks)
for the thesis, architecture, and roadmap that tie them together.

## License

MIT
