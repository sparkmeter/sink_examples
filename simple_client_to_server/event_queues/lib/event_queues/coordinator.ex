defmodule EventQueues.Coordinator do
  @moduledoc """
  Coordinates starting and stopping QueueManagers for a subscription and client_id
  """
  use GenServer
  require Logger
  alias EventQueues.QueueManager

  defmodule State do
    @moduledoc false

    defstruct [:storage_mod, :subscription, :queue_managers]

    def init(storage_mod: storage_mod, subscription: subscription) do
      %State{
        storage_mod: storage_mod,
        subscription: subscription,
        queue_managers: %{}
      }
    end

    def add_client(state, client_id, client_instance_id, pid, ref) do
      %State{
        state
        | queue_managers:
            Map.put(
              state.queue_managers,
              client_id,
              {client_instance_id, pid, ref}
            )
      }
    end

    def remove_client(state, client_id) do
      %State{state | queue_managers: Map.delete(state.queue_managers, client_id)}
    end

    def registered?(state, client_id, _client_instance_id) do
      # todo: handle mismatched client_id
      # should we use the registry?
      Map.has_key?(state.queue_managers, client_id)
    end

    def get(state, client_id) do
      state.queue_managers[client_id]
    end

    def down(state, ref) do
      {client_id, _, _} =
        state.queue_managers
        |> Map.values()
        |> Enum.find(fn {_client_id, _pid, r} -> r == ref end)

      {:ok, State.remove_client(state, client_id), client_id}
    end
  end

  def start_link(init_args) do
    # todo: inject registry so we can use Horde.Registry ?
    subscription = Keyword.fetch!(init_args, :subscription)
    name = Module.concat(subscription, Coordinator)
    GenServer.start_link(__MODULE__, init_args, name: name)
  end

  @doc """
  Starts a QueueManager for the subscription and client if no other process is running for that client.

  - Ensures no other process is running for the client_id
  - Starts a QueueManager under the dynamic supervisor
  """
  def add_client(subscription, client_id, client_instance_id) do
    name = Module.concat(subscription, Coordinator)
    GenServer.call(name, {:add_client, client_id, client_instance_id})
  end

  @doc """
  Stops a QueueManager for the subscription and client if one is running
  """
  def remove_client(subscription, client_id) do
    name = Module.concat(subscription, Coordinator)
    GenServer.call(name, {:remove_client, client_id})
  end

  @impl true
  def init(args) do
    storage_mod = Keyword.fetch!(args, :storage_mod)
    subscription = Keyword.fetch!(args, :subscription)
    {:ok, State.init(storage_mod: storage_mod, subscription: subscription)}
  end

  @impl true
  def handle_call({:add_client, client_id, client_instance_id}, _from, state) do
    dynamic_sup_mod = Module.concat(state.subscription, DynamicSupervisor)

    if !registered?(state, client_id, client_instance_id) do
      {:ok, pid} =
        DynamicSupervisor.start_child(
          dynamic_sup_mod,
          {QueueManager,
           [
             storage_mod: state.storage_mod,
             subscription: state.subscription,
             client_id: client_id,
             client_instance_id: client_instance_id
           ]}
        )

      ref = Process.monitor(pid)
      new_state = State.add_client(state, client_id, client_instance_id, pid, ref)
      {:reply, :ok, new_state}
    else
      {:reply, {:error, :in_use}, state}
    end
  end

  def handle_call({:remove_client, client_id}, _from, state) do
    dynamic_sup_mod = Module.concat(state.subscription, DynamicSupervisor)

    with {_client_id, pid, _ref} <- State.get(state, client_id) do
      _ = DynamicSupervisor.terminate_child(dynamic_sup_mod, pid)
    end

    {:reply, :ok, state}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, reason}, state) do
    {:ok, new_state, client_id} = State.down(state, ref)
    # todo: remove client from state
    Logger.debug("client '#{client_id}' terminating for reason '#{reason}'")
    {:noreply, new_state}
  end

  defp registered?(state, client_id, client_instance_id) do
    # todo: also use global lock and/or postgres locks or something to ensure global uniquess
    # postgres would be nice since it handles network splits
    State.registered?(state, client_id, client_instance_id)
  end
end
