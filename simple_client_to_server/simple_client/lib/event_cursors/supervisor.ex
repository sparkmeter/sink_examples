defmodule EventCursors.Supervisor do
  @moduledoc false
  use Supervisor

  def start_link(init_args) do
    Supervisor.start_link(__MODULE__, init_args, name: __MODULE__)
  end

  @impl true
  def init(storage: storage_mod) do
    children = [
      {EventCursors.Coordinator, storage_mod: storage_mod},
      {Registry, keys: :unique, name: EventCursors.Registry},
      {DynamicSupervisor, strategy: :one_for_one, name: EventCursors.DynamicSupervisor}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
