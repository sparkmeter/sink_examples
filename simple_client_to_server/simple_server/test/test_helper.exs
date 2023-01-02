alias Ecto.Adapters.SQL.Sandbox
alias SimpleServer.Repo
ExUnit.start()

Sandbox.mode(Repo, :manual)
