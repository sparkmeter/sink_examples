defmodule EventCursors.CursorManager do
  @moduledoc """
  Tracks the ack'd and unack'd events for a subscription, provides events when asked.
  """
  use GenServer

  defmodule State do
    @moduledoc false

    fields = [
      :storage_mod,
      :subscription,
      :client_id,
      :client_instance_id,
      :inflight_cursor
    ]

    @enforce_keys fields
    defstruct fields

    def init(
          storage_mod: storage_mod,
          subscription: subscription,
          client_id: client_id,
          client_instance_id: client_instance_id,
          inflight_cursor: inflight_cursor
        ) do
      %State{
        storage_mod: storage_mod,
        subscription: subscription,
        client_id: client_id,
        client_instance_id: client_instance_id,
        inflight_cursor: inflight_cursor
      }
    end

    def taken(state, last_seq_number) do
      %State{state | inflight_cursor: last_seq_number}
    end
  end

  @spec start_link(term) :: GenServer.on_start()
  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  def take(subscription, client_id, num) do
    case registry_lookup(subscription, client_id) do
      [{pid, _}] ->
        GenServer.call(pid, {:take, num})
    end
  end

  #  def dispatch(subscription, message) do
  #    Registry.dispatch(Registry.PubSubTest, "hello", fn entries ->
  #      for {pid, _} <- entries, do: send(pid, {:broadcast, "world"})
  #    end)
  #  end

  def nack(_client_id, _sequence_number) do
  end

  def external_nack(_client_id) do
  end

  def clear_external_nack(_client_id) do
  end

  @impl true
  def init(
        storage_mod: storage_mod,
        subscription: subscription,
        client_id: client_id,
        client_instance_id: client_instance_id
      ) do
    {:ok, _} =
      Registry.register(
        registry_mod(subscription),
        {:cursor_manager, subscription, client_id},
        1_234_567_890
      )

    cursor =
      storage_mod.get_earliest_unsent_sequence_number(
        subscription,
        client_id,
        client_instance_id
      )

    {:ok,
     State.init(
       storage_mod: storage_mod,
       subscription: subscription,
       client_id: client_id,
       client_instance_id: client_instance_id,
       inflight_cursor: cursor
     )}
  end

  @impl true
  def handle_call({:take, num}, _from, state) do
    # should this switch to GenStage and handle_demand ?
    {events, last_seq_number} =
      state.storage_mod.take(
        state.subscription,
        state.client_id,
        state.client_instance_id,
        state.inflight_cursor,
        num
      )

    {:reply, events, State.taken(state, last_seq_number)}
  end

  defp registry_mod(subscription), do: Module.concat(subscription, Registry)

  defp registry_lookup(subscription, client_id) do
    Registry.lookup(
      registry_mod(subscription),
      {:cursor_manager, subscription, client_id}
    )
  end
end
