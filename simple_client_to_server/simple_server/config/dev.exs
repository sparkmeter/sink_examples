use Mix.Config
alias SimpleServer.Repo

# Configure your database
config :simple_server, Repo,
  username: "postgres",
  password: "postgres",
  database: "simple_server_dev",
  hostname: "localhost",
  show_sensitive_data_on_connection_error: true,
  pool_size: 10
