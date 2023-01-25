defmodule SimpleClient.MixProject do
  use Mix.Project

  def project do
    [
      aliases: aliases(),
      app: :simple_client,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {SimpleClient.Application, []},
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
      {:broadway, "~> 1.0.5"},
      {:ecto_sql, "~> 3.8.2"},
      {:ecto_sqlite3, "~> 0.7.2"},
      {:event_queues, path: "../event_queues"},
      {:exqlite, "~> 0.10.3"},
      {:sink, github: "sparkmeter/sink"}
      # {:sink, github: "spark_meter/sink"}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end
end
