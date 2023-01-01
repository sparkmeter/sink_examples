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
      :client_id,
      :client_instance_id,
      :max_sequence_number,
      :max_event_timestamp,
      :counters,
      :ets_current_events,
      :last_ping
    ]

    @enforce_keys fields
    defstruct fields

    def init(client_id, client_instance_id, counters, ets_current_events) do
      %State{
        client_id: client_id,
        client_instance_id: client_instance_id,
        max_sequence_number: nil,
        max_event_timestamp: nil,
        counters: counters,
        ets_current_events: ets_current_events,
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

  def max_sequence_number(client_id) do
    with [{_pid, {counters, _}}] <- registry_lookup(client_id),
         sequence_number <- :counters.get(counters, @counters_seq_num) do
      sequence_number
    end
  end

  def max_offset(client_id, topic) do
    with [{_pid, {_, table}}] <- registry_lookup(client_id),
         [{_, sink_event, _}] <- :ets.lookup(table, topic) do
      sink_event.offset
    end
  end

  @impl true
  def init(client_id: client_id, client_instance_id: client_instance_id) do
    counters = :counters.new(1, [])
    ets_current_events = :ets.new(:table, [:set, :protected])

    :ok = Phoenix.PubSub.subscribe(:sink_events, EventProduction.topic(client_id))
    # todo: load existing values from database
    # load_from_db(ets_current_events, client_id)

    {:ok, _} =
      Registry.register(
        @registry,
        {:cache_manager, client_id},
        {counters, ets_current_events}
      )

    {:ok, State.init(client_id, client_instance_id, counters, ets_current_events)}
  end

  @impl true
  def handle_info({:publish, _client_id, sink_event, sequence_number}, state) do
    case State.publish(state, sink_event, sequence_number) do
      {:ok, new_state} ->
        :ok = :counters.put(state.counters, @counters_seq_num, sequence_number)

        ets_val =
          {{sink_event.event_type_id, sink_event.event_type_id}, sink_event, sequence_number}

        :ets.insert(state.ets_current_events, ets_val)
        {:noreply, new_state}

        # todo: error handling
    end
  end

  defp registry_lookup(client_id) do
    Registry.lookup(@registry, {:cache_manager, client_id})
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
