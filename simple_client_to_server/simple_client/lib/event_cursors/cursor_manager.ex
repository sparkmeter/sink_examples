defmodule EventCursors.CursorManager do
  @moduledoc """
  Tracks the ack'd and unack'd events for a subscription, provides events when asked.
  """
  use GenServer
  @registry EventCursors.Registry

  defmodule State do
    @moduledoc false

    fields = [
      :storage_mod,
      :subscription_name,
      :client_id,
      :client_instance_id,
      :ack_cursor,
      :nack_cursor,
      :inflight_cursor
    ]

    @enforce_keys fields
    defstruct fields

    def init(
          storage_mod: storage_mod,
          subscription_name: subscription_name,
          client_id: client_id,
          client_instance_id: client_instance_id,
          ack_cursor: ack_cursor,
          nack_cursor: nack_cursor
        ) do
      %State{
        storage_mod: storage_mod,
        subscription_name: subscription_name,
        client_id: client_id,
        client_instance_id: client_instance_id,
        ack_cursor: ack_cursor,
        nack_cursor: nack_cursor,
        inflight_cursor: ack_cursor
      }
    end

    def ack(state, sequence_number) do
      # todo: check sequence number
      {:ok,
       %State{
         state
         | ack_cursor: sequence_number
       }}
    end
  end

  @spec start_link(term) :: GenServer.on_start()
  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  def take(subscription_name, client_id, num) do
    case registry_lookup(subscription_name, client_id) do
      [{pid, _}] ->
        GenServer.call(pid, {:take, num})
    end
  end

  def ack(subscription_name, client_id, sequence_number) do
    case registry_lookup(subscription_name, client_id) do
      [{pid, _}] ->
        GenServer.call(pid, {:ack, sequence_number})
    end
  end

  def nack(_client_id, _sequence_number) do
  end

  def external_nack(_client_id) do
  end

  def clear_external_nack(_client_id) do
  end

  @impl true
  def init(
        storage_mod: storage_mod,
        subscription_name: subscription_name,
        client_id: client_id,
        client_instance_id: client_instance_id
      ) do
    {:ok, _} =
      Registry.register(
        @registry,
        {:cursor_manager, subscription_name, client_id},
        1_234_567_890
      )

    {ack_cursor, nack_cursor} = load_cursors_from_db(storage_mod, client_id, client_instance_id)

    {:ok,
     State.init(
       storage_mod: storage_mod,
       subscription_name: subscription_name,
       client_id: client_id,
       client_instance_id: client_instance_id,
       ack_cursor: ack_cursor,
       nack_cursor: nack_cursor
     )}
  end

  @impl true
  def handle_call({:take, num}, _from, state) do
    if is_nil(state.nack_cursor) do
      r =
        state.storage_mod.take(
          state.subscription_name,
          state.client_id,
          state.client_instance_id,
          state.ack_cursor,
          num
        )

      {:reply, r, state}
    end
  end

  def handle_call({:ack, _client_id, sequence_number}, _from, state) do
    case State.ack(state, sequence_number) do
      {:ok, new_state} ->
        {:noreply, new_state}

        # todo: error handling
    end
  end

  defp registry_lookup(subscription_name, client_id) do
    Registry.lookup(@registry, {:cursor_manager, subscription_name, client_id})
  end

  defp load_cursors_from_db(_mod, _client_id, _client_instance_id) do
    # todo: actually load this
    ack_cursor = 0
    nack_cursor = nil
    {ack_cursor, nack_cursor}
  end
end
