defmodule EventProduction.CacheManager do
  @moduledoc """
  Track the most recent produced events for a client

  Each process uses two ets tables:
  - current events: tracks the most recent event for a client's topic
  - recent events: tracks the most recent events for a client

  "max_sequence_number" is tracked via a counter
  Notes to self:
  - do we care about process dying and counter persisting?  documentation suggests they
    are reference counted, so might not have to worry if the ref isn't cached anywhere
  - documentation says an add is faster than a put. I don't think we care, though.
    Should be plenty fast

  todo: implement recent events table
  """

  use GenServer
  @registry EventProduction.Registry
  @counters_seq_num 1

  defmodule State do
    @moduledoc false

    fields = [
      :storage_mod,
      :client_id,
      :client_instance_id,
      :max_sequence_number,
      :max_event_timestamp,
      :counters,
      :ets_latest_events,
      :last_ping
    ]

    @enforce_keys fields
    defstruct fields

    def init(
          storage_mod: storage_mod,
          client_id: client_id,
          client_instance_id: client_instance_id,
          max_sequence_number: max_sequence_number,
          max_event_timestamp: max_event_timestamp,
          counters: counters,
          ets_latest_events: ets_latest_events
        ) do
      %State{
        storage_mod: storage_mod,
        client_id: client_id,
        client_instance_id: client_instance_id,
        max_sequence_number: max_sequence_number,
        max_event_timestamp: max_event_timestamp,
        counters: counters,
        ets_latest_events: ets_latest_events,
        last_ping: nil
      }
    end

    def publish(state, sink_event, sequence_number) do
      # todo: check sequence number, offset, etc.
      {:ok,
       %State{
         state
         | max_sequence_number: sequence_number,
           max_event_timestamp: sink_event.timestamp
       }}
    end
  end

  @spec start_link(term) :: GenServer.on_start()
  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  @doc """
  Return the event if it's in the cache or a miss and the reason why.

  This is useful to both avoid a trip to storage and to check if an event is new.

  If the offset is greater than the most recent known event than
  `{:miss, :offset_out_of_range, difference}` will be returned, where `difference`
  is the difference between the most recent known offset and the requested offset.
  """
  def get_event(client_id, {event_type_id, key}, offset) do
    case ets_lookup(client_id, {event_type_id, key}) do
      nil ->
        {:miss, :new_topic}

      {sink_event, seq_num} when %{offset: offset} ->
        {:hit, sink_event, seq_num}

      {sink_event, _} when sink_event.offset > offset ->
        {:miss, :offset_above_max, offset - sink_event.offset}

      {sink_event, _} when sink_event.offset < offset ->
        {:miss, :not_in_cache}
    end
  end

  def max_sequence_number(client_id) do
    with [{_pid, {counters, _}}] <- registry_lookup(client_id),
         sequence_number <- :counters.get(counters, @counters_seq_num) do
      sequence_number
    end
  end

  def max_offset(client_id, topic) do
    {sink_event, _} = ets_lookup(client_id, topic)
    sink_event && sink_event.offset
  end

  @impl true
  def init(storage_mod: storage_mod, client_id: client_id, client_instance_id: client_instance_id) do
    counters = :counters.new(1, [])
    ets_latest_events = :ets.new(:table, [:set, :protected])

    # make sure we get any new events that happen while we are loading existing events from storage
    :ok = Phoenix.PubSub.subscribe(:sink_events, EventProduction.topic(client_id))

    # load existing events from storage
    {:ok, max_sequence_number, max_event_timestamp} =
      load_from_db(storage_mod, ets_latest_events, client_id, client_instance_id)

    :ok = :counters.put(counters, @counters_seq_num, max_sequence_number || 0)
    # todo: also track max_event_timestamp in counter

    {:ok, _} =
      Registry.register(
        @registry,
        {:cache_manager, client_id},
        {counters, ets_latest_events}
      )

    {:ok,
     State.init(
       storage_mod: storage_mod,
       client_id: client_id,
       client_instance_id: client_instance_id,
       max_sequence_number: max_sequence_number,
       max_event_timestamp: max_event_timestamp,
       counters: counters,
       ets_latest_events: ets_latest_events
     )}
  end

  @impl true
  def handle_info({:publish, _client_id, sink_event, sequence_number}, state) do
    case State.publish(state, sink_event, sequence_number) do
      {:ok, new_state} ->
        :ok = :counters.put(state.counters, @counters_seq_num, sequence_number)

        ets_insert(state.ets_latest_events, sink_event, sequence_number)
        {:noreply, new_state}

        # todo: error handling
    end
  end

  defp registry_lookup(client_id) do
    Registry.lookup(@registry, {:cache_manager, client_id})
  end

  defp load_from_db(_mod, _ets_table, _client_id, nil), do: {:ok, nil, nil}

  defp load_from_db(mod, ets_table, client_id, client_instance_id) do
    {max_sequence_number, max_event_timestamp} =
      Enum.reduce(mod.get_current_events(client_id, client_instance_id), {nil, nil}, fn {event,
                                                                                         seq_num},
                                                                                        acc ->
        ets_insert(ets_table, event, seq_num)
        {max_sequence_number, max_event_timestamp} = acc

        {max(max_sequence_number, seq_num) || seq_num,
         max(max_event_timestamp, event.timestamp) || event.timestamp}
      end)

    {:ok, max_sequence_number, max_event_timestamp}
  end

  defp ets_insert(table, sink_event, sequence_number) do
    ets_val = {{sink_event.event_type_id, sink_event.key}, sink_event, sequence_number}
    true = :ets.insert(table, ets_val)
  end

  defp ets_lookup(client_id, topic) do
    with [{_pid, {_, table}}] <- registry_lookup(client_id),
         [{_, sink_event, sequence_number}] <- :ets.lookup(table, topic) do
      {sink_event, sequence_number}
    else
      _ -> nil
    end
  end

  # do we want to use a continue?
  # There is a risk the pid for the cache manager will be found, but as long as the client
  # uses the registry and not a pid whereis this shouldn't be an issue.
  #  @imple true
  #  def handle_continue(:continue_init, state) do
  #    # todo: load any existing state from database
  #    # load subscriptions
  #    # :ok = PubSub.subscribe(:sink_events, topic(client))
  #
  #    {:noreply, state}
  #  end
end
