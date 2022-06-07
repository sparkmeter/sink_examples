use Mix.Config
alias Ecto.Adapters.SQL.Sandbox
alias SimpleClient.Repo

config :logger, :level, :warn
config :simple_client, Repo, pool: Sandbox, ownership_timeout: 120_000
