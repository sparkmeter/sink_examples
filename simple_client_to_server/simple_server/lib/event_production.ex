defmodule SinkBroadway do
  @moduledoc """

  Thoughts

  Modules
  - producer_tracker
    - tracks
      - max offset, ingested_at for a topic via pg_notify
      - ingested_at
      - external nacks? what would these be?
  - client tracker
    - tracks
      - current ingested_at cursor
      - outstanding events waiting to be ack'd
  - producer
    - asks client_trackers for batches
    - forwards acks / nacks to client tracker
  - processor
    - takes batches and processes them
    - acks / nacks when done
  """

  def add_client({client_id, client_instance_id}) do
    GenServer.call(SinkBroadway.Coordinator, {:add_client, {client_id, client_instance_id}})
  end
end
