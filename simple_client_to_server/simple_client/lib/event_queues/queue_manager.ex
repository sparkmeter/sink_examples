defmodule EventQueues.QueueManager do
  @moduledoc """
  GenStage type producer that manages demand for events from an event log

  - tracks min and max demand
  - stores up to max_demand number of events
  - tracks the last event emitted / taken by a caller to prevent emitting duplicate events
  - requests more events from storage when demand goes below min_demand

  todo:
  - implement priority queue behavior. This may be able to be handled purely in the storage module
  - add a timer or other way to poll for events if demand is < min_demand (because new events have arrived)
  - change interface with BroadwayProducer so a pong is only sent if events > 0
  - allow stopping of event emission (ex: because of external NACK)
  - telemetry?
  """
  use GenServer

  defmodule State do
    @moduledoc false

    fields = [
      :storage_mod,
      :subscription,
      :client_id,
      :client_instance_id,
      :last_taken_event,
      :min_demand,
      :max_demand,
      :events
    ]

    @enforce_keys fields
    defstruct fields

    def init(opts) do
      %State{
        storage_mod: Keyword.fetch!(opts, :storage_mod),
        subscription: Keyword.fetch!(opts, :subscription),
        client_id: Keyword.fetch!(opts, :client_id),
        client_instance_id: Keyword.fetch!(opts, :client_instance_id),
        last_taken_event: Keyword.fetch!(opts, :last_taken_event),
        min_demand: Keyword.fetch!(opts, :min_demand),
        max_demand: Keyword.fetch!(opts, :max_demand),
        events: []
      }
    end

    def new_events(state, events) do
      %State{state | events: state.events ++ events}
    end

    def take(state, num) do
      {events, remaining_events} = Enum.split(state.events, num)
      {%State{state | last_taken_event: List.last(events), events: remaining_events}, events}
    end
  end

  @spec start_link(term) :: GenServer.on_start()
  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  @doc """
  Take _num events and advance the cursor
  """
  def take(subscription, client_id, num) do
    case registry_lookup(subscription, client_id) do
      [{pid, _}] ->
        GenServer.call(pid, {:take, num})

      _ ->
        []
    end
  end

  @doc """
  Ask queues to identify themselves if they are able to emit events.

  With this list we can ask for events.
  """
  def ping_queues(subscription) do
    subscription
    |> registry_mod()
    |> Registry.select([{{:"$1", :"$2", :"$3"}, [], [{{:"$1", :"$2", :"$3"}}]}])
    |> Enum.each(fn {_client_id, pid, _value} ->
      try do
        send(pid, {:ping, self()})
      catch
        _kind, _reason ->
          # process is gone
          :ok
      end
    end)

    :ok
  end

  def nack(_client_id, _sequence_number) do
  end

  def external_nack(_client_id) do
  end

  def clear_external_nack(_client_id) do
  end

  @init_opts_definition [
    storage_mod: [
      type: :atom,
      required: true
    ],
    subscription: [
      type: :atom,
      required: true
    ],
    client_id: [
      type: :string,
      required: true
    ],
    client_instance_id: [
      type: :integer,
      required: true
    ],
    min_demand: [
      type: :non_neg_integer,
      default: 20
    ],
    max_demand: [
      type: :non_neg_integer,
      default: 100
    ]
  ]

  @impl true
  def init(opts) do
    case NimbleOptions.validate(opts, @init_opts_definition) do
      {:ok, clean_opts} ->
        storage_mod = Keyword.fetch!(clean_opts, :storage_mod)
        subscription = Keyword.fetch!(clean_opts, :subscription)
        client_id = Keyword.fetch!(clean_opts, :client_id)
        client_instance_id = Keyword.fetch!(clean_opts, :client_instance_id)

        # todo: get rid of 1_234_567_890 value
        {:ok, _} =
          Registry.register(
            registry_mod(subscription),
            client_id,
            1_234_567_890
          )

        last_acked_event =
          storage_mod.get_last_acked_event(
            subscription,
            client_id,
            client_instance_id
          )

        clean_opts = Keyword.put(clean_opts, :last_taken_event, last_acked_event)

        {:ok, State.init(clean_opts), {:continue, :demand_events}}
    end
  end

  @impl true
  def handle_continue(:demand_events, state) do
    # if events are less than min_demand, ask storage for more events
    new_events =
      if length(state.events) < state.min_demand do
        num = state.max_demand - length(state.events)
        last_demanded_event = List.last(state.events) || state.last_taken_event

        state.storage_mod.demand(
          state.subscription,
          state.client_id,
          state.client_instance_id,
          last_demanded_event,
          num
        )
      else
        []
      end

    {:noreply, State.new_events(state, new_events)}
  end

  @impl true
  def handle_call({:take, num}, _from, state) do
    {new_state, events} = State.take(state, num)
    {:reply, events, new_state, {:continue, :demand_events}}
  end

  @impl true
  def handle_info({:ping, from_pid}, state) do
    # todo: handle from_pid crashing
    send(from_pid, {:pong, state.client_id})

    {:noreply, state}
  end

  defp registry_mod(subscription), do: Module.concat(subscription, Registry)

  defp registry_lookup(subscription, client_id) do
    Registry.lookup(
      registry_mod(subscription),
      client_id
    )
  end
end
