defmodule MusicCast.Mixfile do
  use Mix.Project

  def project do
    [app: :musiccast,
     version: "0.1.0",
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  def application do
    [extra_applications: [:logger],
     mod: {MusicCast.Application, []}]
  end

  defp deps do
    []
  end
end
