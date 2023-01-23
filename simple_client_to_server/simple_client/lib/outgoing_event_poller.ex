defmodule SimpleClient.OutgoingEventPoller do
  @moduledoc """

  """
  use Broadway
  require Logger

  @default_producer_module EventQueues.BroadwayProducer
  @subscription SimpleClient.OutgoingEventSubscription

  @spec start_link(list(keyword())) :: :ignore | {:error, any()} | {:ok, pid()}
  def start_link(opts) do
    producer_mod = Keyword.get(opts, :producer_module, @default_producer_module)
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
  def handle_message(:default, %{data: ground_event} = message, context) do
    Logger.debug("Sending event type #{ground_event.event_type_id} to the Sink server")
    sink_event = SimpleClient.GroundEventLog.to_sink_event(ground_event)
    ack_key = {sink_event.event_type_id, sink_event.key, sink_event.offset}
    # :ok = Connection.Client.publish(event, ack_key)
    :ok = context.connection_module.publish(sink_event, ack_key)

    message
  end
end
