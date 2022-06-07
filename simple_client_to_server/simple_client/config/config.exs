# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config
alias SimpleClient.Repo

config :simple_client, ecto_repos: [Repo]

config :simple_client, Repo,
  database: "_build/#{Mix.env()}/db.sqlite3",
  # this can be :normal if you are ok with maybe losing data
  synchronous: :full,
  locking_mode: :normal,
  journal_mode: :wal,
  foreign_keys: :on,
  busy_timeout: 2000

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
