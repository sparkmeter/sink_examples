defmodule SimpleServer.MixProject do
  use Mix.Project

  def project do
    [
      aliases: ["ecto.reset": ["ecto.drop", "ecto.create", "ecto.migrate"]],
      app: :simple_server,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {SimpleServer.Application, []},
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:broadway, ">= 0.0.0"},
      {:ecto_sql, "~> 3.6"},
      {:phoenix_pubsub, ">= 0.0.0"},
      {:postgrex, ">= 0.0.0"},
      {:sink, github: "sparkmeter/sink"}
    ]
  end
end
