defmodule SimpleClient.SinkSubscriptionStorage do
  import Ecto.Query, only: [from: 2]
  alias SimpleClient.Repo
  alias SimpleClient.GroundEventLog
  alias SimpleClient.OutgoingEventSubscription

  @log_table GroundEventLog
  @sub_table OutgoingEventSubscription

  def demand(OutgoingEventSubscription, "self", _client_instance_id, last_acked_event, num) do
    last_seq_number =
      if is_nil(last_acked_event) do
        0
      else
        last_acked_event.id
      end

    from(log in @log_table,
      join: sub in @sub_table,
      on:
        log.key == sub.key and log.event_type_id == sub.event_type_id and
          log.offset > sub.consumer_offset,
      where: log.id > ^last_seq_number,
      where: is_nil(sub.nack_at_row_id) or sub.nack_at_row_id == log.id,
      select: log,
      order_by: [asc: log.id],
      limit: ^num
    )
    |> Repo.all()
  end

  def get_last_acked_event(OutgoingEventSubscription, "self", _client_instance_id) do
    # assuming we are ack'ing events in order we can take the greatest id
    [{max_ack_id, min_nack_id}] =
      from(sub in @sub_table,
        select: {max(sub.ack_at_row_id), min(sub.nack_at_row_id)}
      )
      |> Repo.all()

    min_nack_id = if is_nil(min_nack_id), do: nil, else: min_nack_id - 1

    case min(max_ack_id, min_nack_id) do
      nil -> nil
      id -> Repo.get_by(@log_table, id: id)
    end
  end
end
