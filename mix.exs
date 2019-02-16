defmodule CartEcto.MixProject do
  use Mix.Project

  def project do
    [
      app: :cart_ecto,
      version: "0.1.0",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {CartEcto.Application, []}
    ]
  end

  defp deps do
    []
  end
end
