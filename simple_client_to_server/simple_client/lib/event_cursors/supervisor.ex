defmodule EventCursors.Supervisor do
  @moduledoc false
  use Supervisor

  def start_link(init_args) do
    Supervisor.start_link(__MODULE__, init_args)
  end

  @impl true
  def init(storage: storage_mod, subscription: subscription) do
    registry_mod = Module.concat(subscription, Registry)
    dynamic_sup_mod = Module.concat(subscription, DynamicSupervisor)

    children = [
      {EventCursors.Coordinator, storage_mod: storage_mod, subscription: subscription},
      {Registry, keys: :unique, subscription: subscription, name: registry_mod},
      {DynamicSupervisor, strategy: :one_for_one, name: dynamic_sup_mod}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
