defmodule SimpleServer.MixProject do
  use Mix.Project

  def project do
    [
      aliases: aliases(),
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

  def aliases do
    [
      "ecto.reset": ["ecto.drop", "ecto.create", "ecto.migrate"]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ecto_sql, "~> 3.6"},
      {:postgrex, ">= 0.0.0"},
      {:sink, github: "sparkmeter/sink"}
    ]
  end
end
