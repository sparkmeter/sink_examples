defmodule SimpleClient.OutgoingEventProducer do
  @moduledoc """
  Produces events from clients

  Manages which clients to ask for events.

  Todo: this is what I'm thinking:
  - maintains a list of pids with events to process
  - if this list is empty, broadcast a message to all event cursors asking who has events
  - store this list
  - loop through the list and ask each pid for events until the list of pids is empty
  - if the pid list is empty, refill pid list

  every X time window check if the pid list is empty. if it is, refill
  """
  use GenStage

  @first_tick_after :timer.seconds(1)
  @tick_interval :timer.seconds(5)

  defmodule State do
    @moduledoc false

    fields = [
      :pids_with_events,
      :pending_demand
    ]

    @enforce_keys fields
    defstruct fields

    def init() do
      %State{
        pids_with_events: [],
        pending_demand: 0
      }
    end

    def buffer_demand(state, demand) do
      %State{state | pending_demand: state.pending_demand + demand}
    end
  end

  def start_link(opts) do
    GenStage.start_link(__MODULE__, opts)
  end

  @impl true
  def init(_opts) do
    state = State.init()
    schedule_tick(@first_tick_after)

    {:producer, state}
  end

  @impl true
  def handle_demand(demand, state) when demand > 0 do
    IO.inspect("SimpleClient.OutgoingEventProducer - handling demand")
    events = get_events(state.pids_with_events, demand)

    unfulfilled_demand =
      case length(events) - demand do
        0 -> 0
        x -> x
      end

    {:noreply, events, State.buffer_demand(state, unfulfilled_demand)}
  end

  def transform(event, _opts) do
    IO.inspect(event)

    %Broadway.Message{
      data: event,
      acknowledger: {Broadway.NoopAcknowledger, nil, nil}
    }
  end

  @impl true
  def handle_cast({:events, events}, state) do
    # todo: remove me and replace with a real method
    IO.puts("cast !!!")
    {:noreply, events, state}
  end

  @impl true
  def handle_info(:tick, state) do
    events =
      if state.pending_demand > 0 do
        get_events(state.pids_with_events, state.pending_demand)
      else
        []
      end

    @tick_interval |> jitter_interval() |> schedule_tick()

    {:noreply, events, state}
  end

  defp get_events([], _demand) do
    # request demand from cursor managers via registry
    IO.inspect("SimpleClient.OutgoingEventProducer - requesting demand")
    # EventCursors.Coordinator.request_events()
    []
  end

  defp get_events(_pids, _demand) do
    []
  end

  defp schedule_tick(time) do
    Process.send_after(self(), :tick, time)
  end

  defp jitter_interval(interval) do
    variance = div(interval, 10)
    interval + Enum.random(-variance..variance)
  end
end
