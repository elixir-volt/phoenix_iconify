defmodule PhoenixIconify.MixProject do
  use Mix.Project

  @version "0.3.6"
  @source_url "https://github.com/elixir-volt/phoenix_iconify"

  def project do
    [
      app: :phoenix_iconify,
      version: @version,
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      package: package(),
      docs: docs(),
      name: "PhoenixIconify",
      description: "Phoenix components for Iconify icons with compile-time discovery"
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:iconify, iconify_dep()},
      {:phoenix_live_view, "~> 0.20 or ~> 1.0"},
      {:req, "~> 0.5"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:reach, "~> 2.0", only: [:dev, :test], runtime: false},
      {:ex_dna, "~> 1.5", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.35", only: :dev, runtime: false}
    ]
  end

  # Use path dependency for local dev, Hex for published version
  defp iconify_dep do
    if path = System.get_env("ICONIFY_PATH") do
      [path: path]
    else
      "~> 0.3.1"
    end
  end

  def cli do
    [preferred_envs: [ci: :test, "test.e2e": :test]]
  end

  defp aliases do
    [
      "test.e2e": ["test --only e2e"],
      ci: [
        "compile --warnings-as-errors",
        "format --check-formatted",
        "credo --strict",
        "reach.check --smells --strict",
        "test",
        "ex_dna"
      ],
      lint: [
        "format --check-formatted",
        "compile --warnings-as-errors",
        "credo --strict",
        "reach.check --smells --strict",
        "ex_dna"
      ]
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url
      },
      files: ~w(lib priv mix.exs README.md LICENSE CHANGELOG.md)
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "CHANGELOG.md"],
      source_url: @source_url,
      source_ref: "v#{@version}"
    ]
  end
end
