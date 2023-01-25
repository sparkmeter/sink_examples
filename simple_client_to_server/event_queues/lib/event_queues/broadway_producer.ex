defmodule EventQueues.BroadwayProducer do
  @moduledoc """
  Produces events from clients

  Manages which clients to ask for events.

  Todo: this is what I'm thinking:
  - maintains a list of client_ids with events to process
  - if this list is empty, broadcast a message to all event cursors asking who has events
  - store this list
  - loop through the list and ask each client_id for events until the list of client_ids is empty
  - if the client_id list is empty, refill client_id list

  every X time window check if the client_id list is empty. if it is, refill

  could use pids instead of client_id, but the client_id is more useful to humans and for logger statements
  """
  use GenStage
  alias EventQueues.QueueManager

  @first_tick_after :timer.seconds(1)
  @tick_interval :timer.seconds(5)

  defmodule State do
    @moduledoc false

    fields = [
      :subscription,
      :client_ids_with_events,
      :pending_demand
    ]

    @enforce_keys fields
    defstruct fields

    def init(subscription) do
      %State{
        subscription: subscription,
        client_ids_with_events: :queue.new(),
        pending_demand: 0
      }
    end

    def add_client_id(state, client_id) do
      # do we care about duplicates? this should probably be a queue
      %State{state | client_ids_with_events: :queue.in(client_id, state.client_ids_with_events)}
    end

    def remaining_demand(state, remaining_client_ids, pending_demand) do
      %State{state | client_ids_with_events: remaining_client_ids, pending_demand: pending_demand}
    end
  end

  def start_link(opts) do
    GenStage.start_link(__MODULE__, opts)
  end

  @impl true
  def init(opts) do
    subscription = Keyword.fetch!(opts, :subscription)
    state = State.init(subscription)
    schedule_tick(@first_tick_after)

    :ok = EventQueues.QueueManager.ping_queues(subscription)

    {:producer, state}
  end

  @impl true
  def handle_demand(demand, state) when demand > 0 do
    {events, client_id_queue, remaining_demand} =
      flush(state.subscription, state.client_ids_with_events, demand + state.pending_demand)

    {:noreply, events, State.remaining_demand(state, client_id_queue, remaining_demand)}
  end

  def transform(event, _opts) do
    %Broadway.Message{
      data: event,
      acknowledger: {Broadway.NoopAcknowledger, nil, nil}
    }
  end

  @impl true
  def handle_info(:tick, state) do
    {events, client_id_queue, remaining_demand} =
      flush(state.subscription, state.client_ids_with_events, state.pending_demand)

    @tick_interval |> jitter_interval() |> schedule_tick()

    {:noreply, events, State.remaining_demand(state, client_id_queue, remaining_demand)}
  end

  def handle_info({:pong, client_id}, state) do
    # todo: maybe emit events if we have pending demand
    {:noreply, [], State.add_client_id(state, client_id)}
  end

  defp flush(subscription, client_ids, demand) do
    {client_id_queue, events, remaining_demand} = get_events(subscription, client_ids, demand)

    if :queue.is_empty(client_id_queue) do
      :ok = EventQueues.QueueManager.ping_queues(subscription)
    end

    {events, client_id_queue, remaining_demand}
  end

  defp get_events(_subscription, q, demand) when q == {[], []}, do: {q, [], demand}

  defp get_events(subscription, client_id_queue, demand) do
    # see: https://elixirforum.com/t/write-while-loop-equivalent-in-elixir/15880/2
    Stream.unfold({client_id_queue, [], demand}, fn {acc_client_id_q, acc_events, acc_demand} ->
      {result, q} = :queue.out(acc_client_id_q)

      if result == :empty || demand == 0 do
        nil
      else
        {:value, client_id} = result
        events = QueueManager.take(subscription, client_id, acc_demand)

        # todo: what if length(events) > demand? raise?
        r = {q, acc_events ++ events, acc_demand - length(events)}
        {r, r}
      end
    end)
    |> Enum.to_list()
    |> List.first()
  end

  defp schedule_tick(time) do
    Process.send_after(self(), :tick, time)
  end

  defp jitter_interval(interval) do
    variance = div(interval, 10)
    interval + Enum.random(-variance..variance)
  end
end
