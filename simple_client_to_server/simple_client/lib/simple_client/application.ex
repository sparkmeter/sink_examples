defmodule SimpleClient.Application do
  @moduledoc false

  use Application

  alias SimpleClient.{
    Repo
    # SinkHandler,
  }

  @impl Application
  def start(_type, _args) do
    children = [
      Repo
    ]

    result =
      Supervisor.start_link(children, strategy: :one_for_one, name: SimpleClient.Supervisor)

    result
  end
end
