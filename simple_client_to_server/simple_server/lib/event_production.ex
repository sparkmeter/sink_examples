defmodule EventProduction do
  @moduledoc """
  Manages a cache of the most recent events produced.

  The Event Production's main responsibities are:
  - tracking the most recent event per client-topic
  - tracking "freshness" via max sequence_number, maybe ping
  - tracking the most recent X events
  - maybe tracking other sources of nacks?
  """
  alias EventProduction.CacheManager
  alias EventProduction.Coordinator

  def broadcast(client_id, sink_event, sequence_number) do
    Phoenix.PubSub.broadcast(
      :sink_events,
      topic(client_id),
      {:publish, client_id, sink_event, sequence_number}
    )
  end

  @doc """
  Translate to the phoenix pubsub topic

  Maybe move to a separate module
  """
  def topic(client_id) do
    "client_id:#{client_id}"
  end

  defdelegate add_client(client_id, client_instance_id), to: Coordinator
  defdelegate max_sequence_number(client_id), to: CacheManager
  defdelegate max_offset(client_id, topic), to: CacheManager
  defdelegate get_event(client_id, topic, offset), to: CacheManager
end
