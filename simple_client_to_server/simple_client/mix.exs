defmodule SimpleClient.MixProject do
  use Mix.Project

  def project do
    [
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

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ecto_sql, "~> 3.8.2"},
      {:ecto_sqlite3, "~> 0.7.2"},
      {:exqlite, "~> 0.10.3"},
      {:sink, path: "../../../sink"}
      # {:sink, github: "spark_meter/sink"}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end
end
