defmodule SinkBroadway.ProducerTracker do
  @moduledoc """
    Todo: come up with a better name

    Listen for Sink Events over Phoenix PubSub. This is used to:

    Track max ingested_at value for a client

    Track max offset for a topic

    Maybe external nacks? what would these be? where would we use them? Do we need
    to track this?

  """
  use GenServer
  alias Phoenix.PubSub

  @ingested_at_table_name :ground_event_log_ingested_at
  @ground_event_log_producer_offsets_table_name :ground_event_log_producer_offsets

  defmodule State do
    @moduledoc false

    @ingested_at_table_name :ground_event_log_ingested_at
    @ground_event_log_producer_offsets_table_name :ground_event_log_producer_offsets

    def init() do
      # create ets table that tracks the max offsets and ingested_at
      %{
        ingested_at_table: :ets.new(@ingested_at_table_name, [:set, :protected, :named_table]),
        events_table:
          :ets.new(@ground_event_log_producer_offsets_table_name, [:set, :protected, :named_table]),
        clients: []
      }
    end
  end

  @spec start_link(term) :: GenServer.on_start()
  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @doc """
  Start tracking the specificied client.
  """
  def add_client({client_id, client_instance_id}) do
    GenServer.call(__MODULE__, {:add_client, {client_id, client_instance_id}})
  end

  def topic({client_id, client_instance_id}), do: "#{client_id}-#{client_instance_id}:*"

  # todo: create a "remove_client" method

  @doc """
  Return the maximum ingested_at value for a client.

  This would be used to see if more events need to be processed
  """
  def max_ingested_at(client) do
    case :ets.lookup(@ingested_at_table_name, client) do
      [{_, ingested_at}] -> ingested_at
      [] -> nil
    end
  end

  @doc """
  Return the maximum offset value for a client.

  This would be used to see how far behind we are and decided skip processing this event
  or fast forward to the most recent event.
  """
  def max_offset(client, {event_type_id, event_key}) do
    case :ets.lookup(
           @ground_event_log_producer_offsets_table_name,
           {client, event_type_id, event_key}
         ) do
      [{_, max_offset}] -> max_offset
      [] -> nil
    end
  end

  @impl true
  def init(_) do
    {:ok, State.init()}
  end

  @impl true
  def handle_call({:add_client, client}, _from, state) do
    # subscribe to pub sub
    # do we want to segment this by event_type_id?
    :ok = PubSub.subscribe(:sink_events, topic(client))

    # load current state from db and populate ets table
    # todo: load from db

    {:reply, :ok, state}
  end

  @impl true
  def handle_info({:publish, client, sink_event, ingested_at}, state) do
    # update the maximum ingested_at for the client and the max offset for the topic
    # todo: check that the ingested_at is greater than the current value
    true = :ets.insert(state.ingested_at_table, {client, ingested_at})

    # todo: check that the offset is greater than the current value
    table_key = {client, sink_event.event_type_id, sink_event.key}
    true = :ets.insert(state.events_table, {table_key, sink_event.offset})

    {:noreply, state}
  end
end
