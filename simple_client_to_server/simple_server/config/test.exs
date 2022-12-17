use Mix.Config
alias SimpleServer.Repo

config :logger, :level, :warn

# Configure your database
config :simple_server, Repo,
  username: "postgres",
  password: "postgres",
  database: "simple_server_test#{System.get_env("MIX_TEST_PARTITION")}",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox
