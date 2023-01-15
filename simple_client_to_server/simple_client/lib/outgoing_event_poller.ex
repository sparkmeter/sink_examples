defmodule SimpleClient.OutgoingEventPoller do
  @moduledoc """

  """

  use Broadway

  @subscription SimpleClient.OutgoingEventSubscription

  @spec start_link(list(keyword())) :: :ignore | {:error, any()} | {:ok, pid()}
  def start_link(opts) do
    producer_mod = Keyword.fetch!(opts, :producer_module)
    connection_mod = Keyword.fetch!(opts, :connection_module)

    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      producer: [
        module: {producer_mod, [1, subscription: @subscription]},
        transformer: {producer_mod, :transform, []}
      ],
      processors: [
        default: [concurrency: 1, max_demand: 20]
      ],
      context: %{
        connection_module: connection_mod
      }
    )
  end

  # def flush

  @impl true
  def handle_message(:default, %{data: event} = message, context) do
    IO.inspect("SimpleClient.OutgoingEventPoller - handling message")
    ack_key = {event.event_type_id, event.key, event.offset}
    # :ok = Connection.Client.publish(event, ack_key)
    :ok = context.connection_module.publish(event, ack_key)

    message
  end

  # old stuff that can be deleted

  #  @impl true
  #  def init(_) do
  #    schedule_tick(@first_tick_after)
  #    {:ok, []}
  #  end
  #
  #  @impl true
  #  def handle_cast(:flush, state) do
  #    _ = flush()
  #    {:noreply, state}
  #  end
  #

  #
  #  @spec flush() :: :ok | :sending | :not_ready | :no_queued_events
  #  defp flush do
  #    with true <- Connection.Client.connected?(),
  #         {:ok, []} <- Connection.ClientConnection.get_inflight(),
  #         {:ok, []} = Connection.ClientConnection.get_received_nacks() do
  #      SimpleClient.get_next_event()
  #      |> case do
  #        nil ->
  #          :no_queued_events
  #
  #        event ->
  #          ack_key = {event.event_type_id, event.key, event.offset}
  #
  #          :ok = Connection.Client.publish(event, ack_key)
  #          :sending
  #      end
  #    end
  #  else
  #    _ -> :not_ready
  #  catch
  #    :error, {:badmatch, err} when err in [{:error, :closed}, {:error, :no_connection}] ->
  #      :not_ready
  #  end
  #
  #  defp schedule_tick(time) do
  #    Process.send_after(self(), :tick, time)
  #  end
  #
  #  defp jitter_interval(interval) do
  #    variance = div(interval, 10)
  #    interval + Enum.random(-variance..variance)
  #  end
end
