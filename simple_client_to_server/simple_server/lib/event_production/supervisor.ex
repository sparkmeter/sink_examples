defmodule EventProduction.Supervisor do
  @moduledoc false
  use Supervisor

  def start_link(init_args) do
    Supervisor.start_link(__MODULE__, init_args, name: __MODULE__)
  end

  @impl true
  def init(storage: storage_mod) do
    children = [
      {EventProduction.Coordinator, storage_mod: storage_mod},
      {Registry, keys: :unique, name: EventProduction.Registry},
      {DynamicSupervisor, strategy: :one_for_one, name: EventProduction.DynamicSupervisor}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
