defmodule SimpleClient.OutgoingEventPoller do
  @moduledoc """
  Poll the GroundEventLog for events which haven't been sent yet.

  This is about as basic an implementation as you can get. It will send one event at a
  time and wait for the server to ACK the message. If the server sends a NACK it will
  stop sending events (until the connection is reopened).
  """

  use GenServer
  alias Sink.Connection

  @first_tick_after :timer.seconds(1)
  @tick_interval :timer.seconds(5)

  @spec start_link(list(keyword())) :: :ignore | {:error, any()} | {:ok, pid()}
  def start_link(default) when is_list(default) do
    GenServer.start_link(__MODULE__, default, name: __MODULE__)
  end

  @impl true
  def init(_) do
    schedule_tick(@first_tick_after)
    {:ok, []}
  end

  @impl true
  def handle_cast(:flush, state) do
    _ = flush()
    {:noreply, state}
  end

  @impl true
  def handle_info(:tick, state) do
    flush()

    @tick_interval |> jitter_interval() |> schedule_tick()

    {:noreply, state}
  end

  @spec flush() :: :ok | :sending | :not_ready | :no_queued_events
  defp flush do
    with true <- Connection.Client.connected?(),
         {:ok, []} <- Connection.ClientConnection.get_inflight(),
         {:ok, []} = Connection.ClientConnection.get_received_nacks() do
      SimpleClient.get_next_event()
      |> case do
        nil ->
          :no_queued_events

        event ->
          ack_key = {event.event_type_id, event.key, event.offset}
          :ok = Connection.Client.publish(event, ack_key)
          :sending
      end
    end
  else
    _ -> :not_ready
  catch
    :error, {:badmatch, err} when err in [{:error, :closed}, {:error, :no_connection}] ->
      :not_ready
  end

  defp schedule_tick(time) do
    Process.send_after(self(), :tick, time)
  end

  defp jitter_interval(interval) do
    variance = div(interval, 10)
    interval + Enum.random(-variance..variance)
  end
end
