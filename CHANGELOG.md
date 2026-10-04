# Changelog

## v0.3.7

- Read runtime icons from the manifests of every loaded application, so libraries can ship `priv/iconify/manifest.json` with the icons their components use. The application's own manifest wins when two define the same icon; the compiler and mix tasks still read and write only the project's own manifest. `PhoenixIconify.Manifest.read_all/1` and `manifest_paths/0` expose the merged view.
- `PhoenixIconify.Manifest.add_icon/3` with `persist: true` writes the application's own manifest plus the new icon, not the merged runtime set.

## v0.3.6

- Fetch icons that a cached icon set lacks from the Iconify API. A set cached before an icon was added to the collection made new icons fail with "Icon not found" (#2).
- Report unknown icon names as not found instead of raising when fetching from the Iconify API. Requires `iconify` 0.3.1.
- Scan Markdown files for icon components. v0.3.5 added `content/**/*.md` to the default globs but skipped those files.
- Include Astral templates and Markdown in the default globs only when Astral is a dependency, so other projects don't scan their Markdown.

## v0.3.5

- Add configurable scanner source globs
- Include Astral `.astral` templates and Markdown content in default icon discovery globs

## v0.3.4

- Avoid `Mix.Project.config/0` at runtime when resolving the icon manifest path in OTP releases by using configured or discovered application priv directories

## v0.3.3

- Fix HEEx icon discovery with Phoenix LiveView 1.2 tag engine parser
- Keep scanner compatibility with LiveView 1.1 and older tokenizer APIs

## v0.3.2

- Improve compile-time icon discovery for wrapper component `icon` attributes and same-line recoverable HEEx inside EEx blocks
- Discover literal icon names returned by icon helper functions
- Include `priv/**/*.heex` templates in scanner source paths

## v0.3.1

- Fix manifest decoding for Mix tasks when persisted icon field atoms are not loaded yet

## v0.3.0

- Replace SVG IDs during rendering to avoid duplicate ID collisions
- Add Iconify-style dimension calculation and `1em` defaults
- Add `color`, `inline`, and `mask`/`bg` render modes

## v0.2.0

- Store discovered icons in a readable JSON manifest
- Render normalized `%Iconify.Icon{}` data directly from the manifest
- Add compile-time discovery through Elixir AST traversal and Phoenix LiveView tokenization
- Add accessibility, sizing, and transformation options to `<.icon />`
- Add `prefetch`, `audit`, and `clean` Mix tasks
- Add CI checks with Credo, Reach smell checks, ExDNA, and tests
- Polish README and package metadata for the `elixir-volt` organization

## v0.1.0

- Initial release
- Phoenix component for rendering icons
- Compile-time icon discovery from `__components_calls__`
- Automatic icon fetching from Iconify API
- Manifest caching in priv/iconify/
