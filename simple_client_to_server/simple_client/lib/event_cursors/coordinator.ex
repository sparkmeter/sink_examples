defmodule EventCursors.Coordinator do
  @moduledoc """
  Coordinates starting and stopping CursorsManagers for a subscription and client_id
  """
  use GenServer
  alias EventCursors.CursorManager

  defmodule State do
    @moduledoc false

    defstruct [:storage_mod, :cursor_managers]

    def init(storage_mod) do
      %State{
        storage_mod: storage_mod,
        cursor_managers: %{}
      }
    end

    def add_client(state, subscription_name, client_id, client_instance_id, pid, ref) do
      %State{
        state
        | cursor_managers:
            Map.put(
              state.cursor_managers,
              {subscription_name, client_id},
              {client_instance_id, pid, ref}
            )
      }
    end

    def registered?(state, subscription_name, client_id, _client_instance_id) do
      # todo: handle mismatched client_id
      # should we use the registry?
      Map.has_key?(state.cursor_managers, {subscription_name, client_id})
    end
  end

  def start_link(init_args) do
    # todo: inject registry so we can use Horde.Registry ?
    GenServer.start_link(__MODULE__, init_args, name: __MODULE__)
  end

  @doc """
  Starts a CursorManager for the subscription and client if no other process is running for that client.

  - Ensures no other process is running for the client_id
  - Starts a CursorManager under the dynamic supervisor
  """
  def add_client(subscription_name, client_id, client_instance_id) do
    GenServer.call(__MODULE__, {:add_client, subscription_name, client_id, client_instance_id})
  end

  @impl true
  def init(storage_mod: storage_mod) do
    {:ok, State.init(storage_mod)}
  end

  @impl true
  def handle_call({:add_client, sub_name, client_id, client_instance_id}, _from, state) do
    if !registered?(state, sub_name, client_id, client_instance_id) do
      {:ok, pid} =
        DynamicSupervisor.start_child(
          EventCursors.DynamicSupervisor,
          {CursorManager,
           [
             storage_mod: state.storage_mod,
             subscription_name: sub_name,
             client_id: client_id,
             client_instance_id: client_instance_id
           ]}
        )

      ref = Process.monitor(pid)
      new_state = State.add_client(state, sub_name, client_id, client_instance_id, pid, ref)
      {:reply, :ok, new_state}
    else
      {:reply, {:error, :in_use}, state}
    end
  end

  defp registered?(state, subscription_name, client_id, client_instance_id) do
    # todo: also use global lock and/or postgres locks or something to ensure global uniquess
    # postgres would be nice since it handles network splits
    State.registered?(state, subscription_name, client_id, client_instance_id)
  end
end