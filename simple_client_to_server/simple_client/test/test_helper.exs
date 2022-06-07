alias Ecto.Adapters.SQL.Sandbox
alias SimpleClient.Repo

ExUnit.start()
Sandbox.mode(Repo, :manual)
