defmodule EventProduction.EventProducer do
  @moduledoc """
  Produce events for a client based on subscriptions.

  Internally tracks subscriptions, and which events have been consumed vs to consume
  """

  use GenServer
  alias Phoenix.PubSub

  defmodule State do
    @moduledoc false

    fields = [
      :processor,
      :client_id,
      :max_ingested_at,
      :max_event_timestamp,
      :ets_table,
      :last_ping
    ]

    @enforce_keys fields
    defstruct fields

    def init(processor, client_id, ets_table) do
      %State{
        processor: processor,
        client_id: client_id,
        max_ingested_at: nil,
        max_event_timestamp: nil,
        ets_table: ets_table,
        last_ping: nil
      }
    end
  end

  @spec start_link(term) :: GenServer.on_start()
  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def max_ingested_at(_processor, _client_id) do
    nil
  end

  def max_offset(_processor, _client_id, _) do
    nil
  end

  def produce_events(_processor, _client_id) do
    []
  end

  @impl true
  def init(processor: processor, client_id: client_id) do
    ets_table = :ets.new(:table, [:set, :protected])

    {:ok, _} =
      Registry.register(EventProduction.Registry, {:table, processor, client_id}, ets_table)

    {:ok, State.init(processor, client_id, ets_table), {:continue, :continue_init}}
  end

  @imple true
  def handle_continue(:continue_init, state) do
    # todo: load any existing state from database
    # load subscriptions
    # :ok = PubSub.subscribe(:sink_events, topic(client))

    {:noreply, state}
  end
end
