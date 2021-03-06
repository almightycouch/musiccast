defmodule MusicCast.Mixfile do
  use Mix.Project

  @version "0.2.3"

  def project do
    [app: :musiccast,
     name: "Yamaha MusicCast™",
     version: @version,
     elixir: "~> 1.4",
     package: package(),
     description: description(),
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     docs: docs(),
     deps: deps()]
  end

  def application do
    [extra_applications: [:logger],
     mod: {MusicCast.Application, []}]
  end

  defp package do
    [files: ["lib", "mix.exs", "README.md", "LICENSE"],
     maintainers: ["Mario Flach"],
     licenses: ["MIT"],
     links: %{github: "https://github.com/almightycouch/musiccast"}]
  end

  defp description do
    "Yamaha MusicCast™ implementation"
  end

  defp docs do
    [extras: ["README.md"],
     main: "readme",
     source_ref: "v#{@version}",
     source_url: "https://github.com/almightycouch/musiccast"]
  end

  defp deps do
    [{:httpoison, "~> 0.12"},
     {:poison, "~> 3.1"},
     {:sweet_xml, "~> 0.6"},
     {:html_entities, "~> 0.3"},
     {:plug, "~> 1.4", optional: true},
     {:ex_doc, "~> 0.16", only: :dev, runtime: false}]
  end
end
